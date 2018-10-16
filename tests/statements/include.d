module tests.statements.include_;

private
{
    import tests.asserts;
}


// Basic includes
unittest
{
    // Include raw data file
    assertRender(
            `{% include "./tests/files/raw.txt" %}`
            ,
            "RAWDATA"
        );

    // Ignore missing file
    assertRender(
            `{% include "notexisting.txt" ignore missing %}`
            ,
            ""
        );

    // Include first exists file
    assertRender(
            `{% include ["notexisting.txt", "./tests/files/raw.txt"] %}`
            ,
            "RAWDATA"
        );

    // Include first exists file or ignore if all missing
    assertRender(
            `{% include ["notexisting1.txt", "notexisting2.txt"] ignore missing %}`
            ,
            ""
        );
}


// Exception cases
unittest
{
    // Include non-existing files
    assertException(`{% include "notexisting.txt" %}`);
    assertException(`{% include ["notexisting1.txt", "notexisting2.txt"] %}`);
}


// Context bahavior
unittest
{
    // Include with context by default
    assertRender(
            `{% set a = 10 %}` ~
            `{% include "./tests/files/context.dj" %}`
            ,
            "10"
        );

    // Include with context manually
    assertRender(
            `{% set a = 10 %}` ~
            `{% include "./tests/files/context.dj" with context %}`
            ,
            "10"
        );

    // Include without context manually
    assertRender(
            `{% set a = 10 %}` ~
            `{% include "./tests/files/context.dj" without context %}`
            ,
            ""
        );
}
