# djinja


## About

This library is an attempt to implement [Jinja2 template engine](http://jinja.pocoo.org/docs/2.10/templates/) on D language.

### 1. Supported features

##### Default delimiters:

* Statements `{%` ... `%}`
* Expressions `{{` ... `}}`
* Comments `{#` ... `#}`
* Line statements `#`, comments `##`

##### Variables:

* Variable itself: `foo`
* Variable's field: `foo.bar` or `foo['bar']`
* Variables array: `foos[2]`

##### Expressions:

* Integer number: `42`
* Floating number `42.2`
* String: `"Some string"`, `'Another string'`
* Boolean: `true`/`false`, `True`/`False`
* Array: `[1, 'string', false]`
* List: `(1, 'string', false)` *note: internal list representation still is array*
* Dictionary: `{'a': 10, 'b': true}` or `{a: 10, b: true}` ***note: keys in dictionary can only be strings*** 
* Math Operators: `**`, `*`, `/`, `//`, `%`, `+`, `-`
* Logic operators: `(` ... `)`, `not`, `and`, `or`
* Comparison operators: `==`, `!=`, `>=`, `<=`, `>`, `<`
* Other operators: `in`, `is`, `|`, `~`, `...(...)`
* Ternary if: `... if ... else ...`

##### Statements:

* If: `if`/`elif`/`else`/`endif`
* For: `for`/`else`/`endfor`
* Macros: `macro`/`endmacro`
* Call: `call`/`endcall`
* Set: `set`
* Filter: `filter`
* Extending: `extends`, `block`/`endblock`
* Import: `import`
* Include: `include`
* With: `with`/`endwith` *note: without assignment*

##### Whitespace control:

Space control with `-` operator allowed only for statements: `{%- ... -%}`

##### Functions:

Most of global functions / tests / filters are not implemented at the moment. Must be done later.

* Implemented functions: `range`, `length`/`count`, `namespace`
* Implemented test: `defined`, `undefined`, `number`, `list`, `dict`
* Implemented filters: `default`/`d`, `escape`/`e`, `upper`, `sort`, `keys`

### 2. Main differences

##### Assignment scope behavior:

Unlike original Jinja it is possible to set variables inside a block and have them show up outside of it. This means that the following example will work as expected.

```jinja
{% set iterated = false %}
{% for item in seq %} ## non-empty sequence
    {{ item }}
    {% set iterated = true %}
{% endfor %}
{% if not iterated %} did not iterate {% endif %} ## will not be printed (iterated == true)
```

### 3. Additional features

##### 1. Set variable fields / array members

It is possible to set variable field and member of array:

```jinja
{% set foo = {} %}
{% set foo.bar = 10 %}
{{ foo.bar }} ## 10
```

```jinja
{% set foos = [1, 2, 3] %}
{% set foos[2] = 30 %}
{{ foos }} ## [1, 2, 30]
```

##### 2. UFCS

It is possible to use Uniform Function Call Syntax for variables like in D:

```jinja
{% set foo = [1, 1, 1, 1, 1] %}
{{ range(length(foo)) }} ## [0, 1, 2, 3, 4]
{{ foo.length.range }}   ## [0, 1, 2, 3, 4]
```

##### 3. Macro return expression

You can return value from user defined macros due to `return` keyword in `endmacro` statement:

```jinja
{% macro sum(numbers) %}
    {% sum = 0 %}
    {% for num in numbers %}
        {% sum = sum + num %}
    {% endfor %}
{% endmacro return sum %}

{{ sum([1, 2, 3, 4]) * 10 }} ## 100
```

##### 4. Macro as function / test / filter

Since macros can return value, you can use them as functions / filters / tests:

```jinja
{% macro sum(numbers) %}
    {% sum = 0 %}
    {% for num in numbers %}
        {% sum = sum + num %}
    {% endfor %}
{% endmacro return sum %}

{{ [0, 1, 2, 4] | sum | e }} ## 4
```

```jinja
{% macro large(l) %}
{% endmacro return l is list and l.length > 10 %}

{{ 'yes' if [0, 1, 2] is large else 'no' }} ## no
```

##### 5. Macro as closure

It is possible to define macro inside another macro and inner macro has link to external contexts.
```jinja
{% set a = 1 %}
{% macro m1 %}  ## variables `a`, `b` are available inside 
    {% set b = 2 %}
    {% macro m2 %}  ## variables `a`, `b`, `c` are available inside
    	{% set c = 3 %}
    {% endmcaro %}
{% endmcaro %}
```
```jinja
{% set counter = 0 -%}

{%- macro inc() -%}
    {% set counter = counter + 1 %}
{%- endmacro return counter -%}

{{ inc() }} ## 1
{{ inc() }} ## 2
{{ inc() }} ## 3
{{ inc() }} ## 4
```


## Usage

##### 1. Public imported functions

###### renderData
```d 
string renderData(T...)(string tmpl);
```
Rendering data from the template

*Parameters:*
* `T...` - aliases for exported variables and functions
* `tmpl` - template to be rendered

*Returns:* rendered template

###### renderFile
```d 
string renderData(T...)(string path);
```
Rendering data from the file

*Parameters:*
* `T...` - aliases for exported variables and functions
* `path` - path to template file

*Returns:* rendered template

###### loadData
```d 
TemplateNode loadData(JinjaConfig config = defaultConfig)(string tmpl);
```
Parsing template from string to AST for further rendering

*Parameters:*
* `config` - configuration for djinja
* `tmpl` - template to be parsed

*Returns:* parsed template

###### loadFile
```d 
TemplateNode loadFile(JinjaConfig config = defaultConfig)(string path);
```
Parsing template from file to AST for further rendering via `render` function

*Parameters:*
* `config` - configuration for djinja
* `path` - path to template file

*Returns:* parsed template

###### render
```d 
string render(T...)(TemplateNode tree);
```
Rendering data from the AST

*Parameters:*
* `T...` - aliases for exported variables and functions
* `tree` - parsed template

*Returns:* rendered template

###### JinjaConfig
Default configuration:
```d
struct JinjaConfig
{
    string exprOpBegin  = "{{";
    string exprOpEnd    = "}}";
    string stmtOpBegin  = "{%";
    string stmtOpEnd    = "%}";
    string cmntOpBegin  = "{#";
    string cmntOpEnd    = "#}";
    string cmntOpInline = "##";
    string stmtOpInline = "#";
}
```

##### 2. Examples

```d
import std.stdio;
import djinja;

int sum(int a, int b)
{
    return a + b;
}

void main()
{
    int num = 10;
    auto result = renderData!(num, sum)("{{ sum(num, 15) }}");
    writeln(result); // 25
}
```

```d
import std.stdio;
import djinja;

int sum(int a, int b)
{
    return a + b;
}

void main()
{

    enum JinjaConfig conf = { exprOpBegin: "<", exprOpEnd: ">" }; 

    auto ast = loadFile!(conf)("simple.dj"); // simple.dj: "< sum(1, 2) >"
    auto result = render!(sum)(ast);

    writeln(result); // 3
}
```

### Todo list

* Make a wrapper for UniNode that allows using macros as passed values
* Add flag to config allowing override set behavior to its original one
* Extend whitespace control behavior
* Add more tests
