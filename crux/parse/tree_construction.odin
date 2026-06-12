package parse

import "core:strings"

// https://html.spec.whatwg.org/multipage/parsing.html#mathml-text-integration-point
is_mathml_text_integration_point :: proc(node: ^Node) -> bool {
	if node == nil do return false
	el, is_el := node.data.(Element)
	if !is_el do return false

	if el.namespace != .MathML do return false
	
	switch el.local_name {
	case "mi", "mo", "mn", "ms", "mtext": return true
	}
	return false
}

// https://html.spec.whatwg.org/multipage/parsing.html#html-integration-point
is_html_integration_point :: proc(node: ^Node) -> bool {
	if node == nil do return false
	el, is_el := node.data.(Element)
	if !is_el do return false

	if el.namespace == .SVG {
		switch el.local_name {
		case "foreignObject", "desc", "title": return true
		}
	}
	
	if el.namespace == .MathML && el.local_name == "annotation-xml" {
		for attr in el.attrs {
			if strings.equal_fold(attr.name, "encoding") {
				if strings.equal_fold(attr.value, "text/html") || strings.equal_fold(attr.value, "application/xhtml+xml") {
					return true
				}
			}
		}
	}
	
	return false
}

// https://html.spec.whatwg.org/multipage/parsing.html#tree-construction-dispatcher
dispatch :: proc(p: ^Parser, t: Token) {
	if p == nil do return

	if len(p.open_elements) == 0 {
		process_token_in_html_content(p, t)
		return
	}

	adjusted_node := adjusted_current_node(p)
	if adjusted_node == nil do return

	if adj_el, is_el := adjusted_node.data.(Element); is_el {
		if adj_el.namespace == .HTML {
			process_token_in_html_content(p, t)
			return
		}
	}

	start_val, start_val_ok := t.(Start_Token)
	char_val, char_val_ok := t.(Character_Token)
	eof_val, eof_val_ok := t.(EOF_Token)

	if is_mathml_text_integration_point(adjusted_node) {
		if start_val_ok && start_val.tag_name != "mglyph" && start_val.tag_name != "malignmark" {
			process_token_in_html_content(p, t)
			return
		}
		if char_val_ok {
			process_token_in_html_content(p, t)
			return
		}
	}

	if adj_el, is_el := adjusted_node.data.(Element); is_el {
		if adj_el.namespace == .MathML && adj_el.local_name == "annotation-xml" {
			if start_val_ok && start_val.tag_name == "svg" {
				process_token_in_html_content(p, t)
				return
			}
		}
	}

	if is_html_integration_point(adjusted_node) {
		if start_val_ok || char_val_ok {
			process_token_in_html_content(p, t)
			return
		}
	}

	if eof_val_ok {
		process_token_in_html_content(p, t)
		return
	}

	process_token_in_foreign_content(p, t)
}

process_token_in_html_content :: proc(p: ^Parser, t: Token) {
    
}

process_token_in_foreign_content :: proc(p: ^Parser, t: Token) {
}


InsertLocation :: struct {
	parent:       ^Node,
	before_child: ^Node, 
}

last_element_in_open_elements :: proc(p: ^Parser, ns: Namespace, local_name: string) -> (^Node, int) {
	#no_bounds_check for i := len(p.open_elements) - 1; i >= 0; i -= 1 {
		node := p.open_elements[i]
		el, is_el := node.data.(Element)
		if !is_el do continue
		if el.namespace == ns && el.local_name == local_name {
			return node, i
		}
	}
	return nil, -1
}

// https://html.spec.whatwg.org/multipage/parsing.html#appropriate-place-for-inserting-a-node
appropriate_place_for_inserting_node :: proc(p: ^Parser, override_target: ^Node = nil) -> InsertLocation {
	target := override_target if override_target != nil else current_node(p)
	if target == nil do return InsertLocation{}
	
	loc := InsertLocation{}

	el, is_el := target.data.(Element)
	
	if p.foster_parenting && is_el &&
	   el.namespace == .HTML &&
	   (el.local_name == "table" || 
		el.local_name == "tbody" || 
		el.local_name == "tfoot" || 
		el.local_name == "thead" || 
		el.local_name == "tr") {

		last_template, last_template_idx := last_element_in_open_elements(p, .HTML, "template")
		last_table, last_table_idx := last_element_in_open_elements(p, .HTML, "table")

		if last_template != nil && (last_table == nil || last_template_idx > last_table_idx) {
			if tmpl, ok := last_template.data.(Element); ok {
				loc.parent = tmpl.template_contents
			}
			loc.before_child = nil
		} else if last_table == nil {
			loc.parent = p.open_elements[0]
			loc.before_child = nil
		} else if last_table.parent_node != nil {
			loc.parent = last_table.parent_node
			loc.before_child = last_table
		} else {
			if last_table_idx == 0 {
				loc.parent = p.open_elements[0]
				return loc
			}
			previous_element := p.open_elements[last_table_idx - 1]
			loc.parent = previous_element
			loc.before_child = nil
		}
	} else {
		loc.parent = target
		loc.before_child = nil
	}

	if loc.parent != nil {
		if p_el, ok := loc.parent.data.(Element); ok && p_el.namespace == .HTML && p_el.local_name == "template" {
			loc.parent = p_el.template_contents
			loc.before_child = nil
		}
	}

	return loc
}


//look_up_custom_element_registry :: proc(node: ^Element) -> CustomElementRegistry {
//    return CustomElementRegistry{}  
//}
//
//look_up_custom_element_definition :: proc(registry: CustomElementRegistry, namespace: Namespace, local_name: string, is: Maybe(string)) -> Maybe(CustomElementDefinition) {
//    return nil 
//}
//
//reset_algorithm :: proc(el: ^Element) {
//    // TODO
//}
//
//is_in_same_tree :: proc(intended_parent: ^Element, form_ptr: ^Element) -> bool {
//	if intended_parent == nil || form_ptr == nil do return false
//	return true 
//}
//
//// https://html.spec.whatwg.org/multipage/parsing.html#create-an-element-for-the-token
//create_element_for_token :: proc(p: ^Parser, tok: Start_Token, namespace: Namespace, intended_parent: ^Element) -> ^Element {
//	local_name := tok.tag_name 
//
//	is_attr_value := ""
//	for attr in tok.attrs {
//		if attr.name == "is" {
//			is_attr_value = attr.value
//			break
//		}
//	}
//
//	registry := look_up_custom_element_registry(intended_parent)
//	definition := look_up_custom_element_definition(registry, namespace, local_name, is_attr_value)
//
//	will_execute_script := (definition != nil) && !p.fragment_case
//
//	if will_execute_script {
//		// TODO: 9
//	}
//
//	el := new(Element)
//	el.namespace = namespace
//	el.local_name = local_name
//	el.is_value = is_attr_value
//	el.attrs = make([dynamic]DOM_Attribute)
//
//	if el.namespace == .HTML && el.local_name == "template" {
//		el.template_contents = new(Element)
//		el.template_contents.namespace = .HTML
//		el.template_contents.local_name = "#document-fragment"
//		el.template_contents.attrs = make([dynamic]DOM_Attribute)
//	}
//
//	append_attrs_to_element(el, tok.attrs)
//
//	if will_execute_script {
//		// TODO: 12 
//	}
//
//	if v, ok := element_has_attr_in_namespace(el, .XMLNS, "xmlns"); ok {
//		if v != namespace_to_string(el.namespace) {
//			// TODO: 13 
//		}
//	}
//	if v, ok := element_has_attr_in_namespace(el, .XMLNS, "xmlns:xlink"); ok {
//		if v != "http://www.w3.org/1999/xlink" {
//			// TODO: 14 
//		}
//	}
//
//	if is_resettable_element(el) && !is_form_associated_custom_element(el) {
//		reset_algorithm(el)
//	}
//
//	if is_form_associated_element(el) &&
//	   !is_form_associated_custom_element(el) &&
//	   p.form_element_pointer != nil {
//
//		has_template := false
//		for node in p.open_elements {
//			if node != nil && node.namespace == .HTML && node.local_name == "template" {
//				has_template = true
//				break
//			}
//		}
//
//		if !has_template {
//			has_form_attr := false
//			for attr in el.attrs {
//				if attr.name == "form" {
//					has_form_attr = true
//					break
//				}
//			}
//			if !has_form_attr && is_in_same_tree(intended_parent, p.form_element_pointer) {
//				associate_element_with_form(p.form_element_pointer, el)
//				el.parser_inserted = true
//			}
//		}
//	}
//
//	return el
//}
