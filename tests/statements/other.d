module tests.statements.other_;

private
{
    import tests.asserts;
}


// Whitespace control
unittest
{
    assertRender(`{% if true %}`~" \n\t test \n\t "~`{% endif %}`, " \n\t test \n\t ");

    assertRender(`
        {%- for item in [1,2,3,4,5] -%}
            {{ item }}
        {%- endfor -%}
            `,
        "12345");

    assertRender(`
        {%- macro bubbleSort(l) %}
            {%- for i in l.length.range %}
                {%- for j in range(l.length - (i + 1)) %}
                    {%- if l[j] > l[j + 1]%}
                        {%- set l[j], l[j+1] = l[j+1], l[j] %}
                    {%- endif %}            
                {%- endfor %}
            {%- endfor %}
        {%- endmacro return l %}

        {%- set list = [5,4,3,2,1,0] -%}

        {{ bubbleSort(list) }}`,
        "[0, 1, 2, 3, 4, 5]");
}

// Inline statements
unittest
{
    assertRender(
`        # macro bubbleSort(l)
            # for i in l.length.range
                # for j in range(l.length - (i + 1))
                    # if l[j] > l[j + 1]
                        # set l[j], l[j+1] = l[j+1], l[j]
                    # endif
                # endfor
            # endfor
        # endmacro return l

        #- set list = [5,4,3,2,1,0] -

        {{ bubbleSort(list) }}`,
        "[0, 1, 2, 3, 4, 5]");

    // Multiline inline statements
    assertRender(
`# set a = [\
            1, \
            2, \
            3, \
          ] 
{{ a }}`,
        "[1, 2, 3]");
}
