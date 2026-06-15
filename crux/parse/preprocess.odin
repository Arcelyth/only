package parse

import "../utils"
import "core:strings"

// https://infra.spec.whatwg.org/#normalize-newlines
norm_newline :: proc(str: string) -> string {
	s1, _ := strings.replace_all(str, "\u000D\u000A", "\u000A")
	s2, _ := strings.replace_all(s1, "\u000D", "\u000A")
	delete(s1)
	return s2
}

// https://html.spec.whatwg.org/multipage/parsing.html#preprocessing-the-input-stream
preprocess :: proc(input: ^InputStream, on_error: ParseErrorProc = nil) {
	out := make([dynamic]rune, 0, len(input.content), input.content.allocator)

	i := 0
	for i < len(input.content) {
		c := input.content[i]

		// CRLF -> LF
		if c == '\r' {
			append(&out, '\n')
			if i + 1 < len(input.content) && input.content[i + 1] == '\n' do i += 2
			else do i += 1
			continue
		}

		if on_error != nil {
			if utils.is_surrogate(c) {
				on_error(.SurrogateInInputStream, c)
			} else if utils.is_noncharacter(c) {
				on_error(.NoncharacterInInputStream, c)
			} else if utils.is_control(c) {
				on_error(.ControlCharacterInInputStream, c)
			}
		}

		append(&out, c)
		i += 1
	}

	delete(input.content)
	input.content = out
	input.next = 0
	input.current = nil
}
