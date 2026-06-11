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
    parser_inserted: bool,
    is_value: string,
}

Document :: struct {}

ShadowRoot :: struct {}

Node :: union {
    Element,
    ShadowRoot,
    Document,
}

append_attrs_to_element :: proc(element: ^Element, token_attrs: [dynamic]Attribute) {
    // TODO
}

// https://infra.spec.whatwg.org/#namespaces
namespace_to_string :: proc(ns: Namespace) -> string {
	switch ns {
	case .HTML: return "http://www.w3.org/1999/xhtml"
	case .MathML: return "http://www.w3.org/1998/Math/MathML"
	case .SVG: return "http://www.w3.org/2000/svg"
	case .XLink: return "http://www.w3.org/1999/xlink"
	case .XML: return "http://www.w3.org/XML/1998/namespace"
	case .XMLNS: return "http://www.w3.org/2000/xmlns/"
	}
	return ""
}

element_has_attr_in_namespace :: proc(el: ^Element, ns: Namespace, attr_name: string) -> (string, bool) {
	if el == nil do return "", false
	for attr in el.attrs {
		if attr.namespace == ns && attr.name == attr_name do return attr.value, true
	}
	return "", false
}

// https://html.spec.whatwg.org/multipage/forms.html#category-reset
is_resettable_element :: proc(el: ^Element) -> bool {
	switch el.local_name {
	case "input", "output", "select", "textarea":
		return true
	}

	if is_form_associated_custom_element(el) do return true

	return false
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#form-associated-custom-element
is_form_associated_custom_element :: proc(el: ^Element) -> bool {
    // TODO
	return false
}

is_form_associated_element :: proc(el: ^Element) -> bool {
    // TODO
	return false
}

associate_element_with_form :: proc(form: ^Element, element: ^Element) {
    // TODO
}
