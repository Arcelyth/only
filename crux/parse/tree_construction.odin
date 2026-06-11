package parse

import "core:strings"

// https://html.spec.whatwg.org/multipage/parsing.html#mathml-text-integration-point
is_mathml_text_integration_point :: proc(node: ^Element) -> bool {
	if node == nil do return false
	if node.namespace != .MathML do return false
	
	switch node.local_name {
	case "mi", "mo", "mn", "ms", "mtext":
		return true
	}
	return false
}

// https://html.spec.whatwg.org/multipage/parsing.html#html-integration-point
is_html_integration_point :: proc(node: ^Element) -> bool {
	if node == nil do return false
	
	if node.namespace == .SVG {
		switch node.local_name {
		case "foreignObject", "desc", "title":
			return true
		}
	}
	
	if node.namespace == .MathML && node.local_name == "annotation-xml" {
		for attr in node.attrs {
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

	if adjusted_node != nil && adjusted_node.namespace == .HTML {
		process_token_in_html_content(p, t)
		return
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

	if adjusted_node != nil && adjusted_node.namespace == .MathML && adjusted_node.local_name == "annotation-xml" {
		if start_val_ok && start_val.tag_name == "svg" {
			process_token_in_html_content(p, t)
			return
		}
	}

	if is_html_integration_point(adjusted_node) {
		if start_val_ok {
			process_token_in_html_content(p, t)
			return
		}
		if char_val_ok {
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
	parent: ^Element,
	before_child: ^Element, 
}

last_element_in_open_elements :: proc(p: ^Parser, ns: Namespace, local_name: string) -> (^Element, int) {
	#no_bounds_check for i := len(p.open_elements) - 1; i >= 0; i -= 1 {
		node := p.open_elements[i]
		if node.namespace == ns && node.local_name == local_name {
			return node, i
		}
	}
	return nil, -1
}

// https://html.spec.whatwg.org/multipage/parsing.html#appropriate-place-for-inserting-a-node
appropriate_place_for_inserting_node :: proc(p: ^Parser, override_target: ^Element = nil) -> InsertLocation {
	target := override_target if override_target != nil else current_node(p)
	if target == nil {
		return InsertLocation{}
	}
	
	loc := InsertLocation{}

	if p.foster_parenting && 
	   target.namespace == .HTML &&
	   (target.local_name == "table" || 
	    target.local_name == "tbody" || 
	    target.local_name == "tfoot" || 
	    target.local_name == "thead" || 
	    target.local_name == "tr") {

		last_template, last_template_idx := last_element_in_open_elements(p, .HTML, "template")
		last_table, last_table_idx := last_element_in_open_elements(p, .HTML, "table")

		if last_template != nil && (last_table == nil || last_template_idx > last_table_idx) {
			loc.parent = last_template.template_contents
			loc.before_child = nil
		} else if last_table == nil {
			loc.parent = p.open_elements[0]
			loc.before_child = nil
		} else if last_table.parent != nil {
			loc.parent = last_table.parent
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

	if loc.parent != nil && loc.parent.namespace == .HTML && loc.parent.local_name == "template" {
		loc.parent = loc.parent.template_contents
		loc.before_child = nil
	}

	return loc
}
