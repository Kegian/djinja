module djinja.algo.functions;

private
{
    import djinja.algo.wrapper;
    import djinja.exception : assertJinja = assertJinjaException;
    import djinja.uninode;

    import std.functional : toDelegate;
    import std.format : fmt = format;
}


Function[string] globalFunctions()
{
    return cast(immutable)
        [
            "range": toDelegate(&range),
            "length": wrapper!length,
            "namespace": wrapper!namespace,
        ];
}



UniNode range(UniNode params)
{
    import std.range : iota;
    import std.array : array;
    import std.algorithm : map;

    assertJinja(params.kind == UniNode.Kind.object, "Non object params");
    assertJinja(cast(bool)("varargs" in params), "Missing varargs in params");

    if (params["varargs"].length > 0)
    {
        auto length = params["varargs"][0].get!long;
        auto arr = iota(length).map!(a => UniNode(a)).array;
        return UniNode(arr);
    }

    assertJinja(0);
    assert(0);
}


long length(UniNode value)
{
    switch (value.kind) with (UniNode.Kind)
    {
        case array:
        case object:
            return value.length;
        case text:
            return value.get!string.length;
        default:
            assertJinja(0, "Object of type `%s` has no length()".fmt(value.kind));
    }
    assert(0);
}


UniNode namespace(UniNode kwargs)
{
    return kwargs;
}
