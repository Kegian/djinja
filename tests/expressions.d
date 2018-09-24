module tests.expressions;

private
{
    import std.conv : to;

    import tests.asserts;
}

// Literals
unittest
{
    // True/False
    assertRender("{{ true }}", "true");
    assertRender("{{ True }}", "true");
    assertRender("{{ false }}", "false");
    assertRender("{{ False }}", "false");

    // Numbers
    assertRender("{{ 10 }}", "10");
    assertRender("{{ 10.5 }}", (10.5).to!string);
    assertRender("{{ -10 }}", "-10");
    assertRender("{{ -10.5 }}", (-10.5).to!string);

    // String
    assertRender("{{ 'some string' }}", "some string");
    assertRender(`{{ "some string" }}`, "some string");

    // List
    assertRender("{{ [] }}", "[]");
    assertRender("{{ [1,2,3] }}", "[1, 2, 3]");

    // Tuple (also list actually)
    assertRender("{{ (1,2,3) }}", "[1, 2, 3]");
    assertRender("{{ (1,)}}", "[1]");

    // Dict
    assertRender("{{ {} }}", "{}");
    assertRender(`{{ {a:True, 'b':10, "c":"string"} }}`, "{a: true, b: 10, c: 'string'}");

    // Idents
    struct Dummy
    {
        string str;
        int[]  arr;
        ubyte  idx;
    }
    auto val = Dummy("some string", [1,2,3], 2);

    assertRender!(val)("{{ val }}", "{arr: [1, 2, 3], idx: 2, str: 'some string'}");
    assertRender!(val)("{{ val.length }}", "3");

    assertRender!(val)("{{ val.str }}", "some string");
    assertRender!(val)("{{ val['str'] }}", "some string");
    assertRender!(val)(`{{ val["str"] }}`, "some string");
    assertRender!(val)(`{{ val.str.length }}`, "11");

    assertRender!(val)("{{ val.arr }}", "[1, 2, 3]");
    assertRender!(val)("{{ val.arr[0] }}", "1");
    assertRender!(val)("{{ val.arr[val.idx - 1] }}", "2");
    assertRender!(val)("{{ val.arr.length }}", "3");
}

// Simple math expressions
unittest
{
    assertRender("{{ 1 }}", "1");
    assertRender("{{ 1 + 1 }}", "2");
    assertRender("{{ 1 - 2 }}", "-1");
    assertRender("{{ -2 * 3 }}", "-6");
    assertRender("{{ 10 // 3 }}", "3");
    assertRender("{{ 10 % 3 }}", "1");
    assertRender("{{ 10.0 / 3.0 }}", (10.0/3.0).to!string);
}


// Priority
unittest
{
    assertRender("{{ 2+2*2**2 }}", "10");
    assertRender("{{ ((2+2)*2)**2 }}", "64");
    assertRender("{{ 2-2/2 }}", "1");
}

// Associativity
unittest
{
    assertRender("{{ 1-2-3-4 }}", "-8");
    assertRender("{{ 2**2**3 }}", "256");
    assertRender("{{ 10/5/2 }}", "1");
}

//Logical expressions
unittest
{
    assertRender("{{10 ==  9}}", "false");
    assertRender("{{10 == 10}}", "true");
    assertRender("{{10 == 11}}", "false");

    assertRender("{{10 !=  9}}", "true");
    assertRender("{{10 != 10}}", "false");
    assertRender("{{10 != 11}}", "true");

    assertRender("{{10 >  9}}", "true");
    assertRender("{{10 > 10}}", "false");
    assertRender("{{10 > 11}}", "false");

    assertRender("{{10 >=  9}}", "true");
    assertRender("{{10 >= 10}}", "true");
    assertRender("{{10 >= 11}}", "false");

    assertRender("{{10 <  9}}", "false");
    assertRender("{{10 < 10}}", "false");
    assertRender("{{10 < 11}}", "true");

    assertRender("{{10 <=  9}}", "false");
    assertRender("{{10 <= 10}}", "true");
    assertRender("{{10 <= 11}}", "true");
}

unittest
{
    assertRender("{{ not true }}", "false");
    assertRender("{{ not false }}", "true");

    assertRender("{{ false or false }}", "false");
    assertRender("{{ false or true  }}", "true");
    assertRender("{{ true  or false }}", "true");
    assertRender("{{ true  or true  }}", "true");

    assertRender("{{ false and false }}", "false");
    assertRender("{{ false and true  }}", "false");
    assertRender("{{ true  and false }}", "false");
    assertRender("{{ true  and true  }}", "true");

    assertRender("{{  true or false  and false }}", "true");
    assertRender("{{ (true or false) and false }}", "false");

    // Stop computation prevents error:
    assertRender("{{ false or false or true or 1 // 0}}", "true");
    assertRender("{{ true and true and false and 1 // 0}}", "false");
}

unittest
{
    assertRender("{{ 1 in [1, 2, 3] }}", "true");
    assertRender("{{ 4 in [1, 2, 3] }}", "false");
    assertRender("{{ 1 not in [1, 2, 3] }}", "false");
    assertRender("{{ 4 not in [1, 2, 3] }}", "true");

    assertRender("{{ 'key' in {key: 'val'} }}", "true");
    assertRender("{{ 'val' in {key: 'val'} }}", "false");
    assertRender("{{ 'key' not in {key: 'val'} }}", "false");
    assertRender("{{ 'val' not in {key: 'val'} }}", "true");

    assertRender("{{ 'tri' in 'string' }}", "true");
    assertRender("{{ 'tra' in 'string' }}", "false");
    assertRender("{{ 'tri' not in 'string' }}", "false");
    assertRender("{{ 'tra' not in 'string' }}", "true");

    assertRender("{{ 1.0 is number}}", "true");
    assertRender("{{ 'a' is number}}", "false");
    assertRender("{{ 1.0 not is number}}", "false");
    assertRender("{{ 'a' not is number}}", "true");

    assertRender("{{ 'string'|upper }}", "STRING");
    assertRender("{{ undefinedVar | d('undefined') | upper }}", "UNDEFINED");

    assertRender("{{ 1 ~ (1>2) ~ 'str' ~ [1] }}", "1falsestr[1]");
    assertRender("{{ 1 ~  1>2  ~ 'str' ~ [1] }}", "false");

    assertRender("{{ length([1, 2, 3])}}", "3");
}

unittest
{
    assertRender("{{ 1 if true  else 2}}", "1");
    assertRender("{{ 1 if false else 2}}", "2");

    assertRender("{{ '!' ~ (undefVar if undefVar is defined else 'a') ~ '!' }}", "!a!");
}

unittest
{
    int myStrLen(string str)
    {
        return cast(int)str.length;
    }

    string str = "abcde";

    assertRender!(myStrLen, str)("{{ myStrLen( '!' ~ str ~ '!') }}", "7");
}


// Implicity cast to string
unittest
{
    assertRender("{{ '' ~ 123 }}", "123");
    assertRender("{{ '' ~ 1.5 }}", "1.5");
    assertRender("{{ '' ~ true }}", "true");
    assertRender("{{ '' ~ [1,2,3] }}", "[1, 2, 3]");
    assertRender("{{ '' ~ (1,) }}", "[1]");
    assertRender("{{ '' ~ {a:1,b:2} }}", "{a: 1, b: 2}");
}

// Implicity cast to bool
unittest
{
    assertRender("{{ false or -1 }}", "true");
    assertRender("{{ false or  1 }}", "true");
    assertRender("{{ false or  0 }}", "false");

    assertRender("{{ false or -1.5 }}", "true");
    assertRender("{{ false or  1.5 }}", "true");
    assertRender("{{ false or  0.0 }}", "false");

    assertRender("{{ false or  'str' }}", "true");
    assertRender("{{ false or  '   ' }}", "true");
    assertRender("{{ false or  ''    }}", "false");

    assertRender("{{ false or [1,2] }}", "true");
    assertRender("{{ false or (1,)  }}", "true");
    assertRender("{{ false or []    }}", "false");

    assertRender("{{ false or {a:1} }}", "true");
    assertRender("{{ false or {}    }}", "false");

    assertRender("{{ false or undefVar }}", "false");
}

// Implicity cast integer to float
unittest
{
    assertRender("{{ 1.5 + 15 }}", (16.5).to!string);
}
