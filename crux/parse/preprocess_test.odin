package parse

import "core:testing"

g_test_errors: [dynamic]ParseError
g_test_error_runes: [dynamic]rune

mock_on_error :: proc(err: ParseError, c: rune) {
	append(&g_test_errors, err)
	append(&g_test_error_runes, c)
}

reset_test_errors :: proc() {
	clear(&g_test_errors)
	clear(&g_test_error_runes)
}

@(test)
test_norm_newline :: proc(t: ^testing.T) {
	input := "Line1\r\nLine2\rLine3\nLine4\r\r\n"
	expected := "Line1\nLine2\nLine3\nLine4\n\n"
	
	result := norm_newline(input)
	defer delete(result)
	testing.expect_value(t, result, expected)
}

@(test)
test_preprocess_stream_and_errors :: proc(t: ^testing.T) {
	raw := []rune{'a', '\r', '\n', 'b', '\r', 'c', 0xD800, 0xFFFF, 0x01, 'd'}
	stream := new_input_stream(raw)
	defer destroy_input_stream(&stream)

	if g_test_errors == nil {
		g_test_errors = make([dynamic]ParseError)
		g_test_error_runes = make([dynamic]rune)
	}
	reset_test_errors()
	defer delete(g_test_errors)
	defer delete(g_test_error_runes)

	preprocess(&stream, mock_on_error)

	expected_content := []rune{'a', '\n', 'b', '\n', 'c', 0xD800, 0xFFFF, 0x01, 'd'}
	testing.expect_value(t, len(stream.content), len(expected_content))
	
	for i in 0..<len(expected_content) {
		testing.expect_value(t, stream.content[i], expected_content[i])
	}

	testing.expect_value(t, stream.next, 0)
	testing.expect_value(t, stream.current, nil)

	testing.expect_value(t, len(g_test_errors), 3)

	if len(g_test_errors) == 3 {
		testing.expect_value(t, g_test_errors[0], ParseError.SurrogateInInputStream)
		testing.expect_value(t, g_test_error_runes[0], 0xD800)

		testing.expect_value(t, g_test_errors[1], ParseError.NoncharacterInInputStream)
		testing.expect_value(t, g_test_error_runes[1], 0xFFFF)

		testing.expect_value(t, g_test_errors[2], ParseError.ControlCharacterInInputStream)
		testing.expect_value(t, g_test_error_runes[2], 0x01)
	}
}
