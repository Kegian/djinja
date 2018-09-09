module djinja.algo.functions;

private
{
    import uninode.core;
}

auto functionList()
{
    return cast(immutable)
        [
            "range": &range,
            "length": &length,
        ];
}

alias Function = UniNode function(UniNode);


UniNode range(UniNode params)
{
    import std.range : iota;
    import std.array : array;
    import std.algorithm : map;

    auto length = params["varargs"][0].get!long;
    auto arr = iota(length).map!(a => UniNode(a)).array;
    return UniNode(arr);
}


UniNode length(UniNode params)
{
    return UniNode(cast(long)params["varargs"][0].length);
}


private:

