package parse

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
	head_element_pointer: ^Element,
	form_element_pointer: ^Element,

	active_formatting_elements: [dynamic]FormattingEntry,
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

handle_token :: proc(t: Token) {

}
