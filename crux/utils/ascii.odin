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

trim_space :: proc(s: string) -> string {
	start := 0
	end := len(s)

	for start < end && is_html_space(s[start]) do start += 1
	for end > start && is_html_space(s[end-1]) do end -= 1
	return s[start:end]
}


