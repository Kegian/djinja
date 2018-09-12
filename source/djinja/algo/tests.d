module djinja.algo.tests;

private
{
    import djinja.algo.wrapper;
    import djinja.uninode;
}


Function[string] globalTests()
{
    return cast(immutable)
        [
            "defined":   wrapper!defined,
            "undefined": wrapper!undefined,
            "number":    wrapper!number,
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

bool number(UniNode value)
{
    return value.isNumericNode;
}
