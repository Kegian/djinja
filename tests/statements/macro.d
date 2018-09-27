module tests.statements.macro_;

private
{
    import tests.asserts;
}


unittest
{
    // Simple macro
    assertRender(`{% macro test %}MACRO{% endmacro %}{{test()}}`, "MACRO");

    // Macro with params
    assertRender(
            `{% macro test(a, b='', c='c', d=10) %}` ~
                `<test a="{{a}}" b="{{b}}" c="{{c}}" d={{d}} />` ~
            `{% endmacro %}` ~
            `{{test('A')}}` ~
            `{{test(10, 'b', 'c', 15) }}`
            , 
            `<test a="A" b="" c="c" d=10 />` ~
            `<test a="10" b="b" c="c" d=15 />`
        );

    // Simple call
    assertRender(
            `{% macro render_dialog(title, class='dialog') %}` ~
                `<div class="{{ class }}">` ~
                    `<h2>{{title}}</h2>` ~
                    `<div class="content">{{caller()}}</div>` ~
                `</div>` ~
            `{% endmacro %}` ~
            `{% call render_dialog("Hello world") %}` ~
                `Simple dialog render` ~
            `{% endcall %}` 
            , 
            `<div class="dialog">` ~
                `<h2>Hello world</h2>` ~
                `<div class="content">Simple dialog render</div>` ~
            `</div>`
        );

    // Call with params
    assertRender(
            `{% macro num_filter(numbers=[]) %}` ~
                `{% for n in numbers if n % 2 and n < 8 %}` ~
                    `{{caller(n, loop.cycle('#', '№'))}}` ~
                `{% endfor %}` ~
            `{% endmacro %}` ~
            `{% call(num, prefix='') num_filter([1,2,3,4,5,6,7,8,9]) %}` ~
                `Number: {{prefix}}{{num}}` ~
            `{% endcall %}` 
            , 
            `Number: #1` ~
            `Number: №3` ~
            `Number: #5` ~
            `Number: №7`
        );
}


unittest
{
    // varargs, kwargs
    assertRender(
            `{% macro test(a, b=0) %}` ~
                `A: {{a}} B: {{b}}`~
                `{{varargs}}` ~
                `{{kwargs | sort}}` ~
            `{% endmacro %}` ~
            `{{ test(1,2,3,4,c=5,d=6,e=7,f=8) }}`
            , 
            `A: 1 B: 2` ~
            `[3, 4]` ~
            `[['c', 5], ['d', 6], ['e', 7], ['f', 8]]`
        );
}


// Extended behavior
unittest
{
    // Return value
    assertRender(
            `{% macro sum(a, b) %}` ~
            `{% endmacro return a + b %}` ~
            `{{ sum(1, 2) }}`
            , 
            `3`
        );

    // Macro as function/filter
    long a = 10;
    assertRender!(a)(
            `{% macro inc(a, b) %}` ~
            `{% endmacro return a + b %}` ~
            `{{ a.inc(10) }}` ~
            `{{ a | inc(15) }}`
            , 
            `20` ~ `25`
        );

    // Macro as test
    assertRender(
            `{% macro good(value) %}` ~
            `{% endmacro return value % 2 == 0 and value > 10 %}` ~
            `{{ 10 is good }}` ~
            `{{ 16 is good }}`
            , 
            `false` ~ `true`
        );
}
