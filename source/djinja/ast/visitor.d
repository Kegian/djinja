module djinja.ast.visitor;


private
{
    import djinja.ast.node;
}



mixin template VisitNode(T)
{
    void visit(T);
}


interface IVisitor
{
    static foreach(NT; NodeTypes)
    {
        mixin VisitNode!NT;
    }
}
