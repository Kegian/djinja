module djinja.algo.filters;

private
{
    import djinja.algo.wrapper;
    import djinja.uninode;
}


Function[string] globalFilters()
{
    return cast(immutable)
        [
            "default": wrapper!defaultVal,
            "d":       wrapper!defaultVal,
            "upper":   wrapper!upper,
            "sort":    wrapper!sort,
            "keys":    wrapper!keys,
        ];
}


UniNode defaultVal(UniNode value, UniNode default_value = UniNode(null), bool boolean = false)
{
    //TODO fix
    if (default_value.kind == UniNode.Kind.nil)
        default_value = UniNode("");

    if (value.kind == UniNode.Kind.nil)
        return default_value;

    if (!boolean)
        return value;

    value.toBoolType;
    if (!value.get!bool)
        return default_value;

    return value;
}


string upper(string str)
{
    import std.uni : toUpper;
    return str.toUpper;
}


UniNode sort(UniNode value)
{
    import std.algorithm : sort;

    switch (value.kind) with (UniNode.Kind)
    {
        case array:
            auto arr = value.get!(UniNode[]);
            sort!((a, b) => a.getAsString < b.getAsString)(arr);
            return UniNode(arr);

        case object:
            UniNode[] arr;
            foreach (key, val; value)
            {
                () @trusted {
                    arr ~= UniNode([UniNode(key), val]);
                } ();
            }
            sort!"a[0].get!string < b[0].get!string"(arr);
            return UniNode(arr);

        default:
            return value;
    }
}


UniNode keys(UniNode value)
{
    if (value.kind != UniNode.Kind.object)
        return UniNode(null);

    UniNode[] arr;
    foreach (key, val; value)
    {
        () @trusted {
            arr ~= UniNode(key);
        } ();
    }
    return UniNode(arr);
}
