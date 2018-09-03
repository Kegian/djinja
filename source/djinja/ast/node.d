module djinja.ast.node;

private
{
    import std.meta : AliasSeq;

    import djinja.ast.visitor;
}

alias NodeTypes = AliasSeq!(
        StmtBlockNode,
        RawNode,
        ExprNode,
        UnaryOpNode,
        BinOpNode,
        NumNode,
        IdentNode,
        IfNode,
    );



interface INode
{
    void accept(IVisitor);
}


mixin template AcceptVisitor()
{
    override void accept(IVisitor visitor)
    {
        visitor.visit(this);
    }
}



abstract class Node : INode
{
    void accept(IVisitor visitor) {}
}



class StmtBlockNode : Node
{
    Node[] children;

    this()
    {
    }

    mixin AcceptVisitor;
}



class RawNode : Node
{
    string raw;

    this(string raw)
    {
        this.raw = raw;
    }

    mixin AcceptVisitor;
}



class ExprNode : Node
{
    Node expr;

    this (Node expr)
    {
        this.expr = expr;
    }

    mixin AcceptVisitor;
}


class BinOpNode : Node
{
    string op;
    Node lhs, rhs;

    this (string op, Node lhs, Node rhs)
    {
        this.op = op;
        this.lhs = lhs;
        this.rhs = rhs;
    }

    mixin AcceptVisitor;
}


class UnaryOpNode : Node
{
    string op;
    Node expr;

    this (string op, Node expr)
    {
        this.op = op;
        this.expr = expr;
    }

    mixin AcceptVisitor;
}


class NumNode : Node
{
    enum Type
    {
        Integer,
        Float,
    }

    union Data
    {
        long _integer;
        double _float;
    }

    Data data;
    Type type;

    this (long num)
    {
        data._integer = num;
        type = Type.Integer;
    }

    this (double num)
    {
        data._float = num;
        type = Type.Float;
    }

    mixin AcceptVisitor;
}


class IdentNode : Node
{
    string name;

    this(string name)
    {
        this.name = name;
    }

    mixin AcceptVisitor;
}


class IfNode : Node
{
    Node cond, then, other;

    this(Node cond, Node then, Node other)
    {
        this.cond = cond;
        this.then = then;
        this.other = other;
    }

    mixin AcceptVisitor;
}
