module djinja.algo.filters;

private
{
    import djinja.algo.wrapper;
    import djinja.uninode;
}


immutable(UniNode function(UniNode))[string] globalFilters()
{
    return cast(immutable)
        [
            "default": &wrapper!defaultVal,
            "d": &wrapper!defaultVal,
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
