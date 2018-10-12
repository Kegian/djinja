module djinja.lexer;


private
{
    import djinja.exception : JinjaException;

    import std.conv : to;
    import std.traits : EnumMembers;
    import std.utf;
    import std.range;
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
    CmntInline,

    Ident,
    Integer,
    Float,
    Boolean,
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
    Recursive = "recursive",
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
    Return = "return",
    Call = "call",
    EndCall = "endcall",
    Filter = "filter",
    EndFilter = "endfilter",
    With = "with",
    EndWith = "endwith",
    Set = "set",
    EndSet = "endset",
    Ignore = "ignore",
    Missing = "missing",
    Import = "import",
    From = "from",
    As = "as",
    Without = "without",
    Context = "context",
    Include = "include",
}

bool isBeginingKeyword(Keyword kw)
{
    import std.algorithm : among;

    return cast(bool)kw.among(
                Keyword.If,
                Keyword.Set,
                Keyword.For,
                Keyword.Block,
                Keyword.Extends,
                Keyword.Macro,
                Keyword.Call,
                Keyword.Filter,
                Keyword.With,
                Keyword.Include,
                Keyword.Import,
                Keyword.From,
        );
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


bool isBoolean(string key)
{
    return key == "true" || key == "false" ||
           key == "True" || key == "False";
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

bool isOperator(string key)
{
    switch (key) with (Operator)
    {
        static foreach(member; EnumMembers!Operator)
        {
            case member:
        }
                return true;
        default :
            return false;
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


bool isIdentOperator(Operator op)()
{
    import std.algorithm : filter;
    import std.uni : isAlphaNum;

    static if (!(cast(string)op).filter!isAlphaNum.empty)
        return true;
    else
        return false;
}


struct TokenPos
{
    string filename;
    ulong line, column;
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

    bool opEquals(Type type){
        return this.type == type;
    }

    bool opEquals(Keyword kw){
        return this.type == Type.Keyword && value == kw;
    }

    bool opEquals(Operator op){
        return this.type == Type.Operator && value == op;
    }
}


struct Lexer(
        string exprOpBegin, string exprOpEnd,
        string stmtOpBegin, string stmtOpEnd,
        string cmntOpBegin, string cmntOpEnd,
        string stmtOpInline, string cmntOpInline)
{
    static assert(exprOpBegin.length, "Expression begin operator can't be empty");
    static assert(exprOpEnd.length, "Expression end operator can't be empty");

    static assert(stmtOpBegin.length, "Statement begin operator can't be empty");
    static assert(stmtOpEnd.length, "Statement end operator can't be empty");

    static assert(cmntOpBegin.length, "Comment begin operator can't be empty");
    static assert(cmntOpEnd.length, "Comment end operator can't be empty");

    static assert(stmtOpInline.length, "Statement inline operator can't be empty");
    static assert(cmntOpInline.length, "Comment inline operator can't be empty");

    //TODO check uniq


    enum stmtInline = stmtOpInline;
    enum EOF = 255;

    private
    {
        bool _isReadingRaw; // State of reading raw data
        bool _isInlineStmt; // State of reading inline statement
        string _str;
        string _filename;
        ulong _line, _column;
    }

    this(string str, string filename = "")
    {
        _str = str;
        _isReadingRaw = true;
        _isInlineStmt = false;
        _filename = filename;
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

        // Check inline statement end
        if (_isInlineStmt && tryToSkipNewLine())
        {
            _isInlineStmt = false;
            _isReadingRaw = true;
            return Token(Type.StmtEnd, "\n");
        }

        // Allow multiline inline statements with '\'
        while (true)
        {
            if (_isInlineStmt && front == '\\')
            {
                pop();
                if (!tryToSkipNewLine())
                    return Token(Type.Unknown, "\\");
            }
            else
                break;

            skipWhitespaces();
        }

        // Check begin operators
        if (exprOpBegin == slice(exprOpBegin.length))
        {
            skip(exprOpBegin.length);
            return Token(Type.ExprBegin, exprOpBegin);
        }
        if (stmtOpBegin == slice(stmtOpBegin.length))
        {
            skip(stmtOpBegin.length);
            return Token(Type.StmtBegin, stmtOpBegin);
        }
        if (cmntOpBegin == slice(cmntOpBegin.length))
        {
            skip(cmntOpBegin.length);
            skipComment();
            return Token(Type.CmntBegin, cmntOpBegin);
        }

        // Check end operators
        if (exprOpEnd == slice(exprOpEnd.length))
        {
            _isReadingRaw = true;
            skip(exprOpEnd.length);
            return Token(Type.ExprEnd, exprOpEnd);
        }
        if (stmtOpEnd == slice(stmtOpEnd.length))
        {
            _isReadingRaw = true;
            skip(stmtOpEnd.length);
            return Token(Type.StmtEnd, stmtOpEnd);
        }
        if (cmntOpEnd == slice(cmntOpEnd.length))
        {
            _isReadingRaw = true;
            skip(cmntOpEnd.length);
            return Token(Type.CmntEnd, cmntOpEnd);
        }

        // Check begin inline operators
        if (cmntOpInline == slice(cmntOpInline.length))
        {
            skipInlineComment();
            _isReadingRaw = true;
            return Token(Type.CmntInline);
        }
        if (stmtOpInline == slice(stmtOpInline.length))
        {
            skip(stmtOpInline.length);
            _isInlineStmt = true;
            return Token(Type.StmtBegin, stmtOpInline);
        }

        // Trying to read non-ident operators
        static foreach(op; EnumMembers!Operator)
        {
            static if (!isIdentOperator!op)
            {
                if (cast(string)op == slice(op.length))
                {
                    skip(op.length);
                    return Token(Type.Operator, op);
                }
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
                else if (ident.isBoolean)
                    return Token(Type.Boolean, ident);
                else if (ident.isOperator)
                    return Token(Type.Operator, ident);
                else
                    return Token(Type.Ident, ident);

            // Integer or float
            case '0': .. case '9':
                return readNumber();

            // String
            case '"':
            case '\'':
                return Token(Type.String, popString());
                
            case '(': return Token(Type.LParen, popChar);
            case ')': return Token(Type.RParen, popChar);
            case '[': return Token(Type.LSParen, popChar);
            case ']': return Token(Type.RSParen, popChar);
            case '{': return Token(Type.LBrace, popChar);
            case '}': return Token(Type.RBrace, popChar);
            case '.': return Token(Type.Dot, popChar);
            case ',': return Token(Type.Comma, popChar);
            case ':': return Token(Type.Colon, popChar);

            default:
                return Token(Type.Unknown, popChar);
        }
    }


private:


    dchar front()
    {
        if (_str.length > 0)
            return _str.front;
        else
            return EOF;
    }


    dchar next()
    {
        auto chars = _str.take(2).array;
        if (chars.length < 2)
            return EOF;
        return chars[1];
    }

    dchar pop()
    {
        if (_str.length > 0)
        {
            auto prev  = _str.front;
            _str.popFront();
            return prev;
        } 
        else
            return EOF;
    }


    string popChar()
    {
        return pop.to!string;
    }


    string slice(uint num)
    {
        if (num >= _str.length)
            return _str;
        else
            return _str[0 .. num];
    }


    void skip(uint num)
    {
        if (num >= _str.length)
            _str = "";
        else
            _str = _str[num .. $];
    }


    TokenPos position()
    {
        return TokenPos(_filename, _line, _column);
    }


    void skipWhitespaces()
    {
        while (true)
        {
            if (front.isWhiteSpace)
            {
                pop();
                continue;
            }

            if (isFronNewLine)
            {
                // Return for handling NL as StmtEnd
                if (_isInlineStmt)
                    return;
                tryToSkipNewLine();
                continue;
            }

            return;
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

            if (exprOpBegin == slice(exprOpBegin.length))
                return raw;
            if (stmtOpBegin == slice(stmtOpBegin.length))
                return raw;
            if (cmntOpBegin == slice(cmntOpBegin.length))
                return raw;
            if (stmtOpInline == slice(stmtOpInline.length))
                return raw;
            if (cmntOpInline == slice(cmntOpInline.length))
                return raw;
            
            raw ~= pop();
        }
    }


    void skipComment()
    {
        while(front != EOF)
        {
            if (cmntOpEnd == slice(cmntOpEnd.length))
                return;
            pop();
        }
    }


    void skipInlineComment()
    {
        while(front != EOF)
        {
            if (front == '\n')
            {
                pop();
                return;
            }
            pop();
        }
    }


    bool isFronNewLine()
    {
        auto ch = front;
        return ch == '\r' || ch == '\n' || ch == 0x2028 || ch == 0x2029; 
    }

    /// true if NL was skiped
    bool tryToSkipNewLine()
    {
        switch (front)
        {
            case '\r':
                pop();
                if (front == '\n')
                    pop();
                return true;

            case '\n':
            case 0x2028:
            case 0x2029:
                pop();
                return true;

            default:
                return false;
        }
    }
}


bool isWhiteSpace(dchar ch)
{
    return ch == ' ' || ch == '\t' || ch == 0x205F || ch == 0x202F || ch == 0x3000
           || ch == 0x00A0 || (ch >= 0x2002 && ch <= 0x200B);
}
