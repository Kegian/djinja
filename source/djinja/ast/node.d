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
        FilterBlockNode,
        ImportNode,
        IncludeNode,
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
    string[] keys;
    Nullable!Node iterable;
    Nullable!Node block;
    Nullable!Node other;
    Nullable!Node cond;
    bool isRecursive;

    this(string[] keys, Node iterable, Node block, Node other, Node cond, bool isRecursive)
    {
        this.keys = keys;
        this.iterable = iterable.toNullable;
        this.block = block.toNullable;
        this.other = other.toNullable;
        this.cond = cond.toNullable;
        this.isRecursive = isRecursive;
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


class FilterBlockNode : Node
{
    string filterName;
    Nullable!Node args;
    Nullable!Node block;

    this(string filterName, Node args, Node block)
    {
        this.filterName = filterName;
        this.args = args.toNullable;
        this.block = block.toNullable;
    }

    mixin AcceptVisitor;
}



class ImportNode : Node
{
    struct Rename
    {
        string was, become;
    }

    string fileName;
    Rename[] macrosNames;
    Nullable!StmtBlockNode stmtBlock;
    bool withContext;

    this(string fileName, Rename[] macrosNames, StmtBlockNode stmtBlock, bool withContext)
    {
        this.fileName = fileName;
        this.macrosNames = macrosNames;
        this.stmtBlock = stmtBlock.toNullable;
        this.withContext = withContext;
    }

    mixin AcceptVisitor;
}



class IncludeNode : Node
{
    string fileName;
    Nullable!StmtBlockNode stmtBlock;
    bool withContext;

    this(string fileName, StmtBlockNode stmtBlock, bool withContext)
    {
        this.fileName = fileName;
        this.stmtBlock = stmtBlock.toNullable;
        this.withContext = withContext;
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
