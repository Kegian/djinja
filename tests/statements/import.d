module tests.statements.import_;

private
{
    import tests.asserts;
}


// Base import
unittest
{
    // Import all macros
    assertRender(
            `{% import './tests/files/test.dj' %}` ~
            `{{ test() }}` ~
            `{{ test1() }}` ~
            `{{ test2() }}`
            ,
            "TEST" ~
            "TEST1" ~
            "TEST2"
        );

    // Import specific macro
    assertRender(
            `{% from './tests/files/test.dj' import test %}` ~
            `{{ test() }}`
            ,
            "TEST"
        );

    // Import with renaming
    assertRender(
            `{% from './tests/files/test.dj' import test as renamed %}` ~
            `{{ renamed() }}`
            ,
            "TEST"
        );

    // Mixed imports
    assertRender(
            `{% from './tests/files/test.dj' import test1 as r1, test2 as r2, test %}` ~
            `{{ test() }}` ~
            `{{ r1() }}` ~
            `{{ r2() }}`
            ,
            "TEST" ~
            "TEST1" ~
            "TEST2"
        );
}

// Exception cases
unittest
{
    // Non-existing file
    assertException(
            `{% import './tests/files/notexisting.dj' %}`
        );

    // Undefined `test3`
    assertException(
            `{% from './tests/files/test.dj' import test3 %}`
        );

    // Undefined test
    assertException(
            `{% from './tests/files/test.dj' import test as renamed %}` ~
            `{{ test() }}`
        );
}

// Context behavior
unittest
{
    // Import without context by default
    assertRender(
            `{% set a = 10 %}` ~
            `{% from './tests/files/context.dj' import print_a %}` ~
            `{{ print_a() }}`
            ,
            ""
        );

    // Import without context manually
    assertRender(
            `{% set a = 10 %}` ~
            `{% from './tests/files/context.dj' import print_a without context %}` ~
            `{{ print_a() }}`
            ,
            ""
        );

    // Import with context manually
    assertRender(
            `{% set a = 10 %}` ~
            `{% from './tests/files/context.dj' import print_a with context %}` ~
            `{{ print_a() }}`
            ,
            "10"
        );
}
