// Implementation of encoding sniffing algorithm.
// https://html.spec.whatwg.org/multipage/parsing.html#encoding-sniffing-algorithm

package encoding

Attr :: struct {
	name:  string,
	value: string,
}

Confidence :: enum {
    Certain,
    Tentative
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

norm_prescan_encoding :: proc(label: string) -> Maybe(string) {
	enc, ok := label_to_name(label).?
	if !ok do return nil

	if ascii_eq_ci(enc, "UTF-16LE") || ascii_eq_ci(enc, "UTF-16BE") do return "UTF-8"
	if ascii_eq_ci(enc, "x-user-defined") do return "windows-1252"
	return enc
}

// https://encoding.spec.whatwg.org/#bom-sniff
get_bom_encoding :: proc(input: []byte) -> Maybe(string) {
	if len(input) >= 3 && input[0] == 0xEF && input[1] == 0xBB && input[2] == 0xBF do return "UTF-8"
	if len(input) >= 2 && input[0] == 0xFF && input[1] == 0xFE do return "UTF-16LE"
	if len(input) >= 2 && input[0] == 0xFE && input[1] == 0xFF do return "UTF-16BE"
	return nil
}

// https://html.spec.whatwg.org/multipage/parsing.html#concept-get-attributes-when-sniffing
get_attr :: proc(input: []byte, i_: int, l: int) -> (Maybe(Attr), int) {
    i := i_

    for i < l {
        c := input[i]
        if is_html_space(c) || c == 0x2F {
            i += 1 
            continue
        } 
        if c == 0x3E do return nil, i   // '>'
        break
    }
    if i >= l do return nil, i

    n_start := i
    n_end := -1
    for i < l {
        c := input[i]
        if c == 0x3D {  // '='
            n_end = i 
            i += 1
            break
        }
        if is_html_space(c) {
            n_end = i
            i += 1
            for i < l {
                c = input[i]
                if is_html_space(c) {
                    i += 1
                    continue
                }
                if c != 0x3D do return Attr{string(input[n_start:n_end]), ""}, i 
                i += 1
                break
            }
            break
        }
        // '/', '>'
        if c == 0x2F || c == 0x3E {
            n_end = i
            return Attr{string(input[n_start:n_end]), ""}, i
        }
        i += 1 
    }
    if n_end == -1 do n_end = i
    if n_end < n_start do n_end = n_start
    for i < l && is_html_space(input[i]) do i += 1
    if i >= l do return Attr{string(input[n_start:n_end]), ""}, i

    v_start := i
    v_end := -1

    c := input[i]
    // quote
    if c == 0x22 || c == 0x27 {
        quote := c
        i += 1
        v_start = i
        for i < l {
            if input[i] == quote {
                v_end = i
                i += 1
                break
            }
            i += 1
        }
        if v_end == -1 do v_end = i
    } else if c == 0x3E {   // '>'
        return Attr{string(input[n_start:n_end]), ""}, i
    } else {
        for i < l {
            c = input[i]
            if is_html_space(c) || c == 0x3E do break
            i += 1
        }
        v_end = i
    }

    return Attr{string(input[n_start:n_end]), string(input[v_start:v_end])}, i
}

// https://html.spec.whatwg.org/#extracting-character-encodings-from-meta-elements
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

encoding_sniff :: proc(input: []byte, opt: EncodingOptions) -> (string, Confidence) {
	// BOM
	if enc := get_bom_encoding(input); enc != nil do return enc.?, .Certain

	// user override
	if opt.override_encoding != "" do if enc := label_to_name(opt.override_encoding); enc != nil do return enc.?, .Certain

	// transport layer
	if opt.transport_encoding != "" do if enc := label_to_name(opt.transport_encoding); enc != nil do return enc.?, .Certain

	// prescan
	if enc := prescan(input); enc != nil do return enc.?, .Tentative

	// same-origin parent
	if opt.same_origin_with_parent && 
        opt.parent_encoding != "" && 
        !is_utf16_family(opt.parent_encoding) {
        if enc := label_to_name(opt.parent_encoding); enc != nil do return enc.?, .Tentative
    }

	// likely encoding
	if opt.likely_encoding != "" do if enc := label_to_name(opt.likely_encoding); enc != nil do return enc.?, .Tentative 

	// default
	if opt.default_encoding != "" do if enc := label_to_name(opt.default_encoding); enc != nil do return enc.?, .Tentative

	return "windows-1252", .Tentative
}

norm_label :: proc(label: string, allocator := context.temp_allocator) -> string {
	cleaned := trim_space(label)
	if len(cleaned) == 0 do return ""
	buf := make([]u8, len(cleaned), allocator)
	for i in 0..<len(cleaned) do buf[i] = ascii_lower(cleaned[i])
	return string(buf)
}

// https://encoding.spec.whatwg.org/#names-and-labels
label_to_name :: proc(label: string) -> Maybe(string) {
	l := norm_label(label)
	if len(l) == 0 do return nil

	switch l {
	// UTF-8
	case "unicode-1-1-utf-8", "unicode11utf8", "unicode20utf8", "utf-8", "utf8", "x-unicode20utf8":
		return "UTF-8"

	// Legacy single-byte encodings
	case "866", "cp866", "csibm866", "ibm866":
		return "IBM866"

	case "csisolatin2", "iso-8859-2", "iso-ir-101", "iso8859-2", "iso88592", "iso_8859-2", "iso_8859-2:1987", "l2", "latin2":
		return "ISO-8859-2"

	case "csisolatin3", "iso-8859-3", "iso-ir-109", "iso8859-3", "iso88593", "iso_8859-3", "iso_8859-3:1988", "l3", "latin3":
		return "ISO-8859-3"

	case "csisolatin4", "iso-8859-4", "iso-ir-110", "iso8859-4", "iso88594", "iso_8859-4", "iso_8859-4:1988", "l4", "latin4":
		return "ISO-8859-4"

	case "csisolatincyrillic", "cyrillic", "iso-8859-5", "iso-ir-144", "iso8859-5", "iso88595", "iso_8859-5", "iso_8859-5:1988":
		return "ISO-8859-5"

	case "arabic", "asmo-708", "csiso88596e", "csiso88596i", "csisolatinarabic", "ecma-114", "iso-8859-6", "iso-8859-6-e", "iso-8859-6-i", "iso-ir-127", "iso8859-6", "iso88596", "iso_8859-6", "iso_8859-6:1987":
		return "ISO-8859-6"

	case "csisolatingreek", "ecma-118", "elot_928", "greek", "greek8", "iso-8859-7", "iso-ir-126", "iso8859-7", "iso88597", "iso_8859-7", "iso_8859-7:1987", "sun_eu_greek":
		return "ISO-8859-7"

	case "csiso88598e", "csisolatinhebrew", "hebrew", "iso-8859-8", "iso-8859-8-e", "iso-ir-138", "iso8859-8", "iso88598", "iso_8859-8", "iso_8859-8:1988", "visual":
		return "ISO-8859-8"

	case "csiso88598i", "iso-8859-8-i", "logical":
		return "ISO-8859-8-I"

	case "csisolatin6", "iso-8859-10", "iso-ir-157", "iso8859-10", "iso885910", "l6", "latin6":
		return "ISO-8859-10"

	case "iso-8859-13", "iso8859-13", "iso885913":
		return "ISO-8859-13"

	case "iso-8859-14", "iso8859-14", "iso885914":
		return "ISO-8859-14"

	case "csisolatin9", "iso-8859-15", "iso8859-15", "iso885915", "iso_8859-15", "l9":
		return "ISO-8859-15"

	case "iso-8859-16":
		return "ISO-8859-16"

	case "cskoi8r", "koi", "koi8", "koi8-r", "koi8_r":
		return "KOI8-R"

	case "koi8-ru", "koi8-u":
		return "KOI8-U"

	case "csmacintosh", "mac", "macintosh", "x-mac-roman":
		return "macintosh"

	case "dos-874", "iso-8859-11", "iso8859-11", "iso885911", "tis-620", "windows-874":
		return "windows-874"

	case "cp1250", "windows-1250", "x-cp1250":
		return "windows-1250"

	case "cp1251", "windows-1251", "x-cp1251":
		return "windows-1251"

	case "ansi_x3.4-1968", "ascii", "cp1252", "cp819", "csisolatin1", "ibm819", "iso-8859-1", "iso-ir-100", "iso8859-1", "iso88591", "iso_8859-1", "iso_8859-1:1987", "l1", "latin1", "us-ascii", "windows-1252", "x-cp1252":
		return "windows-1252"

	case "cp1253", "windows-1253", "x-cp1253":
		return "windows-1253"

	case "cp1254", "csisolatin5", "iso-8859-9", "iso-ir-148", "iso8859-9", "iso88599", "iso_8859-9", "iso_8859-9:1989", "l5", "latin5", "windows-1254", "x-cp1254":
		return "windows-1254"

	case "cp1255", "windows-1255", "x-cp1255":
		return "windows-1255"

	case "cp1256", "windows-1256", "x-cp1256":
		return "windows-1256"

	case "cp1257", "windows-1257", "x-cp1257":
		return "windows-1257"

	case "cp1258", "windows-1258", "x-cp1258":
		return "windows-1258"

	case "x-mac-cyrillic", "x-mac-ukrainian":
		return "x-mac-cyrillic"

	// Legacy multi-byte Chinese (simplified)
	case "chinese", "csgb2312", "csiso58gb231280", "gb2312", "gb_2312", "gb_2312-80", "gbk", "iso-ir-58", "x-gbk":
		return "GBK"

	case "gb18030":
		return "gb18030"

	// Legacy multi-byte Chinese (traditional)
	case "big5", "big5-hkscs", "cn-big5", "csbig5", "x-x-big5":
		return "Big5"

	// Legacy multi-byte Japanese
	case "cseucpkdfmtjapanese", "euc-jp", "x-euc-jp":
		return "EUC-JP"

	case "csiso2022jp", "iso-2022-jp":
		return "ISO-2022-JP"

	case "csshiftjis", "ms932", "ms_kanji", "shift-jis", "shift_jis", "sjis", "windows-31j", "x-sjis":
		return "Shift_JIS"

	// Legacy multi-byte Korean
	case "cseuckr", "csksc56011987", "euc-kr", "iso-ir-149", "korean", "ks_c_5601-1987", "ks_c_5601-1989", "ksc5601", "ksc_5601", "windows-949":
		return "EUC-KR"

	// Legacy miscellaneous
	case "csiso2022kr", "hz-gb-2312", "iso-2022-cn", "iso-2022-cn-ext", "iso-2022-kr", "replacement":
		return "replacement"

	case "unicodefffe", "utf-16be":
		return "UTF-16BE"

	case "csunicode", "iso-10646-ucs-2", "ucs-2", "unicode", "unicodefeff", "utf-16", "utf-16le":
		return "UTF-16LE"

	case "x-user-defined":
		return "x-user-defined"
	}

	return nil
}
