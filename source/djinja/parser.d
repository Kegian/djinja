module djinja.parser;

private
{
    import std.format: fmt = format;
    import std.conv : to;

    import djinja.ast;
    import djinja.lexer;
    import djinja.exception : JinjaParserException,
                              assertJinja = assertJinjaParser;
}


struct Parser(Lexer)
{
    private
    {
        Node _root;
        Lexer _lexer;
        Token[] tokens_;

        Token _curr;
        bool _read;
    }

    this(Lexer lexer)
    {
        //TODO appender
        while (true)
        {
            auto tkn = lexer.nextToken;
            tokens_ ~= tkn; 
            if (tkn.type == Type.EOF)
                break;
        }
    }

    void preprocess()
    {
        import std.uni : isWhite;

        // Cutting newline and whitespaces before/after statements
        for(int i = 1; i < tokens_.length - 1; i++)
        {
            if (tokens_[i].type == Type.StmtBegin
                && tokens_[i-1].type == Type.Raw)
            {
                auto str = tokens_[i-1].value;
                auto idx = str.length;
                for (long j = cast(long)str.length - 1; j >= 0; j--)
                {
                    if (str[j] == '\n')
                        break;
                    if (isWhite(str[j]))
                        idx = j;
                }
                tokens_[i-1].value = idx > 0 ? str[0 .. idx] : "";
            }
            else if (tokens_[i].type == Type.StmtEnd
                && tokens_[i+1].type == Type.Raw)
            {
                auto str = tokens_[i+1].value;
                auto idx = 0;
                for (auto j = 0; j < str.length; j++)
                {
                    if (isWhite(str[j]))
                        idx = j + 1;
                    if (str[j] == '\n')
                        break;
                }
                tokens_[i+1].value = idx < str.length ? str[idx .. $] : "";
            }
        }
    }

    void parseTree()
    {
        preprocess();
        _root = parseStatementBlock();
        if (front.type != Type.EOF)
            throw new JinjaParserException("Expected EOF found %s".fmt(front.value));
    }

    Node root()
    {
        return _root;
    }

private: 


    /**
      * exprblock = EXPRBEGIN expr (IF expr (ELSE expr)? )? EXPREND
      */
    ExprNode parseExpression()
    {
        Node expr;

        pop(Type.ExprBegin);
        expr = parseHighLevelExpression();
        pop(Type.ExprEnd);

        return new ExprNode(expr);
    }

    StmtBlockNode parseStatementBlock()
    {
        auto block = new StmtBlockNode();

        while (front.type != Type.EOF)
        {
            switch(front.type) with (Type)
            {
                case Raw:
                    auto raw = pop.value;
                    if (raw.length)
                        block.children ~= new RawNode(raw);
                    break;

                case ExprBegin:
                    block.children ~= parseExpression();
                    break;

                case CmntBegin:
                    parseComment();
                    break;

                case StmtBegin:
                    if (next.type == Type.Keyword
                        && next.value.toKeyword.isBeginingKeyword)
                        block.children ~= parseStatement();
                    else
                        return block;
                    break;

                default:
                    return block;
            }
        }

        return block;
    }


    Node parseStatement()
    {
        pop(Type.StmtBegin);

        switch(front.value) with (Keyword)
        {
            case If:     return parseIf();
            case For:    return parseFor();
            case Set:    return parseSet();
            case Macro:  return parseMacro();
            case Call:   return parseCall();
            case Filter: return parseFilterBlock();
            default:
                assert(0, "Not implemented kw %s".fmt(front.value));
        }

        // return new RawNode("I must be statemnet");
    }


    ForNode parseFor()
    {
        string key, value;

        pop(Keyword.For);
        value = pop(Type.Ident).value;

        if (front.type == Type.Comma)
        {
            pop(Type.Comma);
            key = value;
            value = pop(Type.Ident).value;
        }

        pop(Operator.In);
        
        Node iterable;

        switch (front.type) with (Type)
        {
            case LParen:  iterable = parseTuple(); break;
            case LSParen: iterable = parseList(); break;
            case LBrace:  iterable = parseDict; break;
            default:      iterable = parseIdent();
        }

        pop(Type.StmtEnd);

        auto block = parseStatementBlock();

        pop(Type.StmtBegin);

        switch (front.value) with (Keyword)
        {
            case EndFor:
                pop(Keyword.EndFor);
                pop(Type.StmtEnd);
                return new ForNode(key, value, iterable, block, null);
            case Else:
                pop(Keyword.Else);
                pop(Type.StmtEnd);
                auto other = parseStatementBlock();
                pop(Type.StmtBegin);
                pop(Keyword.EndFor);
                pop(Type.StmtEnd);
                return new ForNode(key, value, iterable, block, other);
            default:
                throw new JinjaParserException("Unexpected token %s".fmt(front.value));
        }
    }


    IfNode parseIf()
    {
        //TODO: If or ElIf
        pop();
        auto cond = parseHighLevelExpression();
        pop(Type.StmtEnd);

        auto then = parseStatementBlock();

        pop(Type.StmtBegin);

        switch (front.value) with (Keyword)
        {
            case ElIf:
                auto other = parseIf();
                return new IfNode(cond, then, other);
            case Else:
                pop(Keyword.Else);
                pop(Type.StmtEnd);
                auto other = parseStatementBlock();
                pop(Type.StmtBegin);
                pop(Keyword.EndIf);
                pop(Type.StmtEnd);
                return new IfNode(cond, then, other);
            case EndIf:
                pop(Keyword.EndIf);
                pop(Type.StmtEnd);
                return new IfNode(cond, then, null);
            default:
                throw new JinjaParserException("Enexppected token %s".fmt(front.value));
        }
    }


    SetNode parseSet()
    {
        pop(Keyword.Set);

        auto assigns = parseSequenceOf!parseAssignable(Type.Operator);

        pop(Operator.Assign);

        auto exprs = parseSequenceOf!parseHighLevelExpression(Type.StmtEnd);
        Node expr = exprs.length == 1 ? exprs[0] : new ListNode(exprs);

        pop(Type.StmtEnd);

        return new SetNode(assigns, expr);
    }


    AssignableNode parseAssignable()
    {
        string name = pop(Type.Ident).value;
        Node[] subIdents = [];

        while (true)
        {
            switch (front.type) with (Type)
            {
                case Dot:
                    pop(Dot);
                    subIdents ~= new StringNode(pop(Ident).value);
                    break;
                case LSParen:
                    pop(LSParen);
                    subIdents ~= parseHighLevelExpression();
                    pop(RSParen);
                    break;
                default:
                    return new AssignableNode(name, subIdents);
            }
        }
    }


    MacroNode parseMacro()
    {
        pop(Keyword.Macro);

        auto name = pop(Type.Ident).value;
        Arg[] args;

        if (front.type == Type.LParen)
        {
            pop(Type.LParen);
            args = parseFormalArgs();
            pop(Type.RParen);
        }

        pop(Type.StmtEnd);

        auto block = parseStatementBlock();

        pop(Type.StmtBegin);
        pop(Keyword.EndMacro);

        bool ret = false;
        if (front.type == Type.Keyword && front.value == Keyword.Return)
        {
            pop(Keyword.Return);
            block.children ~= parseHighLevelExpression();
            ret = true;
        }
        else
            block.children ~= new NilNode;

        pop(Type.StmtEnd);

        return new MacroNode(name, args, block, ret);
    }

    
    CallNode parseCall()
    {
        pop(Keyword.Call);
        
        Arg[] formalArgs;

        if (front.type == Type.LParen)
        {
            pop(Type.LParen);
            formalArgs = parseFormalArgs();
            pop(Type.RParen);
        }

        auto macroName = front.value;
        auto factArgs = parseCallExpr();

        pop(Type.StmtEnd);

        auto block = parseStatementBlock();
        block.children ~= new StringNode("");

        pop(Type.StmtBegin);
        pop(Keyword.EndCall);
        pop(Type.StmtEnd);

        return new CallNode(macroName, formalArgs, factArgs, block);
    }

    FilterBlockNode parseFilterBlock()
    {
        pop(Keyword.Filter);

        auto filterName = front.value;
        auto args = parseCallExpr();

        pop(Type.StmtEnd);

        auto block = parseStatementBlock();

        pop(Type.StmtBegin);
        pop(Keyword.EndFilter);
        pop(Type.StmtEnd);

        return new FilterBlockNode(filterName, args, block);
    }
    
    Arg[] parseFormalArgs()
    {
        Arg[] args = [];
        bool isVarargs = true;

        while(front.type != Type.EOF && front.type != Type.RParen)
        {
            auto name = pop(Type.Ident).value;
            Node def = null;

            if (!isVarargs || front.type == Type.Operator && front.value == Operator.Assign)
            {
                isVarargs = false;
                pop(Operator.Assign);
                def = parseHighLevelExpression();
            }

            args ~= Arg(name, def);
            
            if (front.type != Type.RParen)
                pop(Type.Comma);
        }
        return args;
    }


    Node parseHighLevelExpression()
    {
        return parseInlineIf();
    }


    /**
      * inlineif = orexpr (IF orexpr (ELSE orexpr)? )?
      */
    Node parseInlineIf()
    {
        Node expr;
        Node cond = null;
        Node other = null;

        expr = parseOrExpr();

        if (front == Keyword.If)
        {
            pop(Keyword.If);
            cond = parseOrExpr();

            if (front == Keyword.Else)
            {
                pop(Keyword.Else);
                other = parseOrExpr();
            }

            return new InlineIfNode(expr, cond, other);
        }

        return expr;
    }

    /**
      * Parse Or Expression
      * or = and (OR or)?
      */
    Node parseOrExpr()
    {
        auto lhs = parseAndExpr();

        while(true)
        {
            if (front.type == Type.Operator && front.value == Operator.Or)
            {
                pop(Operator.Or);
                auto rhs = parseAndExpr();
                lhs = new BinOpNode(Operator.Or, lhs, rhs);
            }
            else
                return lhs;
        }
    }

    /**
      * Parse And Expression:
      * and = inis (AND inis)*
      */
    Node parseAndExpr()
    {
        auto lhs = parseInIsExpr();

        while(true)
        {
            if (front.type == Type.Operator && front.value == Operator.And)
            {
                pop(Operator.And);
                auto rhs = parseInIsExpr();
                lhs = new BinOpNode(Operator.And, lhs, rhs);
            }
            else
                return lhs;
        }
    }

    /**
      * Parse inis:
      * inis = cmp ( (NOT)? (IN expr |IS callexpr) )?
      */
    Node parseInIsExpr()
    {
        auto inis = parseCmpExpr();

        bool hasNot = false;
        if (front == Operator.Not && (next == Operator.In || next == Operator.Is))
        {
            pop(Operator.Not);
            hasNot = true;
        }

        if (front == Operator.In)
        {
            auto op = pop().value;
            auto rhs = parseHighLevelExpression();
            inis = new BinOpNode(op, inis, rhs);
        }

        if (front == Operator.Is)
        {
            auto op = pop().value;
            auto rhs = parseCallExpr();
            inis = new BinOpNode(op, inis, rhs);
        }

        if (hasNot)
            inis = new UnaryOpNode(Operator.Not, inis);

        return inis;
    }


    /**
      * Parse compare expression:
      * cmp = concatexpr (CMPOP concatexpr)?
      */
    Node parseCmpExpr()
    {
        auto lhs = parseConcatExpr();

        if (front.type == Type.Operator && front.value.toOperator.isCmpOperator)
        {
            auto op = pop(Type.Operator).value;
            return new BinOpNode(op, lhs, parseConcatExpr());
        }

        return lhs;
    }

    /**
      * Parse expression:
      * concatexpr = filterexpr (CONCAT filterexpr)*
      */
    Node parseConcatExpr()
    {
        auto lhsTerm = parseFilterExpr();

        while (front == Operator.Concat)
        {
            auto op = pop(Operator.Concat).value;
            lhsTerm = new BinOpNode(op, lhsTerm, parseFilterExpr());
        }

        return lhsTerm;
    }

    /**
      * filterexpr = mathexpr (FILTER callexpr)*
      */
    Node parseFilterExpr()
    {
        auto filterexpr = parseMathExpr();

        while (front == Operator.Filter)
        {
            auto op = pop(Operator.Filter).value;
            filterexpr = new BinOpNode(op, filterexpr, parseCallExpr());
        }

        return filterexpr;
    }

    /**
      * Parse math expression:
      * mathexpr = term((PLUS|MINUS)term)*
      */
    Node parseMathExpr()
    {
        auto lhsTerm = parseTerm();

        while (true)
        {
            if (front.type != Type.Operator)
                return lhsTerm;

            switch (front.value) with (Operator)
            {
                case Plus:
                case Minus:
                    auto op = pop.value;
                    lhsTerm = new BinOpNode(op, lhsTerm, parseTerm());
                    break;
                default:
                    return lhsTerm;
            }
        }
    }

    /**
      * Parse term:
      * term = unary((MUL|DIVI|DIVF|REM)unary)*
      */
    Node parseTerm()
    {
        auto lhsFactor = parseUnary();

        while(true)
        {
            if (front.type != Type.Operator)
                return lhsFactor;
        
            switch (front.value) with (Operator)
            {
                case DivInt:
                case DivFloat:
                case Mul:
                case Rem:
                    auto op = pop.value;
                    lhsFactor = new BinOpNode(op, lhsFactor, parseUnary());
                    break;
                default:
                    return lhsFactor;
            }
        } 
    }

    /**
      * Parse unary:
      * unary = (pow | (PLUS|MINUS|NOT)unary)
      */
    Node parseUnary()
    {
        if (front.type != Type.Operator)
            return parsePow();

        switch (front.value) with (Operator)
        {
            case Plus:
            case Minus:
            case Not:
                auto op = pop.value;
                return new UnaryOpNode(op, parseUnary());
            default:
                assertJinja(0, "Unexpected operator `%s`".fmt(front.value));
                assert(0);
        }
    }

    /**
      * Parse pow:
      * pow = factor (POW pow)?
      */
    Node parsePow()
    {
        auto lhs = parseFactor();

        if (front.type == Type.Operator && front.value == Operator.Pow)
        {
            auto op = pop(Operator.Pow).value;
            return new BinOpNode(op, lhs, parsePow());
        }

        return lhs;
    }


    /**
      * Parse factor:
      * factor = (ident|(tuple|LPAREN HighLevelExpr RPAREN)|literal)
      */
    Node parseFactor()
    {
        switch (front.type) with (Type)
        {
            case Ident:
                return parseIdent();

            case LParen:
                pop(LParen);
                bool hasCommas;
                auto exprList = parseSequenceOf!parseHighLevelExpression(RParen, hasCommas);
                pop(RParen);
                return hasCommas ? new ListNode(exprList) : exprList[0];

            default:
                return parseLiteral();
        }
    }

    /**
      * Parse ident:
      * ident = IDENT (LPAREN ARGS RPAREN)? (DOT IDENT (LP ARGS RP)?| LSPAREN STR LRPAREN)*
      */
    Node parseIdent()
    {
        string name = "";
        Node[] subIdents = [];

        if (next.type == Type.LParen)
            subIdents ~= parseCallExpr();
        else
            name = pop(Type.Ident).value;

        while (true)
        {
            switch (front.type) with (Type)
            {
                case Dot:
                    pop(Dot);
                    if (next.type == Type.LParen)
                        subIdents ~= parseCallExpr();
                    else
                        subIdents ~= new StringNode(pop(Ident).value);
                    break;
                case LSParen:
                    pop(LSParen);
                    subIdents ~= parseHighLevelExpression();
                    pop(RSParen);
                    break;
                default:
                    return new IdentNode(name, subIdents);
            }
        }
    }


    IdentNode parseCallIdent()
    {
        return new IdentNode("", [parseCallExpr()]);
    }


    DictNode parseCallExpr()
    {
        string name = pop(Type.Ident).value;
        Node[] varargs;
        Node[string] kwargs;

        bool parsingKwargs = false;
        void parse()
        {
            if (parsingKwargs || front.type == Type.Ident && next.value == Operator.Assign)
            {
                parsingKwargs = true;
                auto name = pop(Type.Ident).value;
                pop(Operator.Assign);
                kwargs[name] = parseHighLevelExpression();
            }
            else
                varargs ~= parseHighLevelExpression();
        }

        if (front.type == Type.LParen)
        {
            pop(Type.LParen);

            while (front.type != Type.EOF && front.type != Type.RParen)
            {
                parse();

                if (front.type != Type.RParen)
                    pop(Type.Comma);
            }

            pop(Type.RParen);
        }

        Node[string] callDict;
        callDict["name"] = new StringNode(name);
        callDict["varargs"] = new ListNode(varargs);
        callDict["kwargs"] = new DictNode(kwargs);

        return new DictNode(callDict);
    }

    /**
      * literal = string|number|list|tuple|dict
      */
    Node parseLiteral()
    {
        switch (front.type) with (Type)
        {
            case Integer: return new NumNode(pop.value.to!long);
            case Float:   return new NumNode(pop.value.to!double);
            case String:  return new StringNode(pop.value);
            case Boolean: return new BooleanNode(pop.value.to!bool);
            case LParen:  return parseTuple();
            case LSParen: return parseList();
            case LBrace:  return parseDict();
            default:
                throw new JinjaParserException("Unexpected token while parsing expression: %s".fmt(front.value));
        }
    }


    Node parseTuple()
    {
        //Literally array right now

        pop(Type.LParen);
        auto tuple = parseSequenceOf!parseHighLevelExpression(Type.RParen);
        pop(Type.RParen);

        return new ListNode(tuple);
    }


    Node parseList()
    {
        pop(Type.LSParen);
        auto list = parseSequenceOf!parseHighLevelExpression(Type.RSParen);
        pop(Type.RSParen);

        return new ListNode(list);
    }


    Node[] parseSequenceOf(alias parser)(Type stopSymbol)
    {
        bool hasCommas;
        return parseSequenceOf!parser(stopSymbol, hasCommas);
    }


    Node[] parseSequenceOf(alias parser)(Type stopSymbol, ref bool hasCommas)
    {
        Node[] seq;

        hasCommas = false;
        while (front.type != stopSymbol && front.type != Type.EOF)
        {
            seq ~= parser();

            if (front.type != stopSymbol)
            {
                pop(Type.Comma);
                hasCommas = true;
            }
        }

        return seq;
    }


    Node parseDict()
    {
        Node[string] dict;

        pop(Type.LBrace);

        bool isFirst = true;
        while (front.type != Type.RBrace && front.type != Type.EOF)
        {
            if (!isFirst)
                pop(Type.Comma);

            string key;
            if (front.type == Type.Ident)
                key = pop(Type.Ident).value;
            else
                key = pop(Type.String).value;

            pop(Type.Colon);
            dict[key] = parseHighLevelExpression();
            isFirst = false;
        }

        if (front.type == Type.Comma)
            pop(Type.Comma);

        pop(Type.RBrace);

        return new DictNode(dict);
    }


    void parseComment()
    {
        pop(Type.CmntBegin);
        while (front.type != Type.CmntEnd && front.type != Type.EOF)
            pop();
        pop(Type.CmntEnd);
    }


    Token front()
    {
        if (tokens_.length)
            return tokens_[0];
        return Token(Type.EOF);
    }

    Token next()
    {
        if (tokens_.length > 1)
            return tokens_[1];
        return Token(Type.EOF);
    }


    Token pop()
    {
        auto tkn = front();
        if (tokens_.length)
            tokens_ = tokens_[1 .. $];
        return tkn;
    }


    Token pop(Type t)
    {
        if (front.type != t)
            throw new JinjaParserException("Unexpected token %s, expected: %s".fmt(front.value, t));
        return pop();
    }


    Token pop(Keyword kw)
    {
        if (front.type != Type.Keyword || front.value != kw)
            throw new JinjaParserException("Unexpected token %s, expected kw: %s".fmt(front.value, kw));
        return pop();
    }


    Token pop(Operator op)
    {
        if (front.type != Type.Operator || front.value != op)
            throw new JinjaParserException("Unexpected token %s, expected op: %s".fmt(front.value, op));
        return pop();
    }
}

private:

bool isBeginingKeyword(Keyword kw)
{
    import std.algorithm : among;

    return cast(bool)kw.among(
                Keyword.If,
                Keyword.Set,
                Keyword.For,
                Keyword.Block,
                Keyword.Extends,
                Keyword.Macro,
                Keyword.Call,
                Keyword.Filter,
                Keyword.With,
                Keyword.Include,
                Keyword.Import
        );
}
