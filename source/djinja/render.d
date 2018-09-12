module djinja.render;

private
{
    import std.range;
    import std.format: fmt = format;

    import djinja.ast.node;
    import djinja.ast.visitor;
    import djinja.algo;
    import djinja.lexer;
    import djinja.parser;
    import djinja.exception : JinjaRenderException,
                              assertJinja = assertJinjaRender;

    import djinja.uninode;
}


alias Function = UniNode function(UniNode);


struct FormArg
{
    string name;
    Nullable!UniNode def;

    this (string name)
    {
        this.name = name;
        this.def = Nullable!UniNode.init;
    }

    this (string name, UniNode def)
    {
        this.name = name;
        this.def = Nullable!UniNode(def);
    }
}


struct Macro
{
    FormArg[] args;
    Nullable!Context context;
    Nullable!Node block;

    this(FormArg[] args, Context context, Node block)
    {
        this.args = args;
        this.context = context.toNullable;
        this.block = block.toNullable;
    }
}


class Context
{
    private Context prev;

    UniNode data;
    Function[string] functions;
    Macro[string] macros;

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

    Context previos() @property
    {
        if (prev !is null)
            return prev;
        return this;
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
            return UniNode(null);
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


    bool hasMacro(string name)
    {
        if (name in macros)
            return true;
        if (prev is null)
            return false;
        return prev.hasMacro(name);
    }

    
    Macro getMacro(string name)
    {
        if (name in macros)
            return macros[name];
        if (prev is null)
            throw new JinjaRenderException("Non declared macro `%s`".fmt(name));
        return prev.getMacro(name);
    }
}


struct AppliedFilter
{
    string name;
    UniNode args;
}


class Render(T) : IVisitor
{
    private
    {
        T _parser;
        Context         _context;
        UniNode[]       _dataStack;
        string          _renderedResult;
        AppliedFilter[] _appliedFilters;
    }

    this(T parser)
    {
        _parser = parser;
        _parser.parseTree();
        _context = new Context();
    }


    string render(UniNode data)
    {
        _context = new Context(data);

        foreach(key, value; globalFunctions)
            _context.functions[key] = cast(Function)value;
        foreach(key, value; globalFilters)
            _context.functions[key] = cast(Function)value;
        foreach(key, value; globalTests)
            _context.functions[key] = cast(Function)value;

        _renderedResult = "";
        if (_parser.root !is null)
            _parser.root.accept(this);
        return _renderedResult;
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
        writeToResult(node.raw);
    }

    override void visit(ExprNode node)
    {
        node.expr.accept(this);
        auto n = pop();
        n.toStringType;
        writeToResult(n.get!string);
    }

    override void visit(InlineIfNode node)
    {
        bool condition = true;

        if (!node.cond.isNull)
        {
            node.cond.accept(this);
            auto res = pop();
            res.toBoolType;
            condition = res.get!bool;
        }

        if (condition)
        {
            node.expr.accept(this);
        }
        else if (!node.other.isNull)
        {
            node.other.accept(this);
        }
        else
        {
            push(UniNode(null));
        }
    }

    override void visit(BinOpNode node)
    {
        UniNode calc(Operator op)()
        {
            node.lhs.accept(this);
            auto lhs = pop();

            node.rhs.accept(this);
            auto rhs = pop();

            return binary!op(lhs, rhs);
        }

        UniNode calcLogic(bool stopCondition)()
        {
            node.lhs.accept(this);
            auto lhs = pop();
            lhs.toBoolType;
            if (lhs.get!bool == stopCondition)
                return UniNode(stopCondition);

            node.rhs.accept(this);
            auto rhs = pop();
            rhs.toBoolType;
            return UniNode(rhs.get!bool);
        }

        UniNode calcCall(string type)()
        {
            node.lhs.accept(this);
            auto lhs = pop();

            node.rhs.accept(this);
            auto args = pop();
            auto name = args["name"].get!string;
            args["varargs"] = UniNode([lhs] ~ args["varargs"].get!(UniNode[]));
            
            if (_context.hasFunc(name))
                return visitFunc(name, args);
            else if (_context.hasMacro(name))
                return visitMacro(name, args);
            else
                throw new JinjaRenderException("Undefined " ~ type ~ " %s".fmt(name));
        }
        
        UniNode calcFilter()
        {
            return calcCall!"filter";
        }

        UniNode calcIs()
        {
            auto res = calcCall!"test";
            res.toBoolType;
            return res;
        }

        UniNode doSwitch()
        {
            switch (node.op) with (Operator)
            {
                case Concat:    return calc!Concat;
                case Plus:      return calc!Plus;
                case Minus:     return calc!Minus;
                case DivInt:    return calc!DivInt;
                case DivFloat:  return calc!DivFloat;
                case Rem:       return calc!Rem;
                case Mul:       return calc!Mul;
                case Greater:   return calc!Greater;
                case Less:      return calc!Less;
                case GreaterEq: return calc!GreaterEq;
                case LessEq:    return calc!LessEq;
                case Eq:        return calc!Eq;
                case NotEq:     return calc!NotEq;
                case Pow:       return calc!Pow;
                case In:        return calc!In;

                case Or:        return calcLogic!true;
                case And:       return calcLogic!false;

                case Filter:    return calcFilter;
                case Is:        return calcIs;

                default:
                    assert(0, "Not implemented binary operator");
            }
        }

        push(doSwitch());
    }

    override void visit(UnaryOpNode node)
    {
        node.expr.accept(this);
        auto res = pop();
        UniNode doSwitch()
        {
            switch (node.op) with (Operator)
            {
                case Plus:      return unary!Plus(res);
                case Minus:     return unary!Minus(res);
                case Not:       return unary!Not(res);
                default:
                    assert(0, "Not implemented unary operator");
            }
        }

        push(doSwitch());
    }

    override void visit(NumNode node)
    {
        if (node.type == NumNode.Type.Integer)
            push(UniNode(node.data._integer));
        else
            push(UniNode(node.data._float));
    }

    override void visit(BooleanNode node)
    {
        push(UniNode(node.boolean));
    }

    override void visit(NilNode node)
    {
        push(UniNode(null));
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
                        throw new JinjaRenderException("Range violation  on %s...[%d]".fmt(node.name, key.get!long));
                    break;

                // Key of dict
                case text:
                    auto keyStr = key.get!string;
                    if (curr.kind == UniNode.Kind.object && keyStr in curr)
                        curr = curr[keyStr];
                    else if (_context.hasFunc(keyStr))
                    {
                        auto args = [
                            "name": UniNode(keyStr),
                            "varargs": UniNode([curr]),
                            "kwargs": UniNode.emptyObject
                        ];
                        curr = visitFunc(keyStr, UniNode(args));
                    }
                    else if (_context.hasMacro(keyStr))
                    {
                        auto args = [
                            "name": UniNode(keyStr),
                            "varargs": UniNode([curr]),
                            "kwargs": UniNode.emptyObject
                        ];
                        curr = visitMacro(keyStr, UniNode(args));
                    }
                    else
                        throw new JinjaRenderException("Unknown attribute %s".fmt(key.get!string));
                    break;

                // Call of function
                case object:
                    auto name = key["name"].get!string;

                    //TODO check name/varargs/kwargs
                    if (!curr.isNull)
                        key["varargs"] = UniNode([curr] ~ key["varargs"].get!(UniNode[]));

                    if (_context.hasFunc(name))
                    {
                        curr = visitFunc(name, key);
                    }
                    else if (_context.hasMacro(name))
                    {
                        curr = visitMacro(name, key);
                    }
                    else
                        throw new JinjaRenderException("Not found any macro, function or filter `%s`".fmt(name));
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
                        throw new JinjaRenderException("Range violation  on %s...[%d]".fmt(node.name, key.get!long));
                    break;

                // Key of dict
                case text:
                    if (key.get!string in *curr)
                        curr = &((*curr)[key.get!string]);
                    else
                        throw new JinjaRenderException("Unknown attribute %s".fmt(key.get!string));
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
                        throw new JinjaRenderException("Range violation  on %s...[%d]".fmt(node.name, key.get!long));
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


    override void visit(MacroNode node)
    {
        FormArg[] args;

        foreach(arg; node.args)
        {
            if (arg.defaultExpr.isNull)
                args ~= FormArg(arg.name);
            else
            {
                arg.defaultExpr.accept(this);
                args ~= FormArg(arg.name, pop());
            }
        }

        _context.macros[node.name] = Macro(args, _context, node.block);
    }


    override void visit(CallNode node)
    {
        FormArg[] args;

        foreach(arg; node.formArgs)
        {
            if (arg.defaultExpr.isNull)
                args ~= FormArg(arg.name);
            else
            {
                arg.defaultExpr.accept(this);
                args ~= FormArg(arg.name, pop());
            }
        }

        auto caller = Macro(args, _context, node.block);

        node.factArgs.accept(this);
        auto factArgs = pop();

        visitMacro(node.macroName, factArgs, caller.nullable);
    }


    override void visit(FilterBlockNode node)
    {
        node.args.accept(this);
        auto args = pop();

        pushFilter(node.filterName, args);
        node.block.accept(this);
        popFilter();
    }


private:

    UniNode visitFunc(string name, UniNode args)
    {
        return _context.getFunc(name)(args);
    }


    UniNode visitMacro(string name, UniNode args, Nullable!Macro caller = Nullable!Macro.init)
    {
        UniNode result;

        auto macro_ = _context.getMacro(name);
        auto stashedContext = _context;
        _context = macro_.context.get;
        pushNewContext();

        UniNode[] varargs;
        UniNode[string] kwargs;

        foreach(arg; macro_.args)
            if (!arg.def.isNull)
                _context.data[arg.name] = arg.def;

        for(int i = 0; i < args["varargs"].length; i++)
        {
            if (i < macro_.args.length)
                _context.data[macro_.args[i].name] = args["varargs"][i];
            else
                varargs ~= args["varargs"][i];
        }

        //TODO to foreach after uninode fix
        args["kwargs"].opApply(delegate(ref string key, ref UniNode value) @safe
                {
                    if (macro_.args.has(key))
                        _context.data[key] = value;
                    else
                        kwargs[key] = value;
                    return cast(int)0;
                });

        _context.data["varargs"] = UniNode(varargs);
        _context.data["kwargs"] = UniNode(kwargs);

        foreach(arg; macro_.args)
            if (arg.name !in _context.data)
                throw new JinjaRenderException("Missing value for argument `%s`".fmt(arg.name));

        if (!caller.isNull)
            _context.macros["caller"] = caller;

        macro_.block.accept(this);
        result = pop();

        popContext();
        _context = stashedContext;

        return result;
    }


    void writeToResult(string str)
    {
        if (!_appliedFilters.length)
        {
            _renderedResult ~= str;
        }
        else
        {
            UniNode curr = UniNode(str); 


            foreach_reverse (filter; _appliedFilters)
            {
                auto args = filter.args;
                args["varargs"] = UniNode([curr] ~ args["varargs"].get!(UniNode[]));

                if (_context.hasFunc(filter.name))
                    curr = visitFunc(filter.name, args);
                else if (_context.hasMacro(filter.name))
                    curr = visitMacro(filter.name, args);
                else
                    assert(0);

                curr.toStringType;
            }

            _renderedResult ~= curr.get!string;
        }
    }


private:


    void pushNewContext()
    {
        _context = new Context(_context);
    }


    void popContext()
    {
        _context = _context.previos;
    }

    
    void push(UniNode un)
    {
        _dataStack ~= un;
    }


    UniNode pop()
    {
        if (!_dataStack.length)
            throw new JinjaRenderException("Unexpected empty stack");

        auto un = _dataStack.back;
        _dataStack.popBack;
        return un;
    }

    void pushFilter(string name, UniNode args)
    {
        _appliedFilters ~= AppliedFilter(name, args);
    }

    void popFilter()
    {
        _appliedFilters.popBack;
    }
}


private:


bool has(FormArg[] arr, string name) @safe
{
    foreach(a; arr)
        if (a.name == name)
            return true;
    return false;
}
