package crux

InputStream :: struct {
    content: [dynamic]rune,
    // current input character
    current: Maybe(rune),
    // next input character index
    next: int,
    insertion_point: Maybe(int),
    script_created: bool,
    // document.close() inserted EOF
    explicit_eof_pending: bool,
    eof_consumed: bool,
}

new_input_stream :: proc(
	content_slice: []rune,
	script_created := false,
	allocator := context.allocator,
) -> InputStream {
	content_dyn := make([dynamic]rune, 0, len(content_slice), allocator)
	append(&content_dyn, ..content_slice)

	return InputStream{
		content = content_dyn,
		current = nil,
		next = 0,
		insertion_point = nil,
		script_created = script_created,
		explicit_eof_pending = false,
		eof_consumed = false,
	}
}

destroy_input_stream :: proc(input: ^InputStream) {
	delete(input.content)
}

peek :: proc(input: ^InputStream) -> Maybe(rune) {
    if input.next < len(input.content) do return input.content[input.next]

    if input.script_created && input.explicit_eof_pending && !input.eof_consumed do return 0

    return nil
}

consume :: proc(input: ^InputStream) -> Maybe(rune) {
    if input.next < len(input.content) {
        c := input.content[input.next]
        input.current = c
        input.next += 1
        return c
    }

    if input.script_created && input.explicit_eof_pending && !input.eof_consumed {
        input.eof_consumed = true
        input.current = 0
        return 0
    }

    input.current = nil
    return nil
}

reconsume :: proc(input: ^InputStream) {
	if input.script_created && input.eof_consumed do return
	if input.next >= len(input.content) && !input.script_created do return

	if input.next > 0 do input.next -= 1

	if input.next < len(input.content) do input.current = input.content[input.next]
	else do input.current = nil
}

set_insertion_point :: proc(input: ^InputStream) {
    input.insertion_point = input.next
}

clear_insertion_point :: proc(input: ^InputStream) {
    input.insertion_point = nil
}

// document.write()
write :: proc(input: ^InputStream, data: []rune) {
	pos, ok := input.insertion_point.?
	if !ok do return

	before := input.content[:pos]
	after := input.content[pos:]

	new_content := make([dynamic]rune, 0, len(before) + len(data) + len(after), input.content.allocator)

	append(&new_content, ..before)
	append(&new_content, ..data)
	append(&new_content, ..after)

	delete(input.content)
	input.content = new_content
	input.insertion_point = pos + len(data)

    if pos < input.next do input.next += len(data)
}

// document.close()
close_document :: proc(input: ^InputStream) {
    if input.script_created do input.explicit_eof_pending = true
}


