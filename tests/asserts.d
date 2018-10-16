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



void assertException(T...)(string tmpl)
{
    try
        renderData!(T)(tmpl);
    catch (Exception e)
        return;
    assert(0, "Exception throw was expected");
}
