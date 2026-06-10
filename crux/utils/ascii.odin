package utils

is_html_space :: #force_inline proc(c: u8) -> bool {
	return c == 0x09 || c == 0x0A || c == 0x0C || c == 0x0D || c == 0x20
}

ascii_lower :: #force_inline proc(c: u8) -> u8 {
	if c >= 'A' && c <= 'Z' do return c + 0x20
	return c
}

ascii_eq_ci :: proc(a, b: string) -> bool {
	if len(a) != len(b) do return false
	for i in 0..<len(a) {
		if ascii_lower(a[i]) != ascii_lower(b[i]) do return false
	}
	return true
}

is_ascii_upper_alpha :: #force_inline proc(c: rune) -> bool {
	return c >= 'A' && c <= 'Z'
}

is_ascii_lower_alpha :: #force_inline proc(c: rune) -> bool {
	return c >= 'a' && c <= 'z'
}

is_ascii_alpha :: #force_inline proc(c: rune) -> bool {
	return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

trim_space :: proc(s: string) -> string {
	start := 0
	end := len(s)

	for start < end && is_html_space(s[start]) do start += 1
	for end > start && is_html_space(s[end-1]) do end -= 1
	return s[start:end]
}

is_ascii_digit :: #force_inline proc(c: rune) -> bool {
    return c >= '0' && c <= '9'
}

is_ascii_alphanum :: #force_inline proc(c: rune) -> bool {
    return is_ascii_alpha(c) || is_ascii_digit(c)
}

is_ascii_hex_digit :: #force_inline proc(c: rune) -> bool {
    return is_ascii_digit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

is_ascii_upper_hex_digit :: #force_inline proc(c: rune) -> bool {
    return c >= 'A' && c <= 'F'
}

is_ascii_lower_hex_digit :: #force_inline proc(c: rune) -> bool {
    return c >= 'a' && c <= 'f'
}

// https://infra.spec.whatwg.org/#surrogate
is_surrogate :: proc(c: rune) -> bool {
    return (c >= 0xD800 && c <= 0xDBFF) || // leading surragate
    (c >= 0xDC00 && c <= 0xDFFF)    // tailing surragate
} 

// https://infra.spec.whatwg.org/#noncharacter
is_noncharacter :: proc(c: rune) -> bool {
	if c >= 0xFDD0 && c <= 0xFDEF do return true
	return c <= 0x10FFFF && (c & 0xFFFE) == 0xFFFE
}

// https://infra.spec.whatwg.org/#ascii-whitespace
is_ascii_whitespace :: proc(c: rune) -> bool {
	return c == 0x09 || c == 0x0A || c == 0x0C || c == 0x0D || c == 0x20
}

// https://infra.spec.whatwg.org/#control
is_control :: proc(c: rune) -> bool {
	if c == 0 do return false
	if is_ascii_whitespace(c) do return false
	return (c >= 0x0001 && c <= 0x001F) || (c >= 0x007F && c <= 0x009F)
}

