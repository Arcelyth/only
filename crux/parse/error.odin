package parse

ParseErrorProc :: #type proc(err: ParseError, c: rune)

ParseError :: enum {
    SurrogateInInputStream,
    NoncharacterInInputStream,
    ControlCharacterInInputStream,
    UnexpectedNullCharacter,
}


