module djinja.exception;


class JinjaException : Exception
{
    @safe
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}



class JinjaLexerException : JinjaException
{
    @safe
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}



class JinjaParserException : JinjaException
{
    @safe
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}



class JinjaRenderException : JinjaException
{
    @safe
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }
}


void assertJinja(E : JinjaException)(bool expr, string msg = "", string file = __FILE__, size_t line = __LINE__)
{
    if (!expr)
        throw new JinjaException(msg, file, line);
}


alias assertJinjaException = assertJinja!JinjaException;
alias assertJinjaLexer = assertJinja!JinjaLexerException;
alias assertJinjaParser = assertJinja!JinjaParserException;
alias assertJinjaRender = assertJinja!JinjaRenderException;
