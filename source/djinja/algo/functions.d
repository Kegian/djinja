module djinja.algo.functions;

private
{
    import djinja.algo.wrapper;
    import djinja.exception : assertJinja = assertJinjaException;
    import djinja.uninode;

    import std.functional : toDelegate;
}


Function[string] globalFunctions()
{
    return cast(immutable)
        [
            "range": toDelegate(&range),
            "length": toDelegate(&length),
            "myRange": wrapper!myRange,
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


UniNode length(UniNode params)
{
    assertJinja(params.kind == UniNode.Kind.object, "Non object params");
    assertJinja(cast(bool)("varargs" in params), "Missing varargs in params");

    if (params["varargs"].length > 0)
        return UniNode(cast(long)params["varargs"][0].length);

    assertJinja(0);
    assert(0);
}


auto myRange(long idx, int i, string s = "asd")
{
    import std.typecons : tuple;
    return tuple([idx, i], s); 
}
