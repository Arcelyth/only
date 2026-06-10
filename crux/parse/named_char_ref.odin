package parse

import "core:strings"

named_char_ref_map: map[string]string

init_html_named_character_references_map :: proc(allocator := context.allocator) {
    named_char_ref_map = make(map[string]string, 2300, allocator)
    named_char_ref_map["amp;"] = "&"
    named_char_ref_map["lt;"] = "<"
    named_char_ref_map["gt;"] = ">"
    named_char_ref_map["quot;"] = "\""
}

destroy_html_named_character_references_map :: proc() {
    delete(named_char_ref_map)
}
