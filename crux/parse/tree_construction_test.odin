package parse

import "core:testing"

// ----- Preparations for the test
make_test_element :: proc(ns: Namespace, name: string, parent: ^Element = nil) -> ^Element {
	el := new(Element)
	el.namespace = ns
	el.local_name = name
	el.parent = parent
	
	if ns == .HTML && name == "template" {
		el.template_contents = new(Element)
		el.template_contents.namespace = .HTML
		el.template_contents.local_name = "#template-contents"
	}
	
	if parent != nil do append(&parent.children, el)
	return el
}

destroy_test_element :: proc(el: ^Element) {
	if el == nil do return
	if el.template_contents != nil {
		destroy_test_element(el.template_contents)
	}
	for child in el.children {
		destroy_test_element(child)
	}
	delete(el.children)
	delete(el.attrs)
	free(el)
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
	
	html     := make_test_element(.HTML, "html")
	table    := make_test_element(.HTML, "table", html)
	template := make_test_element(.HTML, "template", table)
	
	append(&p.open_elements, html, table, template)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
	}

	loc := appropriate_place_for_inserting_node(&p, override_target = table)
	
	testing.expect_value(t, loc.parent, template.template_contents)
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
	
	html     := make_test_element(.HTML, "html")
	template := make_test_element(.HTML, "template", html)
	
	append(&p.open_elements, html, template)
	defer {
		delete(p.open_elements)
		destroy_test_element(html)
	}

	loc := appropriate_place_for_inserting_node(&p)
	
	testing.expect_value(t, loc.parent, template.template_contents)
	testing.expect_value(t, loc.before_child, nil)
}

@test
test_foreign_template_no_redirection :: proc(t: ^testing.T) {
	p := Parser{}
	p.foster_parenting = false
	
	html        := make_test_element(.HTML, "html")
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

// ----- 
