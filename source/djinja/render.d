module djinja.render;

private
{
    import std.range;
    import std.format: fmt = format;
    import std.algorithm : among;
    import std.conv : to;

    import djinja.ast.node;
    import djinja.ast.visitor;
    import djinja.algo;
    import djinja.lexer;
    import djinja.parser;
    import djinja.exception;

    import uninode;
    import uninode.serialization;
}


class Context
{
    Context prev;
    UniNode data;

    Function[string] functions;

    this ()
    {
        prev = null;
        data = UniNode.emptyObject();
    }

    this (Context ctx)
    {
        prev = ctx;
        data = UniNode.emptyObject();
    }

    this (UniNode data)
    {
        prev = null;
        this.data = data;
    }

    bool has(string name)
    {
        if (name in data)
            return true;
        if (prev is null)
            return false;
        return prev.has(name);
    }
    
    UniNode get(string name)
    {
        if (name in data)
            return data[name];
        if (prev is null)
            throw new JinjaRenderException("Non declared var `%s`".fmt(name));
        return prev.get(name);
    }

    UniNode* getPtr(string name)
    {
        if (name in data)
            return &(data[name]);
        if (prev is null)
            throw new JinjaRenderException("Non declared var `%s`".fmt(name));
        return prev.getPtr(name);
    }
    
    T get(T)(string name)
    {
        return this.get(name).get!T;
    }
    

    bool hasFunc(string name)
    {
        if (name in functions)
            return true;
        if (prev is null)
            return false;
        return prev.hasFunc(name);
    }

    
    Function getFunc(string name)
    {
        if (name in functions)
            return functions[name];
        if (prev is null)
            throw new JinjaRenderException("Non declared function `%s`".fmt(name));
        return prev.getFunc(name);
    }
}



class Render(T) : IVisitor
{
    private
    {
        T _parser;
        Context _context;
        UniNode[] _stack;
        string _result;
    }

    this(T parser)
    {
        _parser = parser;
        _parser.parseTree();

        _context = new Context();
        _context.functions = cast(Function[string])functionList;
    }


    string render(UniNode data)
    {
        _context = new Context(data);
        _context.functions = cast(Function[string])functionList;

        _result = "";
        if (_parser.root !is null)
            _parser.root.accept(this);
        return _result;
    }

    uint _tab = 0;

    override void visit(StmtBlockNode node)
    {
        pushNewContext();
        foreach(ch; node.children)
            ch.accept(this);
        popContext();
    }

    override void visit(RawNode node)
    {
        _result ~= node.raw;
    }

    override void visit(ExprNode node)
    {
        node.expr.accept(this);
        auto n = pop();
        n.toStringType;
        _result ~= n.get!string;
    }

    override void visit(BinOpNode node)
    {
        node.lhs.accept(this);
        node.rhs.accept(this);

        auto rhs = pop();
        auto lhs = pop();
        UniNode res;

        UniNode doSwitch()
        {
            switch (node.op) with (Operator)
            {
                case Concat:    return binary!Concat(lhs, rhs);
                case Plus:      return binary!Plus(lhs, rhs);
                case Minus:     return binary!Minus(lhs,rhs);
                case DivInt:    return binary!DivInt(lhs,rhs);
                case DivFloat:  return binary!DivFloat(lhs,rhs);
                case Mul:       return binary!Mul(lhs,rhs);
                case Greater:   return binary!Greater(lhs,rhs);
                case Less:      return binary!Less(lhs,rhs);
                case GreaterEq: return binary!GreaterEq(lhs,rhs);
                case LessEq:    return binary!LessEq(lhs,rhs);
                case Eq:        return binary!Eq(lhs,rhs);
                case NotEq:     return binary!NotEq(lhs,rhs);
                case Or:        return binary!Or(lhs,rhs);
                case And:       return binary!And(lhs,rhs);
                default:
                    assert(0, "Not implemented yet");
            }
        }

        push(doSwitch());
    }

    override void visit(UnaryOpNode node)
    {
        // print("UnaryOp: %s".fmt(node.op));
        _tab++;
        node.expr.accept(this);
        _tab--;
    }

    override void visit(NumNode node)
    {
        if (node.type == NumNode.Type.Integer)
            push(UniNode(node.data._integer));
        else
            push(UniNode(node.data._float));
    }

    override void visit(IdentNode node)
    {
        UniNode curr;
        if (node.name.length)
            curr = _context.get(node.name);
        else
            curr = UniNode(null);

        foreach (sub; node.subIdents)
        {
            sub.accept(this);
            auto key = pop();

            switch (key.kind) with (UniNode.Kind)
            {
                // Index of list/tuple
                case integer:
                case uinteger:
                    curr.checkNodeType(array);
                    if (key.get!long < curr.length)
                        curr = curr[key.get!long];
                    else
                        throw new JinjaParserException("Range violation  on %s...[%d]".fmt(node.name, key.get!long));
                    break;

                // Key of dict
                case text:
                    auto keyStr = key.get!string;
                    if (curr.kind == UniNode.Kind.object && keyStr in curr)
                        curr = curr[keyStr];
                    else if (_context.hasFunc(keyStr))
                    {
                        auto func = _context.getFunc(keyStr);
                        auto args = [
                            "name": UniNode(keyStr),
                            "varargs": UniNode([curr]),
                            "kwargs": UniNode.emptyObject
                        ];
                        curr = func(UniNode(args));
                    }
                    else
                        throw new JinjaParserException("Unknown attribute %s".fmt(key.get!string));
                    break;

                // Call of function
                // TODO
                case object:
                    //TODO check name/varargs/kwargs
                    if (!curr.isNull)
                        key["varargs"] = UniNode([curr] ~ key["varargs"].get!(UniNode[]));
                    auto func = _context.getFunc(key["name"].get!string);
                    curr = func(key);
                    break;

                case nil:
                    break;
                default:
                    throw new JinjaRenderException("Unknown attribute %s for %s".fmt(key.toString, node.name));
            }

        }

        push(curr);
    }

    override void visit(AssignableNode node)
    {
        auto expr = pop();

        if (!_context.has(node.name))
        {
            if (node.subIdents.length)
                throw new JinjaRenderException("Unknow variable %s".fmt(node.name));
            _context.data[node.name] = expr;
            return;
        }

        UniNode* curr = _context.getPtr(node.name);

        if (!node.subIdents.length)
        {
            (*curr) = expr;
            return;
        }

        for(int i = 0; i < cast(long)(node.subIdents.length) - 1; i++)
        {
            node.subIdents[i].accept(this);
            auto key = pop();

            switch (key.kind) with (UniNode.Kind)
            {
                // Index of list/tuple
                case integer:
                case uinteger:
                    checkNodeType(*curr, array);
                    if (key.get!long < curr.length)
                        curr = &((*curr)[key.get!long]);
                    else
                        throw new JinjaParserException("Range violation  on %s...[%d]".fmt(node.name, key.get!long));
                    break;

                // Key of dict
                case text:
                    if (key.get!string in *curr)
                        curr = &((*curr)[key.get!string]);
                    else
                        throw new JinjaParserException("Unknown attribute %s".fmt(key.get!string));
                    break;

                default:
                    throw new JinjaRenderException("Unknown attribute %s for %s".fmt(key.toString, node.name));
            }
        }

        if (node.subIdents.length)
        {
            node.subIdents[$-1].accept(this);
            auto key = pop();

            switch (key.kind) with (UniNode.Kind)
            {
                // Index of list/tuple
                case integer:
                case uinteger:
                    checkNodeType(*curr, array);
                    if (key.get!long < curr.length)
                        (*curr).opIndex(key.get!long) = expr; // ¯\_(ツ)_/¯
                    else
                        throw new JinjaParserException("Range violation  on %s...[%d]".fmt(node.name, key.get!long));
                    break;

                // Key of dict
                case text:
                    (*curr)[key.get!string] = expr;
                    break;

                default:
                    throw new JinjaRenderException("Unknown attribute %s for %s".fmt(key.toString, node.name));
            }
        }
    }

    override void visit(StringNode node)
    {
        push(UniNode(node.str));
    }

    override void visit(ListNode node)
    {
        UniNode[] list = [];
        foreach (l; node.list)
        {
            l.accept(this);
            list ~= pop();
        }
        push(UniNode(list));
    }

    override void visit(DictNode node)
    {
        UniNode[string] dict;
        foreach (key, value; node.dict)
        {
            value.accept(this);
            dict[key] = pop();
        }
        push(UniNode(dict));
    }

    override void visit(IfNode node)
    {
        node.cond.accept(this);

        auto cond = pop();
        cond.toBoolType;

        if (cond.get!bool)
        {
            node.then.accept(this);
        }
        else if (node.other)
        {
            node.other.accept(this);
        }
    }

    override void visit(ForNode node)
    {
        node.iterable.accept(this);

        UniNode iterable = pop();

        pushNewContext();

        bool iterated = false;

        if (node.key.length)
        {
            iterable.checkNodeType(UniNode.Kind.object);
            foreach(idx, ref obj; iterable)
            {
                () @trusted {
                    _context.data[node.key] = UniNode(idx);
                    _context.data[node.value] = obj;
                    // TODO UPDATE LOOP VARS
                    node.block.accept(this);
                    iterated = true;
                } ();
            }
        }
        else
        {
            iterable.checkNodeType(UniNode.Kind.array);
            foreach(ref it; iterable)
            {
                () @trusted {
                    _context.data[node.value] = it;
                    // TODO UPDATE LOOP VARS
                    node.block.accept(this);
                    iterated = true;
                } ();
            }
        }

        popContext();

        if (!iterated && node.other !is null)
            node.other.accept(this);
    }


    override void visit(SetNode node)
    {
        node.expr.accept(this);

        if (node.assigns.length == 1)
            node.assigns[0].accept(this);            
        else
        {
            auto expr = pop();
            expr.checkNodeType(UniNode.Kind.array);
            
            if (expr.length < node.assigns.length)
                throw new JinjaRenderException("Iterable length less then number of assigns");

            foreach(idx, assign; node.assigns)
            {
                push(expr[idx]);
                assign.accept(this);
            }
        }
    }


private:


    void pushNewContext()
    {
        _context = new Context(_context);
    }


    void popContext()
    {
        if (_context !is null)
            _context = _context.prev;
    }

    
    void push(UniNode un)
    {
        _stack ~= un;
    }


    UniNode pop()
    {
        if (!_stack.length)
            throw new JinjaRenderException("Unexpected empty stack");

        auto un = _stack.back;
        _stack.popBack;
        return un;
    }
}


private:


bool isNumericNode(ref UniNode n)
{
    return cast(bool)n.kind.among(UniNode.Kind.integer, UniNode.Kind.floating);
}


void toCommonNumType(ref UniNode n1, ref UniNode n2)
{
    if (!n1.isNumericNode)
        throw new JinjaRenderException("Not a numeric type of %s".fmt(n1));
    if (!n2.isNumericNode)
        throw new JinjaRenderException("Not a numeric type of %s".fmt(n2));

    if (n1.kind == UniNode.Kind.integer && n2.kind == UniNode.Kind.floating)
    {
        n1 = UniNode(n1.get!long.to!double);
        return;
    }

    if (n1.kind == UniNode.Kind.floating && n2.kind == UniNode.Kind.integer)
    {
        n2 = UniNode(n2.get!long.to!double);
        return;
    }
}


void toCommonCmpType(ref UniNode n1, ref UniNode n2)
{
    //TODO string, list, tuple, dict
   if (n1.isNumericNode && n2.isNumericNode)
   {
       toCommonNumType(n1, n2);
       return;
   }
   if (n1.kind != n2.kind)
       throw new JinjaRenderException("Not comparable types %s and %s".fmt(n1.kind, n2.kind));
}


void toBoolType(ref UniNode n)
{
    switch (n.kind) with (UniNode.Kind)
    {
        case boolean:
            return;
        case integer:
            n = UniNode(n.get!long > 0);
            return;
        case floating:
            n = UniNode(n.get!double > 0);
            return;
        case text:
            n = UniNode(n.get!string.length > 0);
            return;
        default:
            throw new JinjaRenderException("Can't cast type %s to bool".fmt(n.kind));
    }
}


void toStringType(ref UniNode n)
{
    import std.algorithm : map;
    import std.string : join;
    string doSwitch()
    {
        switch (n.kind) with (UniNode.Kind)
        {
            case nil: return "nil";
            case boolean: return n.get!bool.to!string;
            case integer: return n.get!long.to!string;
            case floating: return n.get!double.to!string;
            case text: return n.get!string;
            case raw: return n.get!(ubyte[]).to!string;
            case array: return "["~n.get!(UniNode[]).map!(a => a.getString).join(",").to!string~"]"; 
            case object: return n.toString;
            default: return "[UnknownObj: %s]".fmt(n.toString);
        }
    }
    n = UniNode(doSwitch());
}


string getString(UniNode n)
{
    n.toStringType;
    return n.get!string;
}


void checkNodeType(ref UniNode n, UniNode.Kind kind)
{
    if (n.kind != kind)
        throw new JinjaRenderException("Unexpected expression type %s, expcted %s".fmt(n.kind, kind));
}


UniNode binary(string op)(UniNode lhs, UniNode rhs)
{
    static if (op.among(Operator.Plus,
                        Operator.Minus,
                        Operator.Mul,
                        Operator.DivFloat)
              )
    {
        toCommonNumType(lhs, rhs);
        if (lhs.kind == UniNode.Kind.integer)
            return UniNode(mixin("lhs.get!long" ~ op ~ "rhs.get!long"));
        else
            return UniNode(mixin("lhs.get!double" ~ op ~ "rhs.get!double"));
    }
    else static if (op == Operator.DivInt)
    {
        lhs.checkNodeType(UniNode.Kind.integer);
        rhs.checkNodeType(UniNode.Kind.integer);
        return UniNode(lhs.get!long / rhs.get!long);
    }
    else static if (op.among(Operator.Eq,
                             Operator.NotEq))
    {
        toCommonCmpType(lhs, rhs);
        return UniNode(mixin("lhs" ~ op ~ "rhs"));
    }
    else static if (op.among(Operator.Less,
                             Operator.LessEq,
                             Operator.Greater,
                             Operator.GreaterEq)
                   )
    {
        toCommonCmpType(lhs, rhs);
        switch (lhs.kind) with (UniNode.Kind)
        {
            case integer: return UniNode(mixin("lhs.get!long" ~ op ~ "rhs.get!long"));
            case floating: return UniNode(mixin("lhs.get!double" ~ op ~ "rhs.get!double"));
            case text: return UniNode(mixin("lhs.get!string" ~ op ~ "rhs.get!string"));
            default:
                throw new JinjaRenderException("Not comparable type %s".fmt(lhs.kind));
        }
    }
    else static if (op == Operator.Or)
    {
        lhs.toBoolType;
        rhs.toBoolType;
        return UniNode(lhs.get!bool || rhs.get!bool);
    }
    else static if (op == Operator.And)
    {
        lhs.toBoolType;
        rhs.toBoolType;
        return UniNode(lhs.get!bool && rhs.get!bool);
    }
    else static if (op == Operator.Concat)
    {
        lhs.toStringType;
        rhs.toStringType;
        return UniNode(lhs.get!string ~ rhs.get!string);
    }
    else static assert(0);
}
