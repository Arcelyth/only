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

Element :: struct {
    namespace: Namespace,
    prefix: string,
    local_name: string,
    attrs: [dynamic]Attribute,
    parent: ^Element,
}
