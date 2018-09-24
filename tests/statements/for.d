module tests.statements.for_;

private
{
    import tests.asserts;
}


private struct Dummy
{
    int num;
    string str;
    long[] list;
}

private immutable long[] list = [1, 2, 3, 4, 5];
private auto dict = immutable(Dummy)(1, "str", list);


unittest
{
    // Iterate through inline list
    assertRender(`{% for val in [1,2,3] %}{{val}}{% endfor %}`, "123");

    // Iterate through inline tuple
    assertRender(`{% for val in (1,2,3) %}{{val}}{% endfor %}`, "123");

    // Iterate through inline dict
    assertRender(
            `{% for key, val in {a:1, b:2} %}` ~
            `{{1}}` ~ // Can't check key-val because of an implicit iterating dict order
            `{% endfor %}`,
            "11"
        );
}

unittest
{
    // Filtering iterated obj
    assertRender(
            `{% for i in [1,2,3,4,5] if i % 2 == 1 %}` ~
                `{{i}}` ~
            `{% endfor %}`,
            "135");

    // Else block
    assertRender(
            `{% for i in [] %}` ~
                `{{i}}` ~
            `{% else %}` ~
                `not iterated` ~
            `{% endfor %}`,
            "not iterated");

    assertRender(
            `{% for i in [1,2,3,4,5] if i > 5 %}` ~
                `{{i}}` ~
            `{% else %}` ~
                `else` ~
            `{% endfor %}`,
            "else");
}

unittest
{
    // Recursive iterating
    assertRender(
            `{% for i in [1,2,[3,4,[5,6]],7,[8], 9] recursive %}` ~
                `{{i if i not is list else loop(i) }}` ~
            `{% endfor %}`,
            "123456789");

    // Recursive iterating with filter
    assertRender(
            `{% for i in [1,2,[3,4,[5,6]],7,[8], 9] 
                                        if i not is number or i % 2 recursive %}` ~
                `{{i if i not is list else loop(i) }}` ~
            `{% endfor %}`,
            "13579");
}

unittest
{
    // Check loop.length, loop.index/0, loop.depth/0, loop.revindex/0, loop.first/last
    assertRender(
            `{% for i in [1,2,[3,4,[5,6]],7,8,[9]] 
                                        if i not is number or i % 2 recursive %}` ~
                `{% if i is list%}` ~
                    `{{loop(i)}}` ~
                `{% else %}` ~
                    `{{loop.length}},` ~
                    `{{loop.index}},{{loop.index0}},` ~
                    `{{loop.depth}},{{loop.depth0}},` ~
                    `{{loop.revindex}},{{loop.revindex0}},` ~
                    `{{loop.first}},{{loop.last}}` ~
                `{% endif %}` ~
            `{% endfor %}`,

            "4,1,0,1,0,4,3,true,false" ~
            "2,1,0,2,1,2,1,true,false" ~
            "1,1,0,3,2,1,0,true,true" ~
            "4,3,2,1,0,2,1,false,false" ~
            "1,1,0,2,1,1,0,true,true"
        );

    // Check loop.previtem, loop.nextitem
    assertRender(
            `{% for i in [1,2,[3,4,[5,6]],7,8,[9]] 
                                        if i not is number or i % 2 recursive %}` ~
                `{% if i is list%}` ~
                    `{{loop(i)}}` ~
                `{% else %}` ~
                    `prev: '{{loop.previtem}}', curr: '{{i}}', next: '{{loop.nextitem}}'` ~
                `{% endif %}` ~
            `{% endfor %}`,

            "prev: '', curr: '1', next: '[3, 4, [5, 6]]'" ~
            "prev: '', curr: '3', next: '[5, 6]'" ~
            "prev: '', curr: '5', next: ''" ~
            "prev: '[3, 4, [5, 6]]', curr: '7', next: '[9]'" ~
            "prev: '', curr: '9', next: ''"
        );

    // Check loop.cycle, loop.changed
    assertRender(
            `{% for i in [1,2,3,3,4,4,5,6,7] %}` ~
                `{{loop.cycle(1,2)}},{{loop.cycle(1,2,3)}},{{loop.changed(i)}}` ~
            `{% endfor %}`,

            "1,1,true" ~
            "2,2,true" ~
            "1,3,true" ~
            "2,1,false" ~
            "1,2,true" ~
            "2,3,false" ~
            "1,1,true" ~
            "2,2,true" ~
            "1,3,true"
        );
}
