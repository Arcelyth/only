package parse

DOCTYPE_Token :: struct {
    name: Maybe(string),
    // public identifier    
    public_ident: Maybe(string),
    // system identifier
    sys_ident: Maybe(string),
    force_quirks: bool,
}

Attribute :: struct {
    name: string,
    value: string,
}

Start_Token :: struct {
    tag_name: string,
    self_closing: bool,
    attrs: []Attribute,
}

End_Token :: struct {
    tag_name: string,
    self_closing: bool,
    attrs: []Attribute,
}

Comment_Token :: struct {
    data: string,
}

Character_Token :: struct {
    data: rune,
}

EOF_Token :: struct {}

Token :: union {
    DOCTYPE_Token,
    Start_Token,
    End_Token,
    Comment_Token,
    Character_Token,
    EOF_Token
}

TokenizerState :: enum {
    Data,
    RCDATA,
    RAWTEXT,
    ScriptData,
    PLAINTEXT,

    TagOpen,
    EndTagOpen,
    TagName,

    RCDATALessThanSign,
    RCDATAEndTagOpen,
    RCDATAEndTagName,

    RAWTEXTLessThanSign,
    RAWTEXTEndTagOpen,
    RAWTEXTEndTagName,

    ScriptDataLessThanSign,
    ScriptDataEndTagOpen,
    ScriptDataEndTagName,
    ScriptDataEscapeStart,
    ScriptDataEscapeStartDash,
    ScriptDataEscaped,
    ScriptDataEscapedDash,
    ScriptDataEscapedDashDash,
    ScriptDataEscapedLessThanSign,
    ScriptDataEscapedEndTagOpen,
    ScriptDataEscapedEndTagName,
    ScriptDataDoubleEscapeStart,
    ScriptDataDoubleEscaped,
    ScriptDataDoubleEscapedDash,
    ScriptDataDoubleEscapedDashDash,
    ScriptDataDoubleEscapedLessThanSign,
    ScriptDataDoubleEscapeEnd,

    BeforeAttributeName,
    AttributeName,
    AfterAttributeName,
    BeforeAttributeValue,
    AttributeValueDoubleQuoted,
    AttributeValueSingleQuoted,
    AttributeValueUnquoted,
    AfterAttributeValueQuoted,
    SelfClosingStartTag,

    BogusComment,
    MarkupDeclarationOpen,

    CommentStart,
    CommentStartDash,
    Comment,
    CommentLessThanSign,
    CommentLessThanSignBang,
    CommentLessThanSignBangDash,
    CommentLessThanSignBangDashDash,
    CommentEndDash,
    CommentEnd,
    CommentEndBang,

    DOCTYPE,
    BeforeDOCTYPEName,
    DOCTYPEName,
    AfterDOCTYPEName,
    AfterDOCTYPEPublicKeyword,
    BeforeDOCTYPEPublicIdentifier,
    DOCTYPEPublicIdentifierDoubleQuoted,
    DOCTYPEPublicIdentifierSingleQuoted,
    AfterDOCTYPEPublicIdentifier,
    BetweenDOCTYPEPublicAndSystemIdentifiers,
    AfterDOCTYPESystemKeyword,
    BeforeDOCTYPESystemIdentifier,
    DOCTYPESystemIdentifierDoubleQuoted,
    DOCTYPESystemIdentifierSingleQuoted,
    AfterDOCTYPESystemIdentifier,
    BogusDOCTYPE,

    CDATASection,
    CDATASectionBracket,
    CDATASectionEnd,

    CharacterReference,
    NamedCharacterReference,
    AmbiguousAmpersand,
    NumericCharacterReference,
    HexadecimalCharacterReferenceStart,
    DecimalCharacterReferenceStart,
    HexadecimalCharacterReference,
    DecimalCharacterReference,
    NumericCharacterReferenceEnd,
}

Tokenizer :: struct {
	input: ^InputStream,
    state: TokenizerState,
	return_state: TokenizerState,
    pause_flag: bool,
	on_error: ParseErrorProc,
}

new_tokenizer :: proc(input: ^InputStream, on_error: ParseErrorProc = nil) -> Tokenizer {
	return Tokenizer{ 
        input = input, 
        state = .Data, 
        return_state = .Data, 
        pause_flag = false, 
        on_error = on_error,
    }
}

emit :: proc(tok: Token) {
    handle_token(tok)
}

emit_char :: proc(c: rune) {
    emit(Character_Token{c})
}

emit_comment :: proc(str: string) {
    emit(Comment_Token{str})
}

emit_start :: proc(tag_name: string, self_closing: bool, attrs: []Attribute) {
    emit(Start_Token{tag_name, self_closing, attrs})
}

emit_end :: proc(tag_name: string, self_closing: bool, attrs: []Attribute) {
    emit(End_Token{tag_name, self_closing, attrs})
}

emit_eof :: proc() {
    emit(EOF_Token{})
}

emit_doctype :: proc(name, public_ident, sys_ident: Maybe(string), force_quirks: bool) {
    emit(DOCTYPE_Token{name, public_ident, sys_ident, force_quirks})
}

step_tokenizer :: proc(t: ^Tokenizer) {
	next_char := consume(t.input)
	
	is_eof := next_char == nil
	c := next_char.? if !is_eof else 0

    #partial switch t.state {

    // https://html.spec.whatwg.org/multipage/parsing.html#data-state
	case .Data:
		if is_eof {
            emit_eof()
		}

		switch c {
		case '&':
			t.return_state = .Data
			t.state = .CharacterReference
		case '<':
			t.state = .TagOpen
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char(c)
		case:
			emit_char(c)
		}

    // https://html.spec.whatwg.org/multipage/parsing.html#rcdata-state
	case .RCDATA:
		if is_eof {
            emit_eof()
		}

		switch c {
		case '&':
			t.return_state = .RCDATA
			t.state = .CharacterReference
		case '<':
			t.state = .RCDATALessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char('\uFFFD')
		case:
			emit_char(c)
		}
	}
}

tokenize :: proc(t: ^Tokenizer) {
	for {
        step_tokenizer(t)
		if t.pause_flag {
			return
		}
	}
}
