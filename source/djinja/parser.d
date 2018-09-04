module djinja.parser;

private
{
    import std.format: fmt = format;
    import std.conv : to;

    import djinja.ast;
    import djinja.lexer;
    import djinja.exception;
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

    void parseTree()
    {
        _root = parseStatementBlock();
        if (front.type != Type.EOF)
            throw new JinjaParserException("Expected EOF found %s".fmt(front.value));
    }

    Node root()
    {
        return _root;
    }

private: 


    Node parseExpression()
    {
        pop(Type.ExprBegin);
        auto expr = parseInlineExpr();
        pop(Type.ExprEnd);
        return new ExprNode(expr);
    }

    Node parseStatementBlock()
    {
        auto block = new StmtBlockNode();

        while (front.type != Type.EOF)
        {
            switch(front.type) with (Type)
            {
                case Raw:
                    block.children ~= new RawNode(pop.value);
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
            case If:
                return parseIf();

            case For:
                return parseFor();

            default:
                assert(0, "Not implemented kw %s".fmt(front.value));
        }

        // return new RawNode("I must be statemnet");
    }


    Node parseFor()
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
        
        //TODO ITERABLE
        auto iterable = parseIdent();

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


    Node parseIf()
    {
        //TODO: If or ElIf
        pop();
        auto cond = parseOrExpr();
        pop(Type.StmtEnd);

        auto then = parseStatementBlock();

        //TODO check else && elifs

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

    /**
      * Parse Or Expression
      * or = and (OR or)
      */
    Node parseOrExpr()
    {
        auto lhs = parseAndExpr();

        if (front.type == Type.Operator && front.value == Operator.Or)
        {
            pop(Operator.Or);
            auto rhs = parseOrExpr();
            return new BinOpNode(Operator.Or, lhs, rhs);
        }

        return lhs;
    }

    /**
      * Parse And Expression:
      * and = cmp (AND and)
      */
    Node parseAndExpr()
    {
        auto lhs = parseCmpExpr();

        if (front.type == Type.Operator && front.value == Operator.And)
        {
            pop(Operator.And);
            auto rhs = parseAndExpr();
            return new BinOpNode(Operator.And, lhs, rhs);
        }

        return lhs;
    }

    /**
      * Parse compare expression:
      * cmp = expr (CMPOP expr)?
      */
    Node parseCmpExpr()
    {
        auto lhs = parseInlineExpr();

        if (front.type == Type.Operator && front.value.toOperator.isCmpOperator)
            return new BinOpNode(pop.value, lhs, parseInlineExpr);

        return lhs;
    }


    /**
      * Parse expression:
      * expr = term((PLUS|MINUS)expr)?
      */
    Node parseInlineExpr()
    {
        auto lhsTerm = parseTerm();
        if (front.type != Type.Operator)
            return lhsTerm;

        switch (front.value) with (Operator)
        {
            case Plus:
            case Minus:
                auto op = pop.value;
                return new BinOpNode(op, lhsTerm, parseInlineExpr());
            default:
                return lhsTerm;
        }
    }

    /**
      * Parse term:
      * term = factor((MUL|DIVI|DIVF)term)?
      */
    Node parseTerm()
    {
        auto lhsFactor = parseFactor();
        if (front.type != Type.Operator)
            return lhsFactor;
    
        switch (front.value) with (Operator)
        {
            case DivInt:
            case DivFloat:
            case Mul:
            case Rem:
                auto op = pop.value;
                return new BinOpNode(op, lhsFactor, parseTerm());

            default:
                return lhsFactor;
        }
        
    }

    /**
      * Parse factor:
      * factor = (INTEGER|FLOAT|ident|LPAREN OrExpr RPAREN)
      */
    Node parseFactor()
    {
        switch (front.type) with (Type)
        {
            case Integer:
                return new NumNode(pop.value.to!long);

            case Float:
                return new NumNode(pop.value.to!double);

            case Ident:
                return parseIdent();

            case LParen:
                pop(LParen);
                auto expr = parseOrExpr();
                pop(RParen);
                return expr;

            default:
                throw new JinjaParserException("Unexpected token while parsing expression: %s".fmt(front.value));
        }
    }

    /**
      * Parse ident:
      * ident = IDENT(DOT IDENT| LSPAREN STR LRPAREN IDENT)?
      */
    Node parseIdent()
    {
        string parseName()
        {
            string name;
            switch (front.type) with (Type)
            {
                case Ident:
                    name = pop(Ident).value;
                    break;
                case LSParen:
                    pop(LSParen);
                    name = pop(String).value;
                    pop(RSParen);
                    break;
                default:
                    throw new JinjaParserException("Unexpected token %s".fmt(front.type));
            }
            return name;
        }
        string name = parseName();
        string[] subNames = [];

        while (true)
        {
            switch (front.type) with (Type)
            {
                case Dot:
                    pop(Dot);
                    subNames ~= pop(Ident).value;
                    break;
                case LSParen:
                    pop(LSParen);
                    subNames ~= pop(String).value;
                    pop(RSParen);
                    break;
                default:
                    return new IdentNode(name, subNames);
            }
        }
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
            throw new JinjaException("Unexpected token %s, expected: %s".fmt(front.value, t));
        return pop();
    }


    Token pop(Keyword kw)
    {
        if (front.type != Type.Keyword || front.value != kw)
            throw new JinjaException("Unexpected token %s, expected kw: %s".fmt(front.value, kw));
        return pop();
    }


    Token pop(Operator op)
    {
        if (front.type != Type.Operator || front.value != op)
            throw new JinjaException("Unexpected token %s, expected op: %s".fmt(front.value, op));
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
            Keyword.Include,
            Keyword.Import
    );
}
