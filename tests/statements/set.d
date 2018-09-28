module tests.statements.set_;

private
{
    import tests.asserts;
}


long[] testFunc()
{
    return [1, 2]; 
}


unittest
{
    // Simple set
    assertRender(`{% set a = 10 %}{{a}}`, "10");
    assertRender(`{% set a, b = 10, 'str' %}{{a ~ b}}`, "10str");

    // Set from iterable
    assertRender(`{% set a, b, c = [1, 's', [2,3]] %}{{a ~ b ~ c}}`, "1s[2, 3]");
    assertRender(`{% set a, b, c = (1, 's', [2,3]) %}{{a ~ b ~ c}}`, "1s[2, 3]");
    assertRender!(testFunc)(`{% set a, b = testFunc() %}{{a ~ b}}`, "12");
}

// Intended scope behavior
unittest
{
    assertRender(
            `{% with %}` ~
                `{% set a = 10 %}` ~
                `{{ a is defined }}` ~
            `{% endwith %}` ~
            `{{ a is defined }}`
            ,
            "true" ~ "false");
}

// Extended scope bahavior
unittest
{
    assertRender(
            `{% set a = 10 %}` ~
            `{% with %}` ~
                `{% set a = 15 %}` ~
            `{% endwith %}` ~
            `{{ a }}`
            ,
            "15");
}

// Namespace for compitability
unittest
{
    assertRender(
            `{% set ns = namespace(a=10) %}` ~
            `{% with %}` ~
                `{% set ns.a = 15 %}` ~
            `{% endwith %}` ~
            `{{ ns.a }}`
            ,
            "15");
}
