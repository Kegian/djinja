/**
  * Description of global tests
  *
  * Copyright:
  *     Copyright (c) 2018, Maxim Tyapkin.
  * Authors:
  *     Maxim Tyapkin
  * License:
  *     This software is licensed under the terms of the BSD 3-clause license.
  *     The full terms of the license can be found in the LICENSE.md file.
  */

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
            "list":      wrapper!list,
            "dict":      wrapper!dict,
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


bool list(UniNode value)
{
    return value.kind == UniNode.Kind.array;
}


bool dict(UniNode value)
{
    return value.kind == UniNode.Kind.object;
}
