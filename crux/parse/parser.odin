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
    open_elements: [dynamic]^Element,
    fragment_case: bool,
    context_element: ^Element,
	active_formatting_elements: [dynamic]FormattingEntry,
    // https://html.spec.whatwg.org/multipage/parsing.html#the-element-pointers
	head_element_pointer: ^Element,
	form_element_pointer: ^Element,
    // https://html.spec.whatwg.org/multipage/parsing.html#other-parsing-state-flags
    scripting_mode: ScriptingMode,
	frameset_ok: bool,
    tokenizer: Tokenizer,
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
	element: ^Element,
	token: Token,
}

current_node :: proc(p: ^Parser) -> ^Element {
    if len(p.open_elements) == 0 do return nil
    return p.open_elements[len(p.open_elements)-1]
}

adjusted_current_node :: proc(p: ^Parser) -> ^Element {
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
    node := p.open_elements[idx]
    for {
        if idx == 0 {
            last = true
            if p.fragment_case && p.context_element != nil do node = p.context_element
        }
        if (node.local_name == "td" || node.local_name == "th") && !last {
			p.insert_mode = .InCell
			return
		}
        if node.local_name == "tr" {
			p.insert_mode = .InRow
			return
		}

		if node.local_name == "tbody" || node.local_name == "thead" || node.local_name == "tfoot" {
			p.insert_mode = .InTableBody
			return
		}

		if node.local_name == "caption" {
			p.insert_mode = .InCaption
			return
		}

		if node.local_name == "colgroup" {
			p.insert_mode = .InColumnGroup
			return
		}

		if node.local_name == "table" {
			p.insert_mode = .InTable
			return
		}

        if node.local_name == "template" {
			if len(p.temp_insert_modes) > 0 do p.insert_mode = p.temp_insert_modes[len(p.temp_insert_modes) - 1]
			return
		}

		if node.local_name == "head" && !last {
			p.insert_mode = .InHead
			return
		}

		if node.local_name == "body" {
			p.insert_mode = .InBody
			return
		}

		if node.local_name == "frameset" {
			p.insert_mode = .InFrameset
			return
		}

		if node.local_name == "html" {
			if p.head_element_pointer == nil do p.insert_mode = .BeforeHead
			else do p.insert_mode = .AfterHead
			return
		}

		if last {
            p.insert_mode = .InBody
			return
		}

		if idx == 0 do break
		idx -= 1
		node = p.open_elements[idx]
    }
} 

is_special_element :: proc(node: ^Element) -> bool {
	if node == nil do return false

    #partial switch node.namespace {
    case .HTML: 
        switch node.local_name {
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
		switch node.local_name {
		case "mi", "mo", "mn", "ms", "mtext", "annotation-xml":
			return true
		}
    case .SVG: 
		switch node.local_name {
		case "foreignObject", "desc", "title":
			return true
		}
    }

    return false
}

is_formatting_element :: proc(node: ^Element) -> bool {
	if node == nil || !(node.namespace == .HTML) do return false

	switch node.local_name {
	case "a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u":
		return true
	}

	return false
}

is_scope_boundary :: proc(node: ^Element) -> bool {
    if node == nil do return false

    #partial switch node.namespace {
    case .HTML: 
        switch node.local_name {
        case "applet", "caption", "html", "table", "td", "th", "marquee", "object", "select", "template":
            return true
        }
    case .MathML: 
        switch node.local_name {
        case "mi", "mo", "mn", "ms", "mtext", "annotation-xml":
            return true
        }
    case .SVG: 
        switch node.local_name {
        case "foreignObject", "desc", "title":
            return true
        } 
    }
    return false
}

is_list_item_scope_boundary :: proc(node: ^Element) -> bool {
    if is_scope_boundary(node) do return true

    if node.namespace == .HTML {
        return node.local_name == "ol" || node.local_name == "ul"
    }

    return false
}

is_button_scope_boundary :: proc(node: ^Element) -> bool {
    if is_scope_boundary(node) do return true

    return node.namespace == .HTML && node.local_name == "button"
}

is_table_scope_boundary :: proc(node: ^Element)->bool {
    if node.namespace != .HTML do return false

    switch node.local_name {
    case "html", "table", "template": 
        return true
    }

    return false
}

has_element_in_scope :: proc(p: ^Parser, target: ^Element, boundary: proc(^Element)->bool) -> bool {
    for i := len(p.open_elements)-1; i >= 0; i -= 1 {
        node := p.open_elements[i]
        if node.local_name == target.local_name do return true
        if boundary(node) do return false
    }

    return false
}

// --- TODO ---
insert_html_element_for_token :: proc(p: ^Parser, token: Token) -> ^Element {
    elem := new(Element)
    return elem
}

are_attributes_equal :: proc(a, b: [dynamic]DOM_Attribute) -> bool {
	if len(a) != len(b) do return false
	if len(a) == 0 do return true

	visited_buf: [64]bool
	visited := visited_buf[:len(b)]
	if len(b) > 64 {
		visited = make([]bool, len(b), context.temp_allocator)
	}

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

push_active_formatting_element :: proc(p: ^Parser, el: ^Element, tok: Token) {
	if p == nil || el == nil do return

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
		
		e1 := entry.element
		if e1.local_name == el.local_name && e1.namespace == el.namespace {
			if are_attributes_equal(e1.attrs, el.attrs) {
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
		element = el,
		token = tok,
	})
}

push_formatting_marker :: proc(p: ^Parser) {
	append(&p.active_formatting_elements, FormattingEntry{ kind = .Marker})
}

element_in_open_elements :: proc(p: ^Parser, elem: ^Element) -> bool {
    for e in p.open_elements do if e == elem do return true
    return false
}

reconstruct_active_formatting_elements :: proc(p: ^Parser) {
	if p == nil || len(p.active_formatting_elements) == 0 do return

	last := p.active_formatting_elements[len(p.active_formatting_elements)-1]

	if last.kind == .Marker do return
	if last.kind == .Element && element_in_open_elements(p, last.element) do return

	entry_idx := len(p.active_formatting_elements) - 1

    // rewind
	for {
		if entry_idx == 0 do break
		entry_idx -= 1

		entry := p.active_formatting_elements[entry_idx]
		if entry.kind == .Marker {
			entry_idx += 1
			break
		}
		if entry.kind == .Element && element_in_open_elements(p, entry.element) {
			entry_idx += 1
			break
		}
	}

	// advance/create
	for entry_idx < len(p.active_formatting_elements) {
		entry := p.active_formatting_elements[entry_idx]
		if entry.kind == .Marker {
			entry_idx += 1
			continue
		}

		new_el := insert_html_element_for_token(p, entry.token)
		p.active_formatting_elements[entry_idx].element = new_el

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

