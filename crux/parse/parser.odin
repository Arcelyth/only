package parse

import "core:slice"

InsertionMode :: enum {
	Initial,
	BeforeHtml,
	BeforeHead,
	InHead,
	InHeadNoscript,
	AfterHead,
	InBody,
	Text,
	InTable,
	InTableText,
	InCaption,
	InColumnGroup,
	InTableBody,
	InRow,
	InCell,
	InTemplate,
	AfterBody,
	InFrameset,
	AfterFrameset,
	AfterAfterBody,
	AfterAfterFrameset,
}

ScriptingMode :: enum {
	Normal,
	Disabled,
	Inert,
	Fragment,
}

Parser :: struct {
    // insertion mode
    insert_mode: InsertionMode,
    // original insertion mode
    orig_insert_mode: InsertionMode,
    // template insertion mode
    temp_insert_modes: [dynamic]InsertionMode,
    open_elements: [dynamic]^Node,
    fragment_case: bool,
    context_element: ^Node,
	active_formatting_elements: [dynamic]FormattingEntry,
    // https://html.spec.whatwg.org/multipage/parsing.html#the-element-pointers
	head_element_pointer: ^Node,
	form_element_pointer: ^Node,
    // https://html.spec.whatwg.org/multipage/parsing.html#other-parsing-state-flags
    scripting_mode: ScriptingMode,
	frameset_ok: bool,
    tokenizer: Tokenizer,
    foster_parenting: bool,
}

new_parser :: proc() {

}

destroy_parser :: proc() {

}

FormattingEntryKind :: enum {
	Element,
	Marker,
}

FormattingEntry :: struct {
	kind: FormattingEntryKind,
	element: ^Node,
	token: Token,
}

current_node :: proc(p: ^Parser) -> ^Node {
    if len(p.open_elements) == 0 do return nil
    return p.open_elements[len(p.open_elements)-1]
}

adjusted_current_node :: proc(p: ^Parser) -> ^Node {
    if p == nil do return nil

    if p.fragment_case && len(p.open_elements) == 1 && p.context_element != nil {
        return p.context_element
    }

    return current_node(p)
}

// https://html.spec.whatwg.org/multipage/parsing.html#reset-the-insertion-mode-appropriately
reset_insertion_mode_appropriately :: proc(p: ^Parser) {
	if p == nil || len(p.open_elements) == 0 do return 

	last := false
	idx := len(p.open_elements) - 1

	for {
		node := p.open_elements[idx]
		if idx == 0 {
			last = true
			if p.fragment_case && p.context_element != nil do node = p.context_element
		}

		if el, is_el := node.data.(Element); is_el {
			if (el.local_name == "td" || el.local_name == "th") && !last {
				p.insert_mode = .InCell
				return
			}
			if el.local_name == "tr" {
				p.insert_mode = .InRow
				return
			}
			if el.local_name == "tbody" || el.local_name == "thead" || el.local_name == "tfoot" {
				p.insert_mode = .InTableBody
				return
			}
			if el.local_name == "caption" {
				p.insert_mode = .InCaption
				return
			}
			if el.local_name == "colgroup" {
				p.insert_mode = .InColumnGroup
				return
			}
			if el.local_name == "table" {
				p.insert_mode = .InTable
				return
			}
			if el.local_name == "template" {
				if len(p.temp_insert_modes) > 0 {
					p.insert_mode = p.temp_insert_modes[len(p.temp_insert_modes) - 1]
				}
				return
			}
			if el.local_name == "head" && !last {
				p.insert_mode = .InHead
				return
			}
			if el.local_name == "body" {
				p.insert_mode = .InBody
				return
			}
			if el.local_name == "frameset" {
				p.insert_mode = .InFrameset
				return
			}
			if el.local_name == "html" {
				if p.head_element_pointer == nil do p.insert_mode = .BeforeHead
				else do p.insert_mode = .AfterHead
				return
			}
		}

		if last {
			p.insert_mode = .InBody
			return
		}

		if idx == 0 do break
		idx -= 1
	}
}

is_special_element :: proc(node: ^Node) -> bool {
	if node == nil do return false

    el, is_el := node.data.(Element)
	if !is_el do return false

    #partial switch el.namespace {
    case .HTML: 
        switch el.local_name {
        case "address", "applet", "area", "article", "aside", "base", "basefont", "bgsound",
		     "blockquote", "body", "br", "button", "caption", "center", "col", "colgroup",
		     "dd", "details", "dir", "div", "dl", "dt", "embed", "fieldset", "figcaption",
		     "figure", "footer", "form", "frame", "frameset", "h1", "h2", "h3", "h4", "h5",
		     "h6", "head", "header", "hgroup", "hr", "html", "iframe", "img", "input",
		     "keygen", "li", "link", "listing", "main", "marquee", "menu", "meta", "nav",
		     "noembed", "noframes", "noscript", "object", "ol", "p", "param", "plaintext",
		     "pre", "script", "search", "section", "select", "source", "style", "summary",
		     "table", "tbody", "td", "template", "textarea", "tfoot", "th", "thead", "title",
		     "tr", "track", "ul", "wbr", "xmp":
			return true
        }
    case .MathML:  
		switch el.local_name {
		case "mi", "mo", "mn", "ms", "mtext", "annotation-xml":
			return true
		}
    case .SVG: 
		switch el.local_name {
		case "foreignObject", "desc", "title":
			return true
		}
    }

    return false
}

is_formatting_element :: proc(node: ^Node) -> bool {
	if node == nil do return false

    el, is_el := node.data.(Element)
	if !is_el || el.namespace != .HTML do return false

	switch el.local_name {
	case "a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u":
		return true
	}

	return false
}

is_scope_boundary :: proc(node: ^Node) -> bool {
    if node == nil do return false

    el, is_el := node.data.(Element)
	if !is_el do return false

    #partial switch el.namespace {
    case .HTML: 
        switch el.local_name {
        case "applet", "caption", "html", "table", "td", "th", "marquee", "object", "select", "template":
            return true
        }
    case .MathML: 
        switch el.local_name {
        case "mi", "mo", "mn", "ms", "mtext", "annotation-xml":
            return true
        }
    case .SVG: 
        switch el.local_name {
        case "foreignObject", "desc", "title":
            return true
        } 
    }
    return false
}

is_list_item_scope_boundary :: proc(node: ^Node) -> bool {
	if is_scope_boundary(node) do return true
	
	if el, is_el := node.data.(Element); is_el && el.namespace == .HTML {
		return el.local_name == "ol" || el.local_name == "ul"
	}
	return false
}

is_button_scope_boundary :: proc(node: ^Node) -> bool {
	if is_scope_boundary(node) do return true

	if el, is_el := node.data.(Element); is_el && el.namespace == .HTML {
		return el.local_name == "button"
	}
	return false
}

is_table_scope_boundary :: proc(node: ^Node) -> bool {
	if node == nil do return false
	el, is_el := node.data.(Element)
	if !is_el || el.namespace != .HTML do return false

	switch el.local_name {
	case "html", "table", "template": return true
	}
	return false
}

has_element_in_scope :: proc(p: ^Parser, target: ^Node, boundary: proc(^Node)->bool) -> bool {
	if p == nil || target == nil do return false
	
	target_el, target_is_el := target.data.(Element)
	if !target_is_el do return false

	for i := len(p.open_elements) - 1; i >= 0; i -= 1 {
		node := p.open_elements[i]
		
		if el, is_el := node.data.(Element); is_el {
			if el.local_name == target_el.local_name && el.namespace == target_el.namespace {
				return true
			}
		}
		
		if boundary(node) do return false
	}

	return false
}

// --- TODO ---
insert_html_element_for_token :: proc(p: ^Parser, token: Token) -> ^Node {
	node := new(Node)
	el := Element{}
	
	node.data = el
	return node
}

are_attributes_equal :: proc(a, b: []Attr) -> bool {
	if len(a) != len(b) do return false
	if len(a) == 0 do return true

	visited_buf: [64]bool
	visited := visited_buf[:len(b)]
	if len(b) > 64 do visited = make([]bool, len(b), context.temp_allocator)

	for attr_a in a {
		found := false
		for attr_b, idx in b {
			if visited[idx] do continue

			if attr_a.name == attr_b.name && 
			   attr_a.namespace == attr_b.namespace &&
			   attr_a.value == attr_b.value {
				visited[idx] = true
				found = true
				break
			}
		}
		if !found do return false
	}

	return true
}

push_active_formatting_element :: proc(p: ^Parser, node: ^Node, tok: Token) {
	if p == nil || node == nil do return
	
	el_data, is_el := node.data.(Element)
	if !is_el do return

	since_marker := 0
	for i := len(p.active_formatting_elements) - 1; i >= 0; i -= 1 {
		if p.active_formatting_elements[i].kind == .Marker {
			since_marker = i + 1
			break
		}
	}

	same_count := 0
	earliest_same := -1

	for i := since_marker; i < len(p.active_formatting_elements); i += 1 {
		entry := p.active_formatting_elements[i]
		if entry.kind != .Element do continue
		
		e1_data, ok := entry.element.data.(Element)
		if !ok do continue
		
		if e1_data.local_name == el_data.local_name && e1_data.namespace == el_data.namespace {
			if are_attributes_equal(e1_data.attrs, el_data.attrs) {
				same_count += 1
				if earliest_same == -1 do earliest_same = i
			}
		}
	}

	if same_count >= 3 && earliest_same != -1 {
		ordered_remove(&p.active_formatting_elements, earliest_same)
	}

	append(&p.active_formatting_elements, FormattingEntry{
		kind = .Element,
		element = node,
		token = tok,
	})
}

push_formatting_marker :: proc(p: ^Parser) {
	if p == nil do return
	append(&p.active_formatting_elements, FormattingEntry{ kind = .Marker })
}

node_in_open_elements :: proc(p: ^Parser, node: ^Node) -> bool {
	if p == nil || node == nil do return false
	for e in p.open_elements {
		if e == node do return true
	}
	return false
}

reconstruct_active_formatting_elements :: proc(p: ^Parser) {
	if p == nil || len(p.active_formatting_elements) == 0 do return

	last := p.active_formatting_elements[len(p.active_formatting_elements)-1]

	if last.kind == .Marker do return
	if last.kind == .Element && node_in_open_elements(p, last.element) do return

	entry_idx := len(p.active_formatting_elements) - 1

	for {
		if entry_idx == 0 do break
		entry_idx -= 1

		entry := p.active_formatting_elements[entry_idx]
		if entry.kind == .Marker {
			entry_idx += 1
			break
		}
		if entry.kind == .Element && node_in_open_elements(p, entry.element) {
			entry_idx += 1
			break
		}
	}

	for entry_idx < len(p.active_formatting_elements) {
		entry := p.active_formatting_elements[entry_idx]
		if entry.kind == .Marker {
			entry_idx += 1
			continue
		}

		new_node := insert_html_element_for_token(p, entry.token)
		
		p.active_formatting_elements[entry_idx].element = new_node

		if entry_idx == len(p.active_formatting_elements) - 1 do break
		entry_idx += 1
	}
}

clear_active_formatting_elements_up_to_last_marker :: proc(p: ^Parser) {
	if p == nil do return

	for len(p.active_formatting_elements) > 0 {
		entry := pop(&p.active_formatting_elements)
		if entry.kind == .Marker do return
	}
}
