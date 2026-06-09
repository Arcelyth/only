package parse

import "core:strings"
import "../utils"

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
    current_token: Token, 
    tag_name_builder: strings.Builder, 
    temp_buffer: strings.Builder,
    last_start_tag_name: string,
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

// ----- emit
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

emit_temp_buffer :: proc(t: ^Tokenizer) {
	buf_str := strings.to_string(t.temp_buffer)
	for r in buf_str {
		emit_char(r)
	}
}

emit_current_tag :: proc(t: ^Tokenizer) {
	final_str := strings.to_string(t.tag_name_builder)

	#partial switch &tok in t.current_token {
	case Start_Token:
		tok.tag_name = final_str
		t.last_start_tag_name = final_str
		emit(tok)
	case End_Token:
		tok.tag_name = final_str
		emit(tok)
	case Comment_Token:
		tok.data = final_str
		emit(tok)
	}
}

// ----- create
create_start_tag :: proc(t: ^Tokenizer, name: string) {
	strings.builder_reset(&t.tag_name_builder)
	strings.write_string(&t.tag_name_builder, name)
	t.current_token = Start_Token{}
}

create_end_tag :: proc(t: ^Tokenizer, name: string) {
	strings.builder_reset(&t.tag_name_builder)
	strings.write_string(&t.tag_name_builder, name)
	t.current_token = End_Token{}
}

create_comment :: proc(t: ^Tokenizer, data: string) {
	strings.builder_reset(&t.tag_name_builder)
	strings.write_string(&t.tag_name_builder, data)
	t.current_token = Comment_Token{}
}

append_to_tag_name :: proc(t: ^Tokenizer, c: rune) {
	strings.write_rune(&t.tag_name_builder, c)
}

clear_temp_buffer :: proc(t: ^Tokenizer) {
	strings.builder_reset(&t.temp_buffer)
}

append_to_temp_buffer :: proc(t: ^Tokenizer, c: rune) {
	strings.write_rune(&t.temp_buffer, c)
}

is_appropriate_end_tag :: proc(t: ^Tokenizer) -> bool {
	#partial switch tok in t.current_token {
	case End_Token:
		current_name := strings.to_string(t.tag_name_builder)
		return current_name == t.last_start_tag_name
	case:
		return false
	}
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
            return
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
			return
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
    // https://html.spec.whatwg.org/multipage/parsing.html#rawtext-state
	case .RAWTEXT:
		if is_eof {
			emit_eof()
			return
		}
		switch c {
		case '<':
			t.state = .RAWTEXTLessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char('\uFFFD')
		case:
			emit_char(c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-state
	case .ScriptData:
		if is_eof {
			emit_eof()
			return
		}
		switch c {
		case '<':
			t.state = .ScriptDataLessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char('\uFFFD')
		case:
			emit_char(c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#plaintext-state
	case .PLAINTEXT:
		if is_eof {
			emit_eof()
			return
		}
		switch c {
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char('\uFFFD')
		case:
			emit_char(c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#tag-open-state
	case .TagOpen:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofBeforeTagName, c)
			emit_char('<')
			emit_eof()
			return
		}
		switch c {
		case '!':
			t.state = .MarkupDeclarationOpen
		case '/':
			t.state = .EndTagOpen
		case '?':
			if t.on_error != nil do t.on_error(.UnexpectedQuestionMarkInsteadOfTagName, c)
			create_comment(t, "")
			t.state = .BogusComment
			reconsume(t.input)
		case:
			if utils.is_ascii_alpha(c) {
				create_start_tag(t, "")
				t.state = .TagName
				reconsume(t.input)
			} else {
				if t.on_error != nil do t.on_error(.InvalidFirstCharacterOfTagName, c)
				emit_char('<')
				t.state = .Data
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#end-tag-open-state
	case .EndTagOpen:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofBeforeTagName, c)
			emit_char('<')
			emit_char('/')
			emit_eof()
			return
		}
		switch c {
		case '>':
			if t.on_error != nil do t.on_error(.MissingEndTagName, c)
			t.state = .Data
		case:
			if utils.is_ascii_alpha(c) {
				create_end_tag(t, "")
				t.state = .TagName
				reconsume(t.input)
			} else {
				if t.on_error != nil do t.on_error(.InvalidFirstCharacterOfTagName, c)
				create_comment(t, "")
				t.state = .BogusComment
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#tag-name-state
	case .TagName:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInTag, c)
			emit_eof()
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			t.state = .BeforeAttributeName
		case '/':
			t.state = .SelfClosingStartTag
		case '>':
			t.state = .Data
			emit_current_tag(t)
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_tag_name(t, '\uFFFD')
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_tag_name(t, c + 0x0020)
			} else {
				append_to_tag_name(t, c)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rcdata-less-than-sign-state
	case .RCDATALessThanSign:
		if is_eof {
			emit_char('<')
			t.state = .RCDATA
			reconsume(t.input)
			return
		}
		switch c {
		case '/':
			clear_temp_buffer(t)
			t.state = .RCDATAEndTagOpen
		case:
			emit_char('<')
			t.state = .RCDATA
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rcdata-end-tag-open-state
	case .RCDATAEndTagOpen:
		if is_eof {
			emit_char('<')
			emit_char('/')
			t.state = .RCDATA
			reconsume(t.input)
			return
		}
		if utils.is_ascii_alpha(c) {
			create_end_tag(t, "")
			t.state = .RCDATAEndTagName
			reconsume(t.input)
		} else {
			emit_char('<')
			emit_char('/')
			t.state = .RCDATA
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rcdata-end-tag-name-state
	case .RCDATAEndTagName:
		if is_eof {
			emit_char('<')
			emit_char('/')
			emit_temp_buffer(t)
			t.state = .RCDATA
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			if is_appropriate_end_tag(t) {
				t.state = .BeforeAttributeName
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .RCDATA
				reconsume(t.input)
			}
		case '/':
			if is_appropriate_end_tag(t) {
				t.state = .SelfClosingStartTag
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .RCDATA
				reconsume(t.input)
			}
		case '>':
			if is_appropriate_end_tag(t) {
				t.state = .Data
				emit_current_tag(t)
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .RCDATA
				reconsume(t.input)
			}
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_tag_name(t, c + 0x0020)
				append_to_temp_buffer(t, c)
			} else if utils.is_ascii_lower_alpha(c) {
				append_to_tag_name(t, c)
				append_to_temp_buffer(t, c)
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .RCDATA
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rawtext-less-than-sign-state
	case .RAWTEXTLessThanSign:
		if is_eof {
			emit_char('<')
			t.state = .RAWTEXT
			reconsume(t.input)
			return
		}
		switch c {
		case '/':
			clear_temp_buffer(t)
			t.state = .RAWTEXTEndTagOpen
		case:
			emit_char('<')
			t.state = .RAWTEXT
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rawtext-end-tag-open-state
	case .RAWTEXTEndTagOpen:
		if is_eof {
			emit_char('<')
			emit_char('/')
			t.state = .RAWTEXT
			reconsume(t.input)
			return
		}
		if utils.is_ascii_alpha(c) {
			create_end_tag(t, "")
			t.state = .RAWTEXTEndTagName
			reconsume(t.input)
		} else {
			emit_char('<')
			emit_char('/')
			t.state = .RAWTEXT
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rawtext-end-tag-name-state
	case .RAWTEXTEndTagName:
		if is_eof {
			emit_char('<')
			emit_char('/')
			emit_temp_buffer(t)
			t.state = .RAWTEXT
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			if is_appropriate_end_tag(t) {
				t.state = .BeforeAttributeName
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .RAWTEXT
				reconsume(t.input)
			}
		case '/':
			if is_appropriate_end_tag(t) {
				t.state = .SelfClosingStartTag
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .RAWTEXT
				reconsume(t.input)
			}
		case '>':
			if is_appropriate_end_tag(t) {
				t.state = .Data
				emit_current_tag(t)
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .RAWTEXT
				reconsume(t.input)
			}
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_tag_name(t, c + 0x0020)
				append_to_temp_buffer(t, c)
			} else if utils.is_ascii_lower_alpha(c) {
				append_to_tag_name(t, c)
				append_to_temp_buffer(t, c)
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .RAWTEXT
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-less-than-sign-state
	case .ScriptDataLessThanSign:
		if is_eof {
			emit_char('<')
			t.state = .ScriptData
			reconsume(t.input)
			return
		}
		switch c {
		case '/':
			clear_temp_buffer(t)
			t.state = .ScriptDataEndTagOpen
		case '!':
			t.state = .ScriptDataEscapeStart
			emit_char('<')
			emit_char('!')
		case:
			emit_char('<')
			t.state = .ScriptData
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-end-tag-open-state
	case .ScriptDataEndTagOpen:
		if is_eof {
			emit_char('<')
			emit_char('/')
			t.state = .ScriptData
			reconsume(t.input)
			return
		}
		if utils.is_ascii_alpha(c) {
			create_end_tag(t, "")
			t.state = .ScriptDataEndTagName
			reconsume(t.input)
		} else {
			emit_char('<')
			emit_char('/')
			t.state = .ScriptData
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-end-tag-name-state
	case .ScriptDataEndTagName:
		if is_eof {
			emit_char('<')
			emit_char('/')
			emit_temp_buffer(t)
			t.state = .ScriptData
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			if is_appropriate_end_tag(t) {
				t.state = .BeforeAttributeName
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .ScriptData
				reconsume(t.input)
			}
		case '/':
			if is_appropriate_end_tag(t) {
				t.state = .SelfClosingStartTag
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .ScriptData
				reconsume(t.input)
			}
		case '>':
			if is_appropriate_end_tag(t) {
				t.state = .Data
				emit_current_tag(t)
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .ScriptData
				reconsume(t.input)
			}
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_tag_name(t, c + 0x0020)
				append_to_temp_buffer(t, c)
			} else if utils.is_ascii_lower_alpha(c) {
				append_to_tag_name(t, c)
				append_to_temp_buffer(t, c)
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .ScriptData
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escape-start-state
	case .ScriptDataEscapeStart:
		if is_eof {
			t.state = .ScriptData
			reconsume(t.input)
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataEscapeStartDash
			emit_char('-')
		case:
			t.state = .ScriptData
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escape-start-dash-state
	case .ScriptDataEscapeStartDash:
		if is_eof {
			t.state = .ScriptData
			reconsume(t.input)
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataEscapedDashDash
			emit_char('-')
		case:
			t.state = .ScriptData
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-state
	case .ScriptDataEscaped:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof()
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataEscapedDash
			emit_char('-')
		case '<':
			t.state = .ScriptDataEscapedLessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char('\uFFFD')
		case:
			emit_char(c)
		}
        
    // https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-dash-state
	case .ScriptDataEscapedDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof()
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataEscapedDashDash
			emit_char('-')
		case '<':
			t.state = .ScriptDataEscapedLessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			t.state = .ScriptDataEscaped
			emit_char('\uFFFD')
		case:
			t.state = .ScriptDataEscaped
			emit_char(c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-dash-dash-state
	case .ScriptDataEscapedDashDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof()
			return
		}
		switch c {
		case '-':
			emit_char('-')
		case '<':
			t.state = .ScriptDataEscapedLessThanSign
		case '>':
			t.state = .ScriptData
			emit_char('>')
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			t.state = .ScriptDataEscaped
			emit_char('\uFFFD')
		case:
			t.state = .ScriptDataEscaped
			emit_char(c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-less-than-sign-state
	case .ScriptDataEscapedLessThanSign:
		if is_eof {
			emit_char('<')
			t.state = .ScriptDataEscaped
			reconsume(t.input)
			return
		}
		switch c {
		case '/':
			clear_temp_buffer(t)
			t.state = .ScriptDataEscapedEndTagOpen
		case:
			if utils.is_ascii_alpha(c) {
				clear_temp_buffer(t)
				emit_char('<')
				reconsume(t.input)
				t.state = .ScriptDataDoubleEscapeStart
			} else {
				emit_char('<')
				reconsume(t.input)
				t.state = .ScriptDataEscaped
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-end-tag-open-state
	case .ScriptDataEscapedEndTagOpen:
		if is_eof {
			emit_char('<')
			emit_char('/')
			t.state = .ScriptDataEscaped
			reconsume(t.input)
			return
		}
		if utils.is_ascii_alpha(c) {
			create_end_tag(t, "")
			reconsume(t.input)
			t.state = .ScriptDataEscapedEndTagName
		} else {
			emit_char('<')
			emit_char('/')
			reconsume(t.input)
			t.state = .ScriptDataEscaped
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-end-tag-name-state
	case .ScriptDataEscapedEndTagName:
		if is_eof {
			emit_char('<')
			emit_char('/')
			emit_temp_buffer(t)
			t.state = .ScriptDataEscaped
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			if is_appropriate_end_tag(t) {
				t.state = .BeforeAttributeName
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .ScriptDataEscaped
				reconsume(t.input)
			}
		case '/':
			if is_appropriate_end_tag(t) {
				t.state = .SelfClosingStartTag
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .ScriptDataEscaped
				reconsume(t.input)
			}
		case '>':
			if is_appropriate_end_tag(t) {
				t.state = .Data
				emit_current_tag(t)
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .ScriptDataEscaped
				reconsume(t.input)
			}
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_tag_name(t, c + 0x0020)
				append_to_temp_buffer(t, c)
			} else if utils.is_ascii_lower_alpha(c) {
				append_to_tag_name(t, c)
				append_to_temp_buffer(t, c)
			} else {
				emit_char('<')
				emit_char('/')
				emit_temp_buffer(t)
				t.state = .ScriptDataEscaped
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escape-start-state
	case .ScriptDataDoubleEscapeStart:
		if is_eof {
			t.state = .ScriptDataEscaped
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ', '/', '>':
			if strings.to_string(t.temp_buffer) == "script" {
				t.state = .ScriptDataDoubleEscaped
			} else {
				t.state = .ScriptDataEscaped
			}
			emit_char(c)
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_temp_buffer(t, c + 0x0020)
				emit_char(c)
			} else if utils.is_ascii_lower_alpha(c) {
				append_to_temp_buffer(t, c)
				emit_char(c)
			} else {
				reconsume(t.input)
				t.state = .ScriptDataEscaped
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escaped-state
	case .ScriptDataDoubleEscaped:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof()
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataDoubleEscapedDash
			emit_char('-')
		case '<':
			t.state = .ScriptDataDoubleEscapedLessThanSign
			emit_char('<')
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char('\uFFFD')
		case:
			emit_char(c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escaped-dash-state
	case .ScriptDataDoubleEscapedDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof()
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataDoubleEscapedDashDash
			emit_char('-')
		case '<':
			t.state = .ScriptDataDoubleEscapedLessThanSign
			emit_char('<')
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			t.state = .ScriptDataDoubleEscaped
			emit_char('\uFFFD')
		case:
			t.state = .ScriptDataDoubleEscaped
			emit_char(c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escaped-dash-dash-state
	case .ScriptDataDoubleEscapedDashDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof()
			return
		}
		switch c {
		case '-':
			emit_char('-')
		case '<':
			t.state = .ScriptDataDoubleEscapedLessThanSign
			emit_char('<')
		case '>':
			t.state = .ScriptData
			emit_char('>')
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			t.state = .ScriptDataDoubleEscaped
			emit_char('\uFFFD')
		case:
			t.state = .ScriptDataDoubleEscaped
			emit_char(c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escaped-less-than-sign-state
	case .ScriptDataDoubleEscapedLessThanSign:
		if is_eof {
			reconsume(t.input)
			t.state = .ScriptDataDoubleEscaped
			return
		}
		switch c {
		case '/':
			clear_temp_buffer(t)
			t.state = .ScriptDataDoubleEscapeEnd
			emit_char('/')
		case:
			reconsume(t.input)
			t.state = .ScriptDataDoubleEscaped
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
