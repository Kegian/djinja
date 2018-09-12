module djinja.algo.tests;

private
{
    import djinja.algo.wrapper;
    import djinja.uninode;
}


immutable(UniNode function(UniNode))[string] globalTests()
{
    return cast(immutable)
        [
            "defined": &wrapper!defined,
            "undefined": &wrapper!undefined,
        ];
}


bool defined(UniNode value)
{
    return value.kind != UniNode.Kind.nil;
}


bool undefined(UniNode value)
{
    return value.kind == UniNode.Kind.nil;
}
