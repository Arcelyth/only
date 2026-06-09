package crux

import "core:strings"

ParseErrorProc :: proc(err: ParseError, c: rune)

ParseError :: enum {
    SurrogateInInputStream,
    NoncharacterInInputStream,
    ControlCharacterInInputStream
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
is_control_character :: proc(c: rune) -> bool {
	if c == 0 do return false
	if is_ascii_whitespace(c) do return false
	return (c >= 0x0001 && c <= 0x001F) || (c >= 0x007F && c <= 0x009F)
}

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
            if is_surrogate(c) {
                on_error(.SurrogateInInputStream, c)
            } else if is_noncharacter(c) {
                on_error(.NoncharacterInInputStream, c)
            } else if is_control_character(c) {
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

