module tests.statements.extends_;

private
{
    import tests.asserts;
}


unittest
{
    assertRender(
            `{% extends './tests/files/template.dj' %}` ~
            `{% block top %}CHILD_TOP{% endblock %}` ~
            `{% block super %}` ~ 
                `{{ super() }} : CHILD_SUPER` ~
            `{% endblock %}`
            ,
            `BASE_RAW_DATA` ~
            `CHILD_TOP` ~
            `BASE_SUPER : CHILD_SUPER` ~
            `BASE_BOTTOM`
        );
}


unittest
{
    assertException(`{% extends 'notexisting.dj' %}`);
}
