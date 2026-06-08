package only

import "core:testing"
import "core:fmt"

expect_sniff :: proc(t: ^testing.T, input: string, opt: EncodingOptions, expected: string, loc := #caller_location) {
	res := encoding_sniff(transmute([]byte)input, opt)
	testing.expect_value(t, res, expected, loc)
}

@(test)
test_bom_sniffing :: proc(t: ^testing.T) {
	opt := EncodingOptions{}

	expect_sniff(t, "\xEF\xBB\xBF<html></html>", opt, "UTF-8")
	expect_sniff(t, "\xFF\xFE<h>", opt, "UTF-16LE")
	expect_sniff(t, "\xFE\xFF<h>", opt, "UTF-16BE")
	expect_sniff(t, "<html></html>", opt, "windows-1252")
}

@(test)
test_label_normalization :: proc(t: ^testing.T) {
	testing.expect_value(t, label_to_name("  uTf8   ").?, "UTF-8")
	testing.expect_value(t, label_to_name("\nGBK\t").?, "GBK")
	testing.expect_value(t, label_to_name("shift_jis").?, "Shift_JIS")
	testing.expect_value(t, label_to_name("unknown-encoding"), nil)

	testing.expect_value(t, norm_prescan_encoding("utf-16le").?, "UTF-8")
	testing.expect_value(t, norm_prescan_encoding("x-user-defined").?, "windows-1252")
}

@(test)
test_meta_prescan :: proc(t: ^testing.T) {
	opt := EncodingOptions{}

	expect_sniff(t, `<meta charset="gbk">`, opt, "GBK")
	expect_sniff(t, `<meta charset=big5>`, opt, "Big5")

	expect_sniff(t, `<meta http-equiv="Content-Type" content="text/html; charset=utf-8">`, opt, "UTF-8")
	
	expect_sniff(t, `<meta content="charset=gb18030" http-equiv="content-type">`, opt, "gb18030")

	expect_sniff(t, `<meta content="text/html; charset=gbk">`, opt, "windows-1252")

	dirty_html := `<meta charset="utf8">`
	expect_sniff(t, dirty_html, opt, "UTF-8")
}

@(test)
test_xml_declaration :: proc(t: ^testing.T) {
	opt := EncodingOptions{}

	expect_sniff(t, `<?xml version="1.0" encoding="big5"?>`, opt, "Big5")
	expect_sniff(t, `<?xml encoding='shift_jis'?>`, opt, "Shift_JIS")
}	

@(test)
test_priority_cascade :: proc(t: ^testing.T) {
	payload := "\xEF\xBB\xBF<meta charset='gbk'>"
	opt_a := EncodingOptions{
		override_encoding  = "big5",
		transport_encoding = "shift_jis",
	}
	testing.expect_value(t, encoding_sniff(transmute([]byte)payload, opt_a), "UTF-8")

	no_bom_payload := "<meta charset='gbk'>"
	opt_b := EncodingOptions{
		override_encoding  = "big5",
		transport_encoding = "shift_jis",
	}
	testing.expect_value(t, encoding_sniff(transmute([]byte)no_bom_payload, opt_b), "Big5")

	opt_c := EncodingOptions{
		transport_encoding = "shift_jis",
	}
	testing.expect_value(t, encoding_sniff(transmute([]byte)no_bom_payload, opt_c), "Shift_JIS")

	opt_d := EncodingOptions{}
	testing.expect_value(t, encoding_sniff(transmute([]byte)no_bom_payload, opt_d), "GBK")

	clean_payload := "<html>No Tags</html>"
	opt_e := EncodingOptions{
		same_origin_with_parent = true,
		parent_encoding         = "big5",
	}
	testing.expect_value(t, encoding_sniff(transmute([]byte)clean_payload, opt_e), "Big5")
}

@(test)
test_get_attr :: proc(t: ^testing.T) {
    input := `<meta charset="gbk">`
    attr, i := get_attr(transmute([]byte)input, 6, len(input))
    a, ok := attr.?
    testing.expect(t, ok)
    testing.expect_value(t, a.name, "charset")
    testing.expect_value(t, a.value, "gbk")
    testing.expect_value(t, i, 19)
}

@(test)
test_get_attr_unquoted :: proc(t: ^testing.T) {
    input := `charset=gbk>`
    attr, i := get_attr(transmute([]byte)input, 0, len(input))
    a, ok := attr.?
    testing.expect(t, ok)
    testing.expect_value(t, a.name, "charset")
    testing.expect_value(t, a.value, "gbk")
    testing.expect_value(t, i, 11)
}

@(test)
test_get_attr_no_value :: proc(t: ^testing.T) {
    input := `charset >`
    attr, i := get_attr(transmute([]byte)input, 0, len(input))
    a, ok := attr.?
    testing.expect(t, ok)
    testing.expect_value(t, a.name, "charset")
    testing.expect_value(t, a.value, "")
    testing.expect_value(t, i, 8)
}
