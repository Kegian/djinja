module djinja.lexer;


private
{
    import djinja.exception : JinjaException;

    import std.traits : EnumMembers;
}


enum Type
{
    Unknown,
    Raw,
    Keyword,
    Operator,
    
    StmtBegin,
    StmtEnd,
    ExprBegin,
    ExprEnd,
    CmntBegin,
    CmntEnd,

    Ident,
    Integer,
    Float,
    String,

    LParen,
    RParen,
    LSParen,
    RSParen,
    LBrace,
    RBrace,

    Dot,
    Comma,
    Colon,

    EOL,
    EOF,
}


enum Keyword : string
{
    Unknown = "",
    For = "for",
    EndFor = "endfor",
    If = "if",
    ElIf = "elif",
    Else = "else",
    EndIf = "endif",
    Block = "block",
    EndBlock = "endblock",
    Extends = "extends",
    Macro = "macro",
    EndMacro = "endmacro",
    Call = "call",
    EndCall = "endcall",
    Filter = "filter",
    EndFilter = "endfilter",
    Set = "set",
    EndSet = "endset",
    Include = "include",
    Import = "import",
}

Keyword toKeyword(string key)
{
    switch (key) with (Keyword)
    {
        static foreach(member; EnumMembers!Keyword)
        {
            case member:
                return member;
        }
        default :
            return Unknown;
    }
}


bool isKeyword(string key)
{
    return key.toKeyword != Keyword.Unknown;
}


enum Operator : string
{
    // The first in order is the first in priority

    Eq = "==",
    NotEq = "!=",
    LessEq = "<=",
    GreaterEq = ">=",
    Less = "<",
    Greater = ">",

    And = "and",
    Or = "or",
    Not = "not",

    In = "in",
    Is = "is",

    Assign = "=",
    Filter = "|",
    Concat = "~",

    Plus = "+",
    Minus = "-",

    DivInt = "//",
    DivFloat = "/",
    Rem = "%",
    Pow = "**",
    Mul = "*",
}


Operator toOperator(string key)
{
    switch (key) with (Operator)
    {
        static foreach(member; EnumMembers!Operator)
        {
            case member:
                return member;
        }
        default :
            return cast(Operator)"";
    }
}


bool isCmpOperator(Operator op)
{
    import std.algorithm : among;

    return cast(bool)op.among(
            Operator.Eq,
            Operator.NotEq,
            Operator.LessEq,
            Operator.GreaterEq,
            Operator.Less,
            Operator.Greater
        );
}



struct Token
{
    Type type;

    string value;

    this (Type t)
    {
        type = t;
    }

    this(Type t, string v)
    {
        type = t;
        value = v;
    }
}


struct Lexer(
        string exprOpBegin, string exprOpEnd,
        string stmtOpBegin, string stmtOpEnd,
        string cmntOpBegin, string cmntOpEnd)
{
    static assert(exprOpBegin.length, "Expression begin operator can't be empty");
    static assert(exprOpEnd.length, "Expression end operator can't be empty");

    static assert(stmtOpBegin.length, "Statement begin operator can't be empty");
    static assert(stmtOpEnd.length, "Statement end operator can't be empty");

    static assert(cmntOpBegin.length, "Comment begin operator can't be empty");
    static assert(cmntOpEnd.length, "Comment end operator can't be empty");

    //TODO check uniq

    
    enum EOF = 255;

    private
    {
        bool _isReadingRaw;
        string _str;
    }

    this(string str)
    {
        _str = str;
        _isReadingRaw = true;
    }

    Token nextToken()
    {
        // Try to read raw data
        if (_isReadingRaw)
        {
            auto raw = skipRaw();
            _isReadingRaw = false;
            if (raw.length)
                return Token(Type.Raw, raw);
        }

        skipWhitespaces();

        // Check begin operators
        if (exprOpBegin == front(exprOpBegin.length))
        {
            skip(exprOpBegin.length);
            return Token(Type.ExprBegin, exprOpBegin);
        }
        if (stmtOpBegin == front(stmtOpBegin.length))
        {
            skip(stmtOpBegin.length);
            return Token(Type.StmtBegin, stmtOpBegin);
        }
        if (cmntOpBegin == front(cmntOpBegin.length))
        {
            skip(cmntOpBegin.length);
            skipComment();
            return Token(Type.CmntBegin, cmntOpBegin);
        }

        // Check end operators
        if (exprOpEnd == front(exprOpEnd.length))
        {
            _isReadingRaw = true;
            skip(exprOpEnd.length);
            return Token(Type.ExprEnd, exprOpEnd);
        }
        if (stmtOpEnd == front(stmtOpEnd.length))
        {
            _isReadingRaw = true;
            skip(stmtOpEnd.length);
            return Token(Type.StmtEnd, stmtOpEnd);
        }
        if (cmntOpEnd == front(cmntOpEnd.length))
        {
            _isReadingRaw = true;
            skip(cmntOpEnd.length);
            return Token(Type.CmntEnd, cmntOpEnd);
        }


        // Trying to read operators
        static foreach(op; EnumMembers!Operator)
        {
            if (cast(string)op == front(op.length))
            {
                skip(op.length);
                return Token(Type.Operator, op);
            }
        }

        // Check remainings 
        switch (front)
        {
            // End of file
            case EOF:
                return Token(Type.EOF);


            // Identifier or keyword
            case 'a': .. case 'z':
            case 'A': .. case 'Z':
            case '_':
                auto ident = popIdent();
                if (ident.toKeyword != Keyword.Unknown)
                    return Token(Type.Keyword, ident);
                else
                    return Token(Type.Ident, ident);

            // Integer or float
            case '0': .. case '9':
                return readNumber();

            // String
            case '"':
            case '\'':
                return Token(Type.String, popString());
                
            case '(': return Token(Type.LParen, [pop]);
            case ')': return Token(Type.RParen, [pop]);
            case '[': return Token(Type.LSParen, [pop]);
            case ']': return Token(Type.RSParen, [pop]);
            case '{': return Token(Type.LBrace, [pop]);
            case '}': return Token(Type.RBrace, [pop]);
            case '.': return Token(Type.Dot, [pop]);
            case ',': return Token(Type.Comma, [pop]);
            case ':': return Token(Type.Colon, [pop]);

            default:
                return Token(Type.Unknown, [pop]);
        }
    }


private:


    char front()
    {
        if (_str.length > 0)
            return _str[0];
        else
            return EOF;
    }


    string front(uint num)
    {
        if (num >= _str.length)
            return _str;
        else
            return _str[0 .. num];
    }


    char next()
    {
        if (_str.length > 1)
            return _str[1];
        else
            return EOF;
    }

    char pop()
    {
        if (_str.length > 0)
        {
            auto prev  = _str[0];
            _str = _str[1 .. $];
            return prev;
        } 
        else
            return EOF;
    }

    void skip(uint num)
    {
        if (num >= _str.length)
            _str = "";
        else
            _str = _str[num .. $];
    }


    void skipWhitespaces()
    {
        while (true)
        {
            switch (front)
            {
                case ' ':
                case '\n':
                case '\t':
                case '\r':
                    pop();
                    break;
                default:
                    return;
            }
        }
    }


    string popIdent()
    {
        string ident = "";
        while (true)
        {
            switch(front)
            {
                case 'a': .. case 'z':
                case 'A': .. case 'Z':
                case '0': .. case '9':
                case '_':
                    ident ~= pop();
                    break;
                default:
                    return ident;
            }
        }
    }


    Token readNumber()
    {
        auto type = Type.Integer;
        string number = "";

        while (true)
        {
            switch (front)
            {
                case '0': .. case '9':
                    number ~= pop();
                    break;
                case '.':
                    if (type == Type.Integer)
                    {
                        type = Type.Float;
                        number ~= pop();
                    }
                    else
                        return Token(type, number);
                    break;
                case '_':
                    pop();
                    break;
                default:
                    return Token(type, number);
            }
        }
    }


    string popString()
    {
        auto ch = pop();
        string str = "";
        auto prev = ch;

        while (true)
        {
            if (front == EOF)
                return str;

            if (front == ch && prev != '\\')
            {
                pop();
                return str;
            }

            prev = pop();
            str ~= prev;
        }
    }


    string skipRaw()
    {
        string raw = "";

        while (true)
        {
            if (front == EOF)
                return raw;

            if (exprOpBegin == front(exprOpBegin.length))
                return raw;
            if (stmtOpBegin == front(stmtOpBegin.length))
                return raw;
            if (cmntOpBegin == front(cmntOpBegin.length))
                return raw;
            
            raw ~= pop();
        }
    }


    void skipComment()
    {
        while(front != EOF)
        {
            if (cmntOpEnd == front(cmntOpEnd.length))
                return;
            pop();
        }
    }
}
