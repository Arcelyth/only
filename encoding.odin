// implementation of encoding sniffing algorithm

package only

Attr :: struct {
	name:  string,
	value: string,
}

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

// TODO: add more 
label_to_name :: proc(label: string) -> Maybe(string) {
	l := trim_space(label)
	if len(l) == 0 do return nil

	if ascii_eq_ci(l, "utf-8") do return "UTF-8"
	if ascii_eq_ci(l, "utf8") do return "UTF-8"
	if ascii_eq_ci(l, "utf-16le") do return "UTF-16LE"
	if ascii_eq_ci(l, "utf-16be") do return "UTF-16BE"
	if ascii_eq_ci(l, "windows-1252") do return "windows-1252"
	if ascii_eq_ci(l, "x-user-defined") do return "x-user-defined"
	if ascii_eq_ci(l, "big5") do return "Big5"
	if ascii_eq_ci(l, "shift_jis") do return "Shift_JIS"

	return nil
}

norm_prescan_encoding :: proc(label: string) -> Maybe(string) {
	enc, ok := label_to_name(label).?
	if !ok do return nil

	if ascii_eq_ci(enc, "UTF-16LE") || ascii_eq_ci(enc, "UTF-16BE") do return "UTF-8"
	if ascii_eq_ci(enc, "x-user-defined") do return "windows-1252"
	return enc
}

get_bom_encoding :: proc(input: []byte) -> Maybe(string) {
	if len(input) >= 3 && input[0] == 0xEF && input[1] == 0xBB && input[2] == 0xBF do return "UTF-8"
	if len(input) >= 2 && input[0] == 0xFF && input[1] == 0xFE do return "UTF-16LE"
	if len(input) >= 2 && input[0] == 0xFE && input[1] == 0xFF do return "UTF-16BE"
	return nil
}

get_attr :: proc(input: []byte, i_: int, l: int) -> (Maybe(Attr), int) {
    i := i_
	for i < l {
		c := input[i]
		if is_html_space(c) || c == 0x2F {
			i += 1
			continue
		}
		if c == 0x3E do return nil, i
		break
	}

	if i >= l do return nil, i

	name_bytes := make([dynamic]u8, context.temp_allocator)
	value_bytes := make([dynamic]u8, context.temp_allocator)

	for i < l {
		c := input[i]

		if c == 0x3D && len(name_bytes) > 0 {
			i += 1
			break
		}

		if is_html_space(c) {
			i += 1
			for i < l {
				c = input[i]
				if is_html_space(c) {
					i += 1
					continue
				}
				if c != 0x3D do return Attr{string(name_bytes[:]), ""}, i
				i += 1
				break
			}
			break
		}

		if c == 0x2F || c == 0x3E do return Attr{string(name_bytes[:]), ""}, i

        if c >= 'A' && c <= 'Z' do append(&name_bytes, c + 0x20)
        else do append(&name_bytes, c)

		i += 1
	}

	for i < l && is_html_space(input[i]) do i += 1

	if i >= l do return Attr{string(name_bytes[:]), ""}, i

	c := input[i]
	if c == 0x22 || c == 0x27 {
		quote := c
		i += 1
		for i < l {
			c = input[i]
			if c == quote {
				i += 1
				break
			}

            append(&value_bytes, c)
			i += 1
		}
	} else if c == 0x3E {
		return Attr{string(name_bytes[:]), ""}, i
	} else {
		for i < l {
			c = input[i]
			if is_html_space(c) || c == 0x3E do break

            append(&value_bytes, c)
			i += 1
		}
	}

	return Attr{string(name_bytes[:]), string(value_bytes[:])}, i
}

extract_from_meta :: proc(str: string) -> Maybe(string) {
	position := 0

	for {
		index := -1
		for i := position; i <= len(str)-7; i += 1 {
			if (ascii_lower(str[i]) == 'c') &&
				(ascii_lower(str[i+1]) == 'h') &&
				(ascii_lower(str[i+2]) == 'a') &&
				(ascii_lower(str[i+3]) == 'r') &&
				(ascii_lower(str[i+4]) == 's') &&
				(ascii_lower(str[i+5]) == 'e') &&
				(ascii_lower(str[i+6]) == 't') {
				index = i
				break
			}
		}

		if index == -1 do return nil

		sub_position := index + 7

		for sub_position < len(str) && is_html_space(str[sub_position]) do sub_position += 1
		if sub_position >= len(str) || str[sub_position] != '=' {
			position = index + 7
			continue
		}

		sub_position += 1
		for sub_position < len(str) && is_html_space(str[sub_position]) do sub_position += 1

		position = sub_position
		break
	}

	if position >= len(str) do return nil

	if str[position] == '"' || str[position] == '\'' {
		quote := str[position]
		end_pos := position + 1
		for end_pos < len(str) && str[end_pos] != quote do end_pos += 1
		if end_pos < len(str) {
			label := str[position+1 : end_pos]
			return label_to_name(label)
		}
		return nil
	}

	end_pos := position
	for end_pos < len(str) {
		c := str[end_pos]
		if is_html_space(c) || c == ';' do break
		end_pos += 1
	}

	label := str[position:end_pos]
	return label_to_name(label)
}

is_utf16_family :: proc(enc: string) -> bool {
	return ascii_eq_ci(enc, "UTF-16LE") || ascii_eq_ci(enc, "UTF-16BE")
}

prescan :: proc(input: []byte) -> Maybe(string) {
	l := min(len(input), 1024)
	i := 0

	for i < l {
		c := input[i]
		if c != 0x3C { // '<'
			i += 1
			continue
		}

		if i + 1 >= l do break
		c1 := input[i+1]

		// <!-- comment -->
		if c1 == 0x21 && i + 3 < l && input[i+2] == 0x2D && input[i+3] == 0x2D {
			i += 4
			for i + 2 < l {
				if input[i] == 0x2D && input[i+1] == 0x2D && input[i+2] == 0x3E {
					i += 3
					break
				}
				i += 1
			}
			continue
		}

		// <?xml ... ?>
		if c1 == 0x3F {
			i += 2
			start := i
			for i + 1 < l {
				if input[i] == 0x3F && input[i+1] == 0x3E {
					decl := string(input[start:i])
					enc_res := extract_xml_decl_encoding(decl)
					if enc, ok := enc_res.?; ok do return norm_prescan_encoding(enc)
					i += 2
					break
				}
				i += 1
			}
			continue
		}

		// <meta ...>
		if (ascii_lower(c1) == 'm') && i + 4 < l &&
			(ascii_lower(input[i+2]) == 'e') &&
			(ascii_lower(input[i+3]) == 't') &&
			(ascii_lower(input[i+4]) == 'a') {

			i += 5

            got_pragma := false
			enc_from_charset_attr := false
			enc_from_content_attr := false
			charset := ""

			for {
				attr_res, next_i := get_attr(input, i, l)
				i = next_i

				attr, ok := attr_res.?
				if !ok do break

				switch attr.name {
				case "http-equiv": if ascii_eq_ci(attr.value, "content-type") do got_pragma = true
				case "content":
					if enc := extract_from_meta(attr.value); enc != nil {
						charset = enc.?
						enc_from_content_attr = true
					}
				case "charset":
					if enc := label_to_name(attr.value); enc != nil {
						charset = enc.?
						enc_from_charset_attr = true
					}
				}
			}

			if charset != "" {
				if enc_from_charset_attr do return norm_prescan_encoding(charset)
				if enc_from_content_attr && got_pragma do return norm_prescan_encoding(charset)
			}

			continue
		}

		i += 1
		for i < l && input[i] != 0x3E do i += 1
		if i < l && input[i] == 0x3E do i += 1
	}

	return nil
}

extract_xml_decl_encoding :: proc(str: string) -> Maybe(string) {
	i := 0
	for i + 7 < len(str) {
		if ascii_lower(str[i]) == 'e' &&
			ascii_lower(str[i+1]) == 'n' &&
			ascii_lower(str[i+2]) == 'c' &&
			ascii_lower(str[i+3]) == 'o' &&
			ascii_lower(str[i+4]) == 'd' &&
			ascii_lower(str[i+5]) == 'i' &&
			ascii_lower(str[i+6]) == 'n' &&
			ascii_lower(str[i+7]) == 'g' {

			j := i + 8
			for j < len(str) && is_html_space(str[j]) do j += 1
			if j >= len(str) || str[j] != '=' {
				i += 8
				continue
			}
			j += 1
			for j < len(str) && is_html_space(str[j]) do j += 1
			if j >= len(str) do return nil

			if str[j] == '"' || str[j] == '\'' {
				quote := str[j]
				j += 1
				start := j
				for j < len(str) && str[j] != quote do j += 1
				if j <= len(str) do return label_to_name(str[start:j])
				return nil
			}

			start := j
			for j < len(str) && !is_html_space(str[j]) && str[j] != '?' do j += 1
			return label_to_name(str[start:j])
		}
		i += 1
	}
	return nil
}

EncodingOptions :: struct {
	override_encoding: string,
	transport_encoding: string,
	parent_encoding: string,
	likely_encoding: string,
	default_encoding: string,
	same_origin_with_parent: bool,
}

encoding_sniff :: proc(input: []byte, opt: EncodingOptions) -> string {
	// BOM
	if enc := get_bom_encoding(input); enc != nil do return enc.?

	// user override
	if opt.override_encoding != "" do if enc := label_to_name(opt.override_encoding); enc != nil do return enc.?

	// transport layer
	if opt.transport_encoding != "" do if enc := label_to_name(opt.transport_encoding); enc != nil do return enc.?

	// prescan
	if enc := prescan(input); enc != nil do return enc.?

	// same-origin parent
	if opt.same_origin_with_parent && 
        opt.parent_encoding != "" && 
        !is_utf16_family(opt.parent_encoding) {
        if enc := label_to_name(opt.parent_encoding); enc != nil do return enc.?
    }

	// likely encoding
	if opt.likely_encoding != "" do if enc := label_to_name(opt.likely_encoding); enc != nil do return enc.?

	// default
	if opt.default_encoding != "" do if enc := label_to_name(opt.default_encoding); enc != nil do return enc.?

	return "windows-1252"
}
