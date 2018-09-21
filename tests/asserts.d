module tests.asserts;


private
{
    import djinja.djinja;
}


void assertRender(T...)(string tmpl, string expected)
{
    auto result = renderData!(T)(tmpl);
    assert(expected == result, "Expected `"~expected~"`, got `"~result~"`");
}
