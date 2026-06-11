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

