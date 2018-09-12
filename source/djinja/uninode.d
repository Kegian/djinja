module djinja.uninode;

public
{
    import uninode.core;
    import uninode.serialization :
                serialize = serializeToUniNode,
                deserialize = deserializeUniNode;
}

private
{
    import std.algorithm : among;
    import std.format: fmt = format;
    import std.conv : to;

    import djinja.lexer;
    import djinja.exception : JinjaRenderException,
                              assertJinja = assertJinjaRender;
}


bool isNumericNode(ref UniNode n)
{
    return cast(bool)n.kind.among!(
            UniNode.Kind.integer,
            UniNode.Kind.uinteger,
            UniNode.Kind.floating
        );
}


bool isIntNode(ref UniNode n)
{
    return cast(bool)n.kind.among!(
            UniNode.Kind.integer,
            UniNode.Kind.uinteger
        );
}


bool isFloatNode(ref UniNode n)
{
    return n.kind == UniNode.Kind.floating;
}


void toCommonNumType(ref UniNode n1, ref UniNode n2)
{
    assertJinja(n1.isNumericNode, "Not a numeric type of %s".fmt(n1));
    assertJinja(n2.isNumericNode, "Not a numeric type of %s".fmt(n2));

    if (n1.isIntNode && n2.isFloatNode)
    {
        n1 = UniNode(n1.get!long.to!double);
        return;
    }

    if (n1.isFloatNode && n2.isIntNode)
    {
        n2 = UniNode(n2.get!long.to!double);
        return;
    }
}


void toCommonCmpType(ref UniNode n1, ref UniNode n2)
{
    //TODO string, list, tuple, dict
   if (n1.isNumericNode && n2.isNumericNode)
   {
       toCommonNumType(n1, n2);
       return;
   }
   if (n1.kind != n2.kind)
       throw new JinjaRenderException("Not comparable types %s and %s".fmt(n1.kind, n2.kind));
}


void toBoolType(ref UniNode n)
{
    switch (n.kind) with (UniNode.Kind)
    {
        case boolean:
            return;
        case integer:
        case uinteger:
            n = UniNode(n.get!long != 0);
            return;
        case floating:
            n = UniNode(n.get!double != 0);
            return;
        case text:
            n = UniNode(n.get!string.length > 0);
            return;
        case array:
        case object:
            n = UniNode(n.length > 0);
            return;
        case nil:
            n = UniNode(false);
            return;
        default:
            throw new JinjaRenderException("Can't cast type %s to bool".fmt(n.kind));
    }
}


void toStringType(ref UniNode n) @safe
{
    import std.algorithm : map;
    import std.string : join;

    string getString(UniNode n)
    {
        n.toStringType;
        return n.get!string;
    }

    string doSwitch() @safe
    {
        switch (n.kind) with (UniNode.Kind)
        {
            case nil:      return "";
            case boolean:  return n.get!bool.to!string;
            case integer:  return n.get!long.to!string;
            case uinteger: return n.get!ulong.to!string;
            case floating: return n.get!double.to!string;
            case text:     return n.get!string;
            case raw:      return n.get!(ubyte[]).to!string;
            case array:    return "["~n.get!(UniNode[]).map!(a => getString(a)).join(", ").to!string~"]";
            case object:
                string[] results;
                foreach (key, ref value; n)
                    results ~= key ~ ": " ~ getString(value);
                return "{" ~ results.join(", ").to!string ~ "}";
            default: return "[UnknownObj: %s]".fmt(n.toString);
        }
    }

    n = UniNode(doSwitch());
}


void checkNodeType(ref UniNode n, UniNode.Kind kind)
{
    if (n.kind != kind)
        throw new JinjaRenderException("Unexpected expression type %s, expcted %s".fmt(n.kind, kind));
}



UniNode unary(string op)(UniNode lhs)
    if (op.among!(Operator.Plus,
                 Operator.Minus)
    )
{
    assertJinja(lhs.isIntNode, "Expected int got %s".fmt(lhs.kind));

    if (lhs.isIntNode)
        return UniNode(mixin(op ~ "lhs.get!long"));
    else
        return UniNode(mixin(op ~ "lhs.get!double"));
}



UniNode unary(string op)(UniNode lhs)
    if (op == Operator.Not)
{
    lhs.toBoolType;
    return UniNode(!lhs.get!bool);
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op.among!(Operator.Plus,
                 Operator.Minus,
                 Operator.Mul,
                 Operator.DivFloat,
                 Operator.Rem)
    )
{
    toCommonNumType(lhs, rhs);
    if (lhs.isIntNode)
        return UniNode(mixin("lhs.get!long" ~ op ~ "rhs.get!long"));
    else
        return UniNode(mixin("lhs.get!double" ~ op ~ "rhs.get!double"));
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.DivInt)
{
    assertJinja(lhs.isIntNode, "Expected int got %s".fmt(lhs.kind));
    assertJinja(rhs.isIntNode, "Expected int got %s".fmt(rhs.kind));
    return UniNode(lhs.get!long / rhs.get!long);
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.Pow)
{
    toCommonNumType(lhs, rhs);
    if (lhs.isIntNode)
        return UniNode(lhs.get!long ^^ rhs.get!long);
    else
        return UniNode(lhs.get!double ^^ rhs.get!double);
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op.among!(Operator.Eq, Operator.NotEq))
{
    toCommonCmpType(lhs, rhs);
    return UniNode(mixin("lhs" ~ op ~ "rhs"));
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op.among!(Operator.Less,
                  Operator.LessEq,
                  Operator.Greater,
                  Operator.GreaterEq)
       )
{
    toCommonCmpType(lhs, rhs);
    switch (lhs.kind) with (UniNode.Kind)
    {
        case integer:
        case uinteger:
            return UniNode(mixin("lhs.get!long" ~ op ~ "rhs.get!long"));
        case floating:
            return UniNode(mixin("lhs.get!double" ~ op ~ "rhs.get!double"));
        case text:
            return UniNode(mixin("lhs.get!string" ~ op ~ "rhs.get!string"));
        default:
            throw new JinjaRenderException("Not comparable type %s".fmt(lhs.kind));
    }
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.Or)
{
    lhs.toBoolType;
    rhs.toBoolType;
    return UniNode(lhs.get!bool || rhs.get!bool);
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.And)
{
    lhs.toBoolType;
    rhs.toBoolType;
    return UniNode(lhs.get!bool && rhs.get!bool);
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.Concat)
{
    lhs.toStringType;
    rhs.toStringType;
    return UniNode(lhs.get!string ~ rhs.get!string);
}



UniNode binary(string op)(UniNode lhs, UniNode rhs)
    if (op == Operator.In)
{
    import std.algorithm.searching : countUntil;

    switch (rhs.kind) with (UniNode.Kind)
    {
        case array:
            foreach(val; rhs)
            {
                if (val == lhs)
                    return UniNode(true);
            }
            return UniNode(false);
        case object:
            if (lhs.kind != UniNode.Kind.text)
                return UniNode(false);
            return UniNode(cast(bool)(lhs.get!string in rhs));
        case text:
            if (lhs.kind != UniNode.Kind.text)
                return UniNode(false);
            return UniNode(rhs.get!string.countUntil(lhs.get!string) >= 0);
        default:
            return UniNode(false);
    }
}
