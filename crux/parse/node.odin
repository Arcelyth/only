package parse

append_attrs_to_element :: proc(element: ^Element, token_attrs: [dynamic]Attribute) {
    // TODO
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


// https://infra.spec.whatwg.org/#namespaces
Namespace :: enum {
    HTML,
    MathML,
    SVG,
    XLink,
    XML,
    XMLNS,
}

// https://infra.spec.whatwg.org/#namespaces
namespace_uri :: proc(ns: Namespace) -> string {
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


// https://dom.spec.whatwg.org/#interface-node
Node :: struct {
	data: Node_Data,
	type: Node_Type,
    node_name: string,
    base_uri: string,
    is_connected: bool,
    owner_document: ^Document,
	parent_node: ^Node,
    parent_element: ^Element,
	child_nodes: [dynamic]^Node,
    first_child: ^Node,
    last_child: ^Node,
    // previous sibling
    prev_sibling: ^Node,
    next_sibling: ^Node,
    node_value: Maybe(string),
    text_content: Maybe(string),
}

Node_Type :: enum {
	Element,
    Attribute,
	Text,
    CDATA_Section,
    Entity_Reference,   // legacy
    Entity,             // legacy
    Processing_Instruction, 
	Comment,
	Document,
    Document_Type,
	Document_Fragment,
    Notation,           // legacy 
}

Node_Data :: union {
	Document,
	Element,
    // Text, CDATASection, ProcessingInstruction, Comment
    Character_Data,
}

// https://dom.spec.whatwg.org/#interface-document
Document :: struct {
    url: string,
    document_uri: string,
    compat_mode: string,
    character_set: string,
    charset: string,    // legacy alias of .character_set
    input_encoding: string, // legacy alias of .character_set
    content_type: string,
    doctype: ^Document_Type,
    document_element: ^Element,
}

// https://dom.spec.whatwg.org/#interface-documenttype
Document_Type :: struct {
    name: string,
    public_id: string,
    system_id: string,
}

// https://dom.spec.whatwg.org/#interface-documentfragment
Document_Fragment :: struct {}

// https://dom.spec.whatwg.org/#interface-domtokenlist
DOM_Token_List :: [dynamic]string

// https://dom.spec.whatwg.org/#interface-shadowroot
Shadow_Root :: struct {
    mode: Shadow_Root_Mode,
    delegates_focus: bool,
    slot_assignment: Slot_Assignment_Mode,
    clonable: bool,
    serializable: bool,
    host: bool,
    onslotchange: Maybe(Event_Handler),
}

Shadow_Root_Mode :: enum {
    SRM_Open,
    SRM_Closed,
}

Slot_Assignment_Mode :: enum {
    SAM_Manual,
    SAM_named,
}

// https://dom.spec.whatwg.org/#interface-element
Element :: struct {
	namespace: Namespace,
	prefix: Maybe(string),
	local_name: string,
    tag_name: string,
    id: string,
    class_name: string,
    class_list: DOM_Token_List,
    slot: string,
    // attributes
	attrs: []Attr,
	template_contents: ^Node,
	form_owner: ^Node,
    shadow_root: ^Shadow_Root,
    // custom element  registry
    custom_el_regisry: ^Custom_Element_Registry,
}

// https://dom.spec.whatwg.org/#interface-attr
Attr :: struct {
    namespace: Namespace,  
    prefix: Maybe(string),
    local_name: string,
    name: string,
    value: string,
    owner_element: ^Element,
    specified: bool // useless; always returns true
}

// https://dom.spec.whatwg.org/#interface-characterdata
Character_Data :: struct {
    data: string,
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#custom-elements-api
Custom_Element_Registry :: struct {}


