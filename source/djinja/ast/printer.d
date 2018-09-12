module djinja.ast.printer;

private
{
    import djinja.ast.node;
    import djinja.ast.visitor;
}


class NullVisitor : IVisitor
{
    static foreach(NT; NodeTypes)
    {
        void visit(NT node)
        {
            import std.stdio: wl = writeln;
            wl("# ", NT.stringof, " #");
        }
    }
}


class Printer : NullVisitor
{
    import std.stdio: wl = writeln, w = write;
    import std.format: fmt = format;

    uint _tab = 0;

    override void visit(StmtBlockNode node)
    {
        print("Statement Block:"); 
        _tab++;
        foreach(ch; node.children)
        {
            ch.accept(this);
        }
        _tab--;
    }


    override void visit(RawNode node)
    {
        import std.array : replace;
        print("Raw block: \"%s\"".fmt(node.raw.replace("\n", "\\n").replace(" ", ".")));
    }


    override void visit(ExprNode node)
    {
        print("Expression block:");
        _tab++;
        node.expr.accept(this);
        _tab--;
    }


    override void visit(InlineIfNode node)
    {
        print("Inline If:");

        _tab++;

        if (node.cond.isNull)
            print("If: NONE");
        else
        {
            print("If:");
            _tab++;
            node.cond.accept(this);
            _tab--;
        }
        
        print("Expression:");
        _tab++;
        node.expr.accept(this);
        _tab--;

        if (node.other.isNull)
            print("Else: nil");
        else
        {
            print("Else:");
            _tab++;
            node.other.accept(this);
            _tab--;
        }

        _tab--;
    }


    override void visit(BinOpNode node)
    {
        print("BinaryOp: %s".fmt(node.op));
        _tab++;
        node.lhs.accept(this);
        node.rhs.accept(this);
        _tab--;
    }

    override void visit(UnaryOpNode node)
    {
        print("UnaryOp: %s".fmt(node.op));
        _tab++;
        node.expr.accept(this);
        _tab--;
    }

    override void visit(NumNode node)
    {
        if (node.type == NumNode.Type.Integer)
            print("Integer: %d".fmt(node.data._integer));
        else
            print("Float: %f".fmt(node.data._float));
    }

    override void visit(BooleanNode node)
    {
        print("Bool: %s".fmt(node.boolean));
    }

    override void visit(NilNode node)
    {
        print("Nil");
    }

    override void visit(IdentNode node)
    {
        print("Ident: '%s'".fmt(node.name));
        if (node.subIdents.length)
        {
            print("Sub idents:");
            _tab++;
            foreach (id; node.subIdents)
                id.accept(this);
            _tab--;
        }
    }

    override void visit(AssignableNode node)
    {
        print("Assignable: %s".fmt(node.name));
        if (node.subIdents.length)
        {
            _tab++;
            print("Sub idents:");
            _tab++;
            foreach (id; node.subIdents)
                id.accept(this);
            _tab--;
            _tab--;
        }
    }

    override void visit(StringNode node)
    {
        print("String: %s".fmt(node.str));
    }


    override void visit(ListNode node)
    {
        print("List:");
        _tab++;
        foreach (l; node.list)
            l.accept(this);
        _tab--;
    }

    override void visit(DictNode node)
    {
        print("Dict:");
        _tab++;
        foreach (key, value; node.dict)
        {
            print("Key: %s".fmt(key));
            print("Value:");
            _tab++;
            value.accept(this);
            _tab--;
        }
        _tab--;
    }

    override void visit(IfNode node)
    {
        print("If:");
        _tab++;

        print("Condition:");
        _tab++;
        node.cond.accept(this);
        _tab--;

        print("Then:");
        _tab++;
        node.then.accept(this);
        _tab--;

        if (node.other)
        {
            print("Else:");
            _tab++;
            node.other.accept(this);
            _tab--;
        }
        else
            print("Else: NONE");
        _tab--;
    }

    override void visit(ForNode node)
    {
        print("For: %s, %s".fmt(node.key, node.value));
        _tab++;

        print("Iterable:");
        _tab++;
        node.iterable.accept(this);
        _tab--;

        print("Block:");
        _tab++;
        node.block.accept(this);
        _tab--;

        if (node.other)
        {
            print("Else:");
            _tab++;
            node.other.accept(this);
            _tab--;
        }
        else
            print("Else: NONE");

        _tab--;
    }


    override void visit(SetNode node)
    {
        print("Set:");
        _tab++;

        print("Assigns:");
        _tab++;
        foreach (assign; node.assigns)
            assign.accept(this);
        _tab--;

        print("Expression:");
        _tab++;
        node.expr.accept(this);
        _tab--;

        _tab--;
    }


    override void visit(MacroNode node)
    {
        print("Macro: '%s'".fmt(node.name));

        _tab++;
        if (!node.args.length)
            print("Args: NONE");
        else
        {
            print("Args:");
            _tab++;
            foreach(arg; node.args)
            {
                print("Name: %s".fmt(arg.name));
                if (!arg.defaultExpr.isNull)
                {
                    _tab++;
                    print("Default:");
                    _tab++;
                    arg.defaultExpr.accept(this);
                    _tab--;
                    _tab--;
                }
            }
            _tab--;
        }

        print("Body:");
        _tab++;
        node.block.accept(this);
        _tab--;

        _tab--;

        print("Return: %s".fmt(node.isReturn));
    }


    override void visit(CallNode node)
    {
        print("Call: '%s'".fmt(node.macroName));

        _tab++;

        if (!node.formArgs.length)
            print("Formal args: NONE");
        else
        {
            print("Formal args:");
            _tab++;
            foreach(arg; node.formArgs)
            {
                print("Name: %s".fmt(arg.name));
                if (!arg.defaultExpr.isNull)
                {
                    _tab++;
                    print("Default:");
                    _tab++;
                    arg.defaultExpr.accept(this);
                    _tab--;
                    _tab--;
                }
            }
            _tab--;
        }

        if (node.factArgs.isNull)
            print("Fact args: NONE");
        else
        {
            print("Fact args:");
            _tab++;
            node.factArgs.accept(this);
            _tab--;
        }

        print("Body:");
        _tab++;
        node.block.accept(this);
        _tab--;

        _tab--;
    }


    void print(string str)
    {
        foreach(i; 0 .. _tab)
            w(" -- ");
        wl(str);
    }
}
