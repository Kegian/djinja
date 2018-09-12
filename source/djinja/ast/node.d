module djinja.ast.node;

public
{
    import std.typecons : Nullable, nullable;
}

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
        StringNode,
        BooleanNode,
        NilNode,
        ListNode,
        DictNode,
        NumNode,
        IdentNode,
        IfNode,
        ForNode,
        SetNode,
        AssignableNode,
        MacroNode,
        CallNode,
        InlineIfNode,
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
    Nullable!Node expr;

    this (Node expr)
    {
        this.expr = expr.toNullable;
    }

    mixin AcceptVisitor;
}


class InlineIfNode : Node
{
    Nullable!Node expr, cond, other;

    this (Node expr, Node cond, Node other)
    {
        this.expr = expr.toNullable;
        this.cond = cond.toNullable;
        this.other = other.toNullable;
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


class BooleanNode : Node
{
    bool boolean;

    this(bool boolean)
    {
        this.boolean = boolean;
    }

    mixin AcceptVisitor;
}


class NilNode : Node
{
    mixin AcceptVisitor;
}


class IdentNode : Node
{
    string name;
    Node[] subIdents;


    this(string name, Node[] subIdents)
    {
        this.name = name;
        this.subIdents = subIdents;
    }

    mixin AcceptVisitor;
}


class AssignableNode : Node
{
    string name;
    Node[] subIdents;


    this(string name, Node[] subIdents)
    {
        this.name = name;
        this.subIdents = subIdents;
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


class ForNode : Node
{
    string key, value;
    Node iterable;
    Node block;
    Node other;


    this(string key, string value, Node iterable, Node block, Node other)
    {
        this.key = key;
        this.value = value;
        this.iterable = iterable;
        this.block = block;
        this.other = other;
    }

    mixin AcceptVisitor;
}


class StringNode : Node
{
    string str;

    this(string str)
    {
        this.str = str;
    }

    mixin AcceptVisitor;
}


class ListNode : Node
{
    Node[] list;

    this(Node[] list)
    {
        this.list = list;
    }

    mixin AcceptVisitor;
}


class DictNode : Node
{
    Node[string] dict;

    this(Node[string] dict)
    {
        this.dict = dict;
    }

    mixin AcceptVisitor;
}


class SetNode : Node
{
    Node[] assigns;
    Node expr;

    this(Node[] assigns, Node expr)
    {
        this.assigns = assigns;
        this.expr = expr;
    }

    mixin AcceptVisitor;
}


class MacroNode : Node
{
    string name;
    Arg[] args;
    Nullable!Node block;
    bool isReturn;

    this(string name, Arg[] args, Node block, bool isReturn)
    {
        this.name = name;
        this.args = args;
        this.block = block.toNullable;
        this.isReturn = isReturn;
    }

    mixin AcceptVisitor;
}


class CallNode : Node
{
    string macroName;
    Arg[] formArgs;
    Nullable!Node factArgs;
    Nullable!Node block;

    this(string macroName, Arg[] formArgs, Node factArgs, Node block)
    {
        this.macroName = macroName;
        this.formArgs = formArgs;
        this.factArgs = factArgs.toNullable;
        this.block = block.toNullable;
    }

    mixin AcceptVisitor;
}



struct Arg
{
    string name;
    Nullable!Node defaultExpr;

    this(string name, Node def)
    {
        this.name = name;
        this.defaultExpr = def.toNullable;
    }
}



auto toNullable(T)(T val)
    if (is(T == class))
{
    if (val is null)
        return Nullable!T.init;
    else
        return Nullable!T(val);
}
