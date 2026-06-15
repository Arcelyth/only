package parse

append_attrs_to_element :: proc(element: ^Node, token_attrs: [dynamic]Attribute) {
	// TODO
}

element_has_attr_in_namespace :: proc(
	node: ^Node,
	ns: Namespace,
	attr_name: string,
) -> (
	string,
	bool,
) {
	if node == nil do return "", false
	el, is_el := node.data.(Element)
	if !is_el do return "", false

	for attr in el.attrs {
		if attr.namespace == ns && attr.name == attr_name do return attr.value, true
	}
	return "", false
}

// https://html.spec.whatwg.org/multipage/forms.html#category-reset
is_resettable_element :: proc(node: ^Node) -> bool {
	el, is_el := node.data.(Element)
	if !is_el do return false
	switch el.local_name {
	case "input", "output", "select", "textarea":
		return true
	}

	if is_form_associated_custom_element(node) do return true

	return false
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#form-associated-custom-element
is_valid_custom_element_name :: proc(name: string) -> bool {
	if len(name) == 0 do return false
	has_dash := false

	for ch in name {
		if ch >= 'A' && ch <= 'Z' do return false
		if ch == '-' do has_dash = true
	}

	if !has_dash do return false
	if name[0] < 'a' || name[0] > 'z' do return false

	return true
}

is_form_associated_custom_element :: proc(node: ^Node) -> bool {
	// TODO
	return false
}

is_form_associated_element :: proc(node: ^Node) -> bool {
	el, is_el := node.data.(Element)
	if !is_el do return false
	switch el.local_name {
	case "button", "fieldset", "input", "object", "output", "select", "textarea", "img":
		return true
	}

	return is_form_associated_custom_element(node)
}

associate_element_with_form :: proc(form: ^Node, element: ^Node) {
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
	case .HTML:
		return "http://www.w3.org/1999/xhtml"
	case .MathML:
		return "http://www.w3.org/1998/Math/MathML"
	case .SVG:
		return "http://www.w3.org/2000/svg"
	case .XLink:
		return "http://www.w3.org/1999/xlink"
	case .XML:
		return "http://www.w3.org/XML/1998/namespace"
	case .XMLNS:
		return "http://www.w3.org/2000/xmlns/"
	}
	return ""
}


// https://dom.spec.whatwg.org/#interface-node
Node :: struct {
	data:           Node_Data,
	type:           Node_Type,
	node_name:      string,
	base_uri:       string,
	is_connected:   bool,
	owner_document: ^Document,
	parent_node:    ^Node,
	parent_element: ^Element,
	child_nodes:    [dynamic]^Node,
	first_child:    ^Node,
	last_child:     ^Node,
	// previous sibling
	prev_sibling:   ^Node,
	next_sibling:   ^Node,
	node_value:     Maybe(string),
	text_content:   Maybe(string),
}

Node_Type :: enum {
	Element,
	Attribute,
	Text,
	CDATA_Section,
	Entity_Reference, // legacy
	Entity, // legacy
	Processing_Instruction,
	Comment,
	Document,
	Document_Type,
	Document_Fragment,
	Notation, // legacy
}

Node_Data :: union {
	Document,
	Element,
	Shadow_Root,
	// Text, CDATASection, ProcessingInstruction, Comment
	Character_Data,
}

// https://dom.spec.whatwg.org/#interface-document
Document :: struct {
	document_uri:       string,
	compat_mode:        string,
	character_set:      string,
	charset:            string, // legacy alias of .character_set
	input_encoding:     string, // legacy alias of .character_set
	// TODO: https://encoding.spec.whatwg.org/#encodings
	content_type:       string,
	doctype:            ^Document_Type,
	document_element:   ^Element,
	custom_el_registry: ^Custom_Element_Registry,
	encoding:           string,
	url:                string,
	origin:             Origin,
	type:               Document_Type,
	mod:                string,
}

// https://dom.spec.whatwg.org/#interface-documenttype
Document_Type :: enum {
	DT_XML,
	DT_HTML,
}

doc_type_to_string :: proc(dt: Document_Type) -> string {
	switch dt {
	case .DT_XML:
		return "xml"
	case .DT_HTML:
		return "html"
	}
	return ""
}

Document_Mode :: enum {
	No_Quirks,
	Quirks,
	Limited_Quirks,
}

doc_mode_to_string :: proc(dt: Document_Mode) -> string {
	switch dt {
	case .No_Quirks:
		return "no-quirks"
	case .Quirks:
		return "quirks"
	case .Limited_Quirks:
		return "limited-quirks"
	}
	return ""
}

// https://dom.spec.whatwg.org/#interface-documentfragment
Document_Fragment :: struct {}

Origin :: union {
	Opaque_Origin,
	Tuple_Origin,
}

Tuple_Origin :: struct {
	scheme: string,
	// TODO: https://url.spec.whatwg.org/#host-representation
	host:   string,
	port:   u16,
	domain: string,
}

Opaque_Origin :: struct {}

// https://dom.spec.whatwg.org/#interface-domtokenlist
DOM_Token_List :: [dynamic]string

// https://dom.spec.whatwg.org/#interface-shadowroot
Shadow_Root :: struct {
	mode:                         Shadow_Root_Mode,
	delegates_focus:              bool,
	available_to_el_internals:    bool,
	declarative:                  bool,
	slot_assignment:              Slot_Assignment_Mode,
	clonable:                     bool,
	serializable:                 bool,
	custom_el_registry:           ^Custom_Element_Registry,
	keep_custom_el_registry_null: bool,
	host:                         bool,
	onslotchange:                 Maybe(Event_Handler),
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
	namespace:          Namespace,
	prefix:             Maybe(string),
	local_name:         string,
	tag_name:           string,
	id:                 string,
	class_name:         string,
	class_list:         DOM_Token_List,
	slot:               string,
	// attributes
	attrs:              []Attr,
	template_contents:  ^Node,
	form_owner:         ^Node,
	shadow_root:        ^Shadow_Root,
	// custom element registry
	custom_el_registry: ^Custom_Element_Registry,
	// custom element state
	custom_el_state:    Custom_Element_State,
	// custom element definition
	custom_el_def:      ^Custom_Element_Definition,
	// valid custom element name
	is_value:           string,
}

// https://dom.spec.whatwg.org/#interface-attr
Attr :: struct {
	namespace:     Namespace,
	prefix:        Maybe(string),
	local_name:    string,
	name:          string,
	value:         string,
	owner_element: ^Element,
	specified:     bool, // useless; always returns true
}

// https://dom.spec.whatwg.org/#interface-characterdata
Character_Data :: struct {
	data: string,
}

// https://html.spec.whatwg.org/multipage/parsing.html#speculative-mock-element
Spec_Mock_Element :: struct {
	namespace:      string,
	local_name:     string,
	attribute_list: [dynamic]Attr,
	children:       [dynamic]^Node,
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#custom-elements-api
Custom_Element_Registry :: struct {
	is_scoped:           bool,
	scoped_document_set: map[^Document]struct{},
	// custom element definition set
	custom_el_def_set:   map[^Custom_Element_Definition]struct{},
	// element definition is running
	el_def_is_running:   bool,
	// TODO
	//when_defined_promise_map: map[srting]Promise,
}

lookup_custom_element_registry :: proc(node: ^Node) -> ^Custom_Element_Registry {
	el, is_el := node.data.(Element)
	if is_el do return el.custom_el_registry
	sr, is_sr := node.data.(Shadow_Root)
	if is_sr do return sr.custom_el_registry
	doc, is_doc := node.data.(Document)
	if is_doc do return doc.custom_el_registry
	return nil
}

Custom_Element_State :: enum {
	CE_Undefined,
	CE_Failed,
	CE_Uncustomized,
	CE_Precustomized,
	CE_Custom,
}

Custom_Element_Definition :: struct {
	// valid custom element name
	name:               string,
	local_name:         string,
	constructor:        ^proc(),
	// a list of observed attributes
	observed_attrs:     []string,
	// lifecycle callbacks
	lifcycle_cbs:       map[string]^proc(),
	construction_stack: [dynamic]CE_Construction_Stack_Entry,
	form_associated:    bool,
	disable_internals:  bool,
	disable_shadow:     bool,
}

CE_Construction_Stack_Entry_Kind :: enum {
	Element,
	AlreadyConstructedMarker,
}

CE_Construction_Stack_Entry :: struct {
	kind:    CE_Construction_Stack_Entry_Kind,
	element: ^Node,
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#look-up-a-custom-element-definition
lookup_custom_element_def :: proc(
	registry: ^Custom_Element_Registry,
	namespace: Namespace,
	local_name: string,
	is_name: string,
) -> ^Custom_Element_Definition {
	if registry == nil do return nil
	if namespace != .HTML do return nil

	if is_name == "" {
		// autonomous
		for def in registry.custom_el_def_set {
			if def.name == local_name && def.local_name == local_name do return def
		}
		return nil
	}

	// customized built-in
	for def in registry.custom_el_def_set {
		if def.name == is_name && def.local_name == local_name do return def
	}
	return nil
}
