package parse

import "core:testing"

// ----- Preparations for the test
make_test_element :: proc(ns: Namespace, name: string, parent: ^Node = nil) -> ^Node {
	node := new(Node)
	node.type = .Element
	node.parent_node = parent
	
	el := Element{}
	el.namespace = ns
	el.local_name = name
	
	if ns == .HTML && name == "template" {
		tmpl_contents := new(Node)
		tmpl_contents.type = .Document_Fragment
		
		tmpl_el := Element{}
		tmpl_el.namespace = .HTML
		tmpl_el.local_name = "#template-contents"
		tmpl_contents.data = tmpl_el
		
		el.template_contents = tmpl_contents
	}
	
	node.data = el
	
	if parent != nil do append(&parent.child_nodes, node)
	return node
}

destroy_test_element :: proc(node: ^Node) {
	if node == nil do return
	
	for child in node.child_nodes do destroy_test_element(child)
	delete(node.child_nodes)
	
	switch &el in node.data {
	case Element:
		if el.template_contents != nil do destroy_test_element(el.template_contents)
		delete(el.attrs)
		delete(el.class_list)
	case Document:
	case Character_Data:
	}
	
	free(node)
}

// -----

// ----- Tests for appropriate_place_for_inserting_node.
@test
test_normal_insertion_location :: proc(t: ^testing.T) {
	p := Parser{}
	p.foster_parenting = false
	
	html := make_test_element(.HTML, "html")
	body := make_test_element(.HTML, "body", html)
	div := make_test_element(.HTML, "div", body)
	
	append(&p.open_elements, html, body, div)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
	}

	loc := appropriate_place_for_inserting_node(&p)
	
	testing.expect_value(t, loc.parent, div)
	testing.expect_value(t, loc.before_child, nil)
}

@test
test_foster_parenting_table_has_parent :: proc(t: ^testing.T) {
	p := Parser{}
	p.foster_parenting = true
	
	html := make_test_element(.HTML, "html")
	body := make_test_element(.HTML, "body", html)
	div := make_test_element(.HTML, "div", body)
	table := make_test_element(.HTML, "table", div)
	
	append(&p.open_elements, html, body, div, table)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
	}

	loc := appropriate_place_for_inserting_node(&p)
	
	testing.expect_value(t, loc.parent, div)
	testing.expect_value(t, loc.before_child, table)
}

@test
test_foster_parenting_table_has_no_parent :: proc(t: ^testing.T) {
	p := Parser{}
	p.foster_parenting = true
	
	html := make_test_element(.HTML, "html")
	body := make_test_element(.HTML, "body", html)
	div := make_test_element(.HTML, "div", body)
	table := make_test_element(.HTML, "table")
	
	append(&p.open_elements, html, body, div, table)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
		destroy_test_element(table)
	}

	loc := appropriate_place_for_inserting_node(&p)
	
	testing.expect_value(t, loc.parent, div)
	testing.expect_value(t, loc.before_child, nil)
}

@test
test_foster_parenting_template_is_newer_than_table :: proc(t: ^testing.T) {
	p := Parser{}
	p.foster_parenting = true
	
	html := make_test_element(.HTML, "html")
	table := make_test_element(.HTML, "table", html)
	template := make_test_element(.HTML, "template", table)
	
	append(&p.open_elements, html, table, template)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
	}

	loc := appropriate_place_for_inserting_node(&p, override_target = table)
	
	tmpl_contents: ^Node = nil
	if el, ok := template.data.(Element); ok {
		tmpl_contents = el.template_contents
	}

	testing.expect_value(t, loc.parent, tmpl_contents)
	testing.expect_value(t, loc.before_child, nil)
}

@test
test_foster_parenting_no_table_in_stack :: proc(t: ^testing.T) {
	p := Parser{}
	p.foster_parenting = true
	
	html := make_test_element(.HTML, "html")
	body := make_test_element(.HTML, "body", html)
	external_table := make_test_element(.HTML, "table")
	
	append(&p.open_elements, html, body)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
		destroy_test_element(external_table)
	}

	loc := appropriate_place_for_inserting_node(&p, override_target = external_table)
	
	testing.expect_value(t, loc.parent, html)
	testing.expect_value(t, loc.before_child, nil)
}

@test
test_template_contents_redirection :: proc(t: ^testing.T) {
	p := Parser{}
	p.foster_parenting = false
	
	html := make_test_element(.HTML, "html")
	template := make_test_element(.HTML, "template", html)
	
	append(&p.open_elements, html, template)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
	}

	loc := appropriate_place_for_inserting_node(&p)
	
	tmpl_contents: ^Node = nil
	if el, ok := template.data.(Element); ok {
		tmpl_contents = el.template_contents
	}

	testing.expect_value(t, loc.parent, tmpl_contents)
	testing.expect_value(t, loc.before_child, nil)
}

@test
test_foreign_template_no_redirection :: proc(t: ^testing.T) {
	p := Parser{}
	p.foster_parenting = false
	
	html := make_test_element(.HTML, "html")
	svg_template := make_test_element(.SVG, "template", html)
	
	append(&p.open_elements, html, svg_template)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
	}

	loc := appropriate_place_for_inserting_node(&p)
	
	testing.expect_value(t, loc.parent, svg_template)
	testing.expect_value(t, loc.before_child, nil)
}

@test
test_empty_open_elements :: proc(t: ^testing.T) {
	p := Parser{}

	loc := appropriate_place_for_inserting_node(&p)

	testing.expect_value(t, loc.parent, nil)
	testing.expect_value(t, loc.before_child, nil)
}
