module djinja.djinja;


private
{
    import std.meta;
    import std.traits;

    import djinja.render;
    import djinja.lexer;
    import djinja.parser;
    import djinja.uninode;
    import djinja.ast;
}


TemplateNode loadData(string tmpl)
{
    alias JinjaLexer = Lexer!("{{", "}}", "{%", "%}", "{#", "#}");

    Parser!JinjaLexer parser;
    auto tree = parser.parseTree(tmpl);
    return tree;
}


TemplateNode loadFile(string path)
{
    alias JinjaLexer = Lexer!("{{", "}}", "{%", "%}", "{#", "#}");

    Parser!JinjaLexer parser;
    auto tree = parser.parseTreeFromFile(tmpl);
    return tree;
}


string render(T...)(TemplateNode tree)
{
    alias Args = AliasSeq!T;
    alias Idents = staticMap!(Ident, T);

    auto render = new Render(tree);

    auto data = UniNode.emptyObject();
    
    foreach (i, arg; Args)
    {
        static if (isSomeFunction!arg)
            render.registerFunction!arg(Idents[i]);
        else
            data[Idents[i]] = arg.serialize;
    }

    return render.render(data.serialize);
}


string renderData(T...)(string tmpl)
{
    return render!(T)(loadData(tmpl));
}


private:


template Ident(alias A)
{
    enum Ident = __traits(identifier, A);
}
