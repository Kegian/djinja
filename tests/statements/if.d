module tests.statements.if_;

private
{
    import tests.asserts;
}


// If / Endif
unittest
{
    // Simple if
    assertRender(`{% if true  %} test {% endif %}`, " test ");
    assertRender(`{% if false %} test {% endif %}`, "");

    // Expression as condition
    assertRender(`{% if false or 1 and 1 %} test {% endif %}`, " test ");
    assertRender(`{% if false or 1 and 0 %} test {% endif %}`, "");
}

// If / Else / Endif
unittest
{
    assertRender(`{% if true  %} then {% else %} else {% endif %}`, " then ");
    assertRender(`{% if false %} then {% else %} else {% endif %}`, " else ");
}

// If / Elif / Else / Endif
unittest
{
    assertRender(
            `{% if false %}` ~
                `then` ~
            `{% elif false %}` ~
                `elif 1` ~
            `{% elif true %}` ~
                `elif 2` ~
            `{% elif true %}` ~
                `elif 3` ~
            `{% else %}` ~
                `else` ~
            `{% endif %}`,
            "elif 2"
        );

    assertRender(
            `{% if false %}` ~
                `then` ~
            `{% elif false %}` ~
                `elif 1` ~
            `{% elif false %}` ~
                `elif 2` ~
            `{% elif false %}` ~
                `elif 3` ~
            `{% else %}` ~
                `else` ~
            `{% endif %}`,
            "else"
        );
}
