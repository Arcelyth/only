package crux

import "core:testing"
import "core:unicode/utf8"

@(test)
test_stream_basic_consume :: proc(t: ^testing.T) {
	raw := []rune{'a', 'b', 'c'}
	stream := new_input_stream(raw)
	defer destroy_input_stream(&stream)

	testing.expect_value(t, stream.next, 0)
	testing.expect_value(t, stream.current, nil)

	testing.expect_value(t, peek(&stream).?, 'a')
	testing.expect_value(t, consume(&stream).?, 'a')
	testing.expect_value(t, stream.current.?, 'a')
	testing.expect_value(t, stream.next, 1)

	testing.expect_value(t, consume(&stream).?, 'b')
	testing.expect_value(t, consume(&stream).?, 'c')

	testing.expect_value(t, peek(&stream), nil)
	testing.expect_value(t, consume(&stream), nil)
}

@(test)
test_document_write_and_string_conversion :: proc(t: ^testing.T) {
	raw := []rune{'<', 'g', '>', '<', '/', 'g', '>'}
	stream := new_input_stream(raw, script_created = true)
	defer destroy_input_stream(&stream)

	consume(&stream)
	consume(&stream)
	testing.expect_value(t, stream.next, 2)

	set_insertion_point(&stream)

	write(&stream, []rune{'x', 'y'})
	write(&stream, []rune{'z'})

	final_str := utf8.runes_to_string(stream.content[:])
	defer delete(final_str)

	testing.expect_value(t, final_str, "<gxyz></g>")

	testing.expect_value(t, peek(&stream).?, 'x')
	testing.expect_value(t, consume(&stream).?, 'x')
}

@(test)
test_script_created_explicit_eof :: proc(t: ^testing.T) {
	raw := []rune{'!'}
	stream := new_input_stream(raw, script_created = true)
	defer destroy_input_stream(&stream)

	testing.expect_value(t, consume(&stream).?, '!')

	testing.expect_value(t, peek(&stream), nil)

	close_document(&stream)

	testing.expect_value(t, peek(&stream).?, 0)
	testing.expect_value(t, consume(&stream).?, 0)
	testing.expect_value(t, stream.eof_consumed, true)
	testing.expect_value(t, peek(&stream), nil)
}

@(test)
test_stream_reconsume :: proc(t: ^testing.T) {
	raw := []rune{'h', 't', 'm', 'l'}
	stream := new_input_stream(raw)
	defer destroy_input_stream(&stream)

	consume(&stream)
	consume(&stream)
	testing.expect_value(t, stream.next, 2)

	reconsume(&stream)
	testing.expect_value(t, stream.next, 1)
	testing.expect_value(t, stream.current.?, 't')

	testing.expect_value(t, peek(&stream).?, 't')
}
