module djinja.algo.wrapper;

private
{
    import std.algorithm : min;
    import std.format : fmt = format;
    import std.traits;
    import std.typecons : Tuple;
    import std.string : join;

    import djinja.exception : assertJinja = assertJinjaException;
    import djinja.uninode;
}


template wrapper(alias F)
    if (isSomeFunction!F)
{
    alias ParameterIdents = ParameterIdentifierTuple!F;
    alias ParameterTypes = Parameters!F;
    alias ParameterDefs = ParameterDefaults!F;
    alias RT = ReturnType!F;
    alias PT = Tuple!ParameterTypes;


    UniNode wrapper(UniNode params)
    {
        assertJinja(params.kind == UniNode.Kind.object, "Non object params");
        assertJinja(cast(bool)("varargs" in params), "Missing varargs in params");
        assertJinja(cast(bool)("kwargs" in params), "Missing kwargs in params");

        bool[string] filled;
        PT args;

        foreach(i, def; ParameterDefs)
        {
            string key = ParameterIdents[i];
            static if (is(def == void))
                filled[key] = false;
            else
                args[i] = def;
        }

        void fillArg(size_t idx, PType)(string key, UniNode val)
        {
            // TODO toBoolType, toStringType
            try
                args[idx] = val.deserialize!PType;
            catch
                assertJinja(0, "Can't deserialize param `%s` from `%s` to `%s` in function `%s`"
                                        .fmt(key, val.kind, PType.stringof, fullyQualifiedName!F));
        }

        static foreach (int i; 0 .. PT.length)
        {
            if (params["varargs"].length > i)
            {
                fillArg!(i, ParameterTypes[i])(ParameterIdents[i], params["varargs"][i]);
                filled[ParameterIdents[i]] = true;
            }
        }

        static foreach(i, key; ParameterIdents)
        {
            if (key in params["kwargs"])
            {
                fillArg!(i, ParameterTypes[i])(key, params["kwargs"][key]);
                filled[ParameterIdents[i]] = true;
            }
        }

        string[] missedArgs = [];
        foreach(key, val; filled)
            if (!val)
                missedArgs ~= key;

        if (missedArgs.length)
            assertJinja(0, "Missed values for args %s".fmt(missedArgs.join(", ")));

        static if (is (RT == void))
        {
            F(args.expand);
            return UniNode(null);
        }
        else
        {
            auto ret = F(args.expand);
            return ret.serialize!RT;
        }
    }
}
