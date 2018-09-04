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
        print("Raw block: '%s'".fmt(node.raw));
    }


    override void visit(ExprNode node)
    {
        print("Expression block:");
        _tab++;
        node.expr.accept(this);
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

    override void visit(IdentNode node)
    {
        print("Ident: %s".fmt(node.name));
        if (node.subNames.length)
        {
            _tab++;
            print("Sub names: %s".fmt(node.subNames));
            _tab--;
        }
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


    void print(string str)
    {
        foreach(i; 0 .. _tab)
            w(" -- ");
        wl(str);
    }
}
