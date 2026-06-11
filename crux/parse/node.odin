package parse

// https://infra.spec.whatwg.org/#namespaces
Namespace :: enum {
    HTML,
    MathML,
    SVG,
    XLink,
    XML,
    XMLNS,
}

Attribute :: struct {
    name: string,
    value: string,
}

DOM_Attribute :: struct {
    name: string,
    namespace: Namespace,
    value: string,
}

Element :: struct {
    namespace: Namespace,
    prefix: string,
    local_name: string,
    attrs: [dynamic]DOM_Attribute,
    parent: ^Element,
    children: [dynamic]^Element,
    template_contents: ^Element, 
}
