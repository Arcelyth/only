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

Start_Token :: struct {
    tag_name: string,
    self_closing: bool,
    attrs: [dynamic]Attribute,
}

End_Token :: struct {
    tag_name: string,
    self_closing: bool,
    attrs: [dynamic]Attribute,
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
    // temporary buffer
    temp_buffer: strings.Builder,
    last_start_tag_name: string,
    current_attr_name: strings.Builder,
    current_attr_value: strings.Builder,
    current_attr_dup: bool,
    has_current_attr: bool,
    comment_data_builder: strings.Builder,
    doctype_name_builder: strings.Builder,
	doctype_public_id_builder: strings.Builder,
	doctype_public_id_set: bool,
    doctype_system_id_builder: strings.Builder,
	doctype_system_id_set: bool,
    // character reference code
    char_ref_code: rune,
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

destroy_tokenizer :: proc(t: ^Tokenizer) {
	strings.builder_destroy(&t.tag_name_builder)
	strings.builder_destroy(&t.temp_buffer)
	strings.builder_destroy(&t.current_attr_name)
	strings.builder_destroy(&t.current_attr_value)
	strings.builder_destroy(&t.comment_data_builder)
	strings.builder_destroy(&t.doctype_name_builder)
	strings.builder_destroy(&t.doctype_public_id_builder)
	strings.builder_destroy(&t.doctype_system_id_builder)
}

// ----- emit
emit :: proc(p: ^Parser, tok: Token) {
    dispatch(p, tok)
}

emit_char :: proc(p: ^Parser, c: rune) {
    emit(p, Character_Token{c})
}

emit_eof :: proc(p: ^Parser) {
    emit(p, EOF_Token{})
}

emit_temp_buffer :: proc(p: ^Parser) { 
	buf_str := strings.to_string(p.tokenizer.temp_buffer)
	for r in buf_str {
		emit_char(p, r)
	}
}

emit_cur_tag :: proc(p: ^Parser) {
    t := &p.tokenizer
    flush_cur_attr(t)
	final_str := strings.to_string(t.tag_name_builder)

	#partial switch &tok in t.current_token {
	case Start_Token:
		tok.tag_name = final_str
		t.last_start_tag_name = strings.clone(final_str)
		emit(p, tok)
	case End_Token:
		tok.tag_name = strings.clone(final_str)
		emit(p, tok)
	case Comment_Token:
		tok.data = final_str
		emit(p, tok)
	}
}

emit_cur_comment :: proc(p: ^Parser) {
    t := &p.tokenizer
	#partial switch &tok in t.current_token {
	case Comment_Token:
		tok.data = strings.clone(strings.to_string(t.comment_data_builder))
		emit(p, tok)
	}
}

emit_cur_doctype :: proc(p: ^Parser) {
    t := &p.tokenizer
	#partial switch &tok in t.current_token {
	case DOCTYPE_Token:
		tok.name = strings.clone(strings.to_string(t.doctype_name_builder))
		
		if t.doctype_public_id_set {
			tok.public_ident = strings.clone(strings.to_string(t.doctype_public_id_builder))
		} else {
			tok.public_ident = nil
		}
		
		if t.doctype_system_id_set {
			tok.sys_ident = strings.clone(strings.to_string(t.doctype_system_id_builder))
		} else {
			tok.sys_ident = nil
		}
		
		emit(p, tok)
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

append_to_comment_data :: proc(t: ^Tokenizer, c: rune) {
	strings.write_rune(&t.comment_data_builder, c)
}

create_comment :: proc(t: ^Tokenizer, data: string) {
	strings.builder_reset(&t.comment_data_builder)
	strings.write_string(&t.comment_data_builder, data)
	t.current_token = Comment_Token{}
}

// ----- attr
flush_cur_attr :: proc(t: ^Tokenizer) {
	if !t.has_current_attr do return
	if !t.current_attr_dup {
		attr := Attribute{
			name = strings.clone(strings.to_string(t.current_attr_name)),
			value = strings.clone(strings.to_string(t.current_attr_value)),
		}

		#partial switch &tok in t.current_token {
		case Start_Token: append(&tok.attrs, attr)
		case End_Token: append(&tok.attrs, attr)
		}
	}

	t.has_current_attr = false
}

start_new_attr :: proc(t: ^Tokenizer) {
	flush_cur_attr(t)

	strings.builder_reset(&t.current_attr_name)
	strings.builder_reset(&t.current_attr_value)
	t.current_attr_dup = false
	t.has_current_attr = true
}

append_to_cur_attr_name :: proc(t: ^Tokenizer, c: rune) {
	strings.write_rune(&t.current_attr_name, c)
}

append_to_cur_attr_val :: proc(t: ^Tokenizer, c: rune) {
	strings.write_rune(&t.current_attr_value, c)
}

leave_attr_name :: proc(t: ^Tokenizer) {
	if !t.has_current_attr do return

	name := strings.to_string(t.current_attr_name)
	is_dup := false

	#partial switch &tok in t.current_token {
	case Start_Token:
		for attr in tok.attrs do if attr.name == name do is_dup = true
	case End_Token:
		for attr in tok.attrs do if attr.name == name do is_dup = true
	}

	if is_dup {
		if t.on_error != nil do t.on_error(.DuplicateAttribute, 0)
		t.current_attr_dup = true
	}
}

// ----- DOCTYPE
create_doctype_token :: proc(t: ^Tokenizer) {
	t.current_token = DOCTYPE_Token{}
	strings.builder_reset(&t.doctype_name_builder)
	strings.builder_reset(&t.doctype_public_id_builder)
	strings.builder_reset(&t.doctype_system_id_builder)
	t.doctype_public_id_set = false
	t.doctype_system_id_set = false
}

init_doctype_system_identifier :: proc(t: ^Tokenizer) {
	strings.builder_reset(&t.doctype_system_id_builder)
	t.doctype_system_id_set = true
}

append_to_doctype_system_identifier :: proc(t: ^Tokenizer, c: rune) {
	strings.write_rune(&t.doctype_system_id_builder, c)
}

set_doctype_force_quirks :: proc(t: ^Tokenizer, force: bool) {
	#partial switch &tok in t.current_token {
	case DOCTYPE_Token:
		tok.force_quirks = force
	}
}

append_to_doctype_name :: proc(t: ^Tokenizer, c: rune) {
	strings.write_rune(&t.doctype_name_builder, c)
}

init_doctype_public_ident :: proc(t: ^Tokenizer) {
	strings.builder_reset(&t.doctype_public_id_builder)
	t.doctype_public_id_set = true
}

append_to_doctype_public_ident :: proc(t: ^Tokenizer, c: rune) {
	strings.write_rune(&t.doctype_public_id_builder, c)
}

set_self_closing_flag :: proc(t: ^Tokenizer) {
	#partial switch &tok in t.current_token {
	case Start_Token: tok.self_closing = true
	case End_Token: tok.self_closing = true
	}
}

// https://html.spec.whatwg.org/multipage/parsing.html#charref-in-attribute
is_consumed_as_part_of_attr :: proc(t: ^Tokenizer) -> bool {
    return t.return_state == .AttributeValueDoubleQuoted || 
           t.return_state == .AttributeValueSingleQuoted || 
           t.return_state == .AttributeValueUnquoted
}

// https://html.spec.whatwg.org/multipage/parsing.html#flush-code-points-consumed-as-a-character-reference
flush_code_points_consumed_as_char_ref :: proc(p: ^Parser) {
    t := &p.tokenizer
    s := strings.to_string(t.temp_buffer)
    for cp in s {
        if is_consumed_as_part_of_attr(t) do append_to_cur_attr_val(t, cp)
        else do emit_char(p, cp)
    }
}

try_consume_named_char_ref :: proc(t: ^Tokenizer) -> (match_found: bool, is_last_semicolon: bool, matched_str: string) {
    longest_match_len := 0
    longest_match_str := ""
    longest_match_name := ""
    has_semicolon := false

    for name, value in named_char_ref_map {
        if len(name) > longest_match_len {
            if match(t.input, name) {
                longest_match_len = len(name)
                longest_match_str = value
                longest_match_name = name
                has_semicolon = strings.has_suffix(name, ";")
            }
        }
    }

    if longest_match_len > 0 {
        for r in longest_match_name do strings.write_rune(&t.temp_buffer, r)
        consume_n(t.input, longest_match_len)
        return true, has_semicolon, longest_match_str
    }

    return false, false, ""
}

step_tokenizer :: proc(p: ^Parser) {
    t := &p.tokenizer
	next_char := consume(t.input)
	
	is_eof := next_char == nil
	c := next_char.? if !is_eof else 0

    #partial switch t.state {

    // https://html.spec.whatwg.org/multipage/parsing.html#data-state
	case .Data:
		if is_eof {
            emit_eof(p)
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
			emit_char(p, c)
		case:
			emit_char(p, c)
		}

    // https://html.spec.whatwg.org/multipage/parsing.html#rcdata-state
	case .RCDATA:
		if is_eof {
            emit_eof(p)
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
			emit_char(p, '\uFFFD')
		case:
			emit_char(p, c)
		}
    // https://html.spec.whatwg.org/multipage/parsing.html#rawtext-state
	case .RAWTEXT:
		if is_eof {
			emit_eof(p)
			return
		}
		switch c {
		case '<':
			t.state = .RAWTEXTLessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char(p, '\uFFFD')
		case:
			emit_char(p, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-state
	case .ScriptData:
		if is_eof {
			emit_eof(p)
			return
		}
		switch c {
		case '<':
			t.state = .ScriptDataLessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char(p, '\uFFFD')
		case:
			emit_char(p, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#plaintext-state
	case .PLAINTEXT:
		if is_eof {
			emit_eof(p)
			return
		}
		switch c {
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char(p, '\uFFFD')
		case:
			emit_char(p, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#tag-open-state
	case .TagOpen:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofBeforeTagName, c)
			emit_char(p, '<')
			emit_eof(p)
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
				emit_char(p, '<')
				t.state = .Data
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#end-tag-open-state
	case .EndTagOpen:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofBeforeTagName, c)
			emit_char(p, '<')
			emit_char(p, '/')
			emit_eof(p)
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
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			t.state = .BeforeAttributeName
		case '/':
			t.state = .SelfClosingStartTag
		case '>':
			t.state = .Data
			emit_cur_tag(p)
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
			emit_char(p, '<')
			t.state = .RCDATA
			reconsume(t.input)
			return
		}
		switch c {
		case '/':
			clear_temp_buffer(t)
			t.state = .RCDATAEndTagOpen
		case:
			emit_char(p, '<')
			t.state = .RCDATA
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rcdata-end-tag-open-state
	case .RCDATAEndTagOpen:
		if is_eof {
			emit_char(p, '<')
			emit_char(p, '/')
			t.state = .RCDATA
			reconsume(t.input)
			return
		}
		if utils.is_ascii_alpha(c) {
			create_end_tag(t, "")
			t.state = .RCDATAEndTagName
			reconsume(t.input)
		} else {
			emit_char(p, '<')
			emit_char(p, '/')
			t.state = .RCDATA
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rcdata-end-tag-name-state
	case .RCDATAEndTagName:
		if is_eof {
			emit_char(p, '<')
			emit_char(p, '/')
			emit_temp_buffer(p) 
			t.state = .RCDATA
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			if is_appropriate_end_tag(t) {
				t.state = .BeforeAttributeName
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .RCDATA
				reconsume(t.input)
			}
		case '/':
			if is_appropriate_end_tag(t) {
				t.state = .SelfClosingStartTag
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .RCDATA
				reconsume(t.input)
			}
		case '>':
			if is_appropriate_end_tag(t) {
				t.state = .Data
				emit_cur_tag(p)
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
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
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .RCDATA
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rawtext-less-than-sign-state
	case .RAWTEXTLessThanSign:
		if is_eof {
			emit_char(p, '<')
			t.state = .RAWTEXT
			reconsume(t.input)
			return
		}
		switch c {
		case '/':
			clear_temp_buffer(t)
			t.state = .RAWTEXTEndTagOpen
		case:
			emit_char(p, '<')
			t.state = .RAWTEXT
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rawtext-end-tag-open-state
	case .RAWTEXTEndTagOpen:
		if is_eof {
			emit_char(p, '<')
			emit_char(p, '/')
			t.state = .RAWTEXT
			reconsume(t.input)
			return
		}
		if utils.is_ascii_alpha(c) {
			create_end_tag(t, "")
			t.state = .RAWTEXTEndTagName
			reconsume(t.input)
		} else {
			emit_char(p, '<')
			emit_char(p, '/')
			t.state = .RAWTEXT
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#rawtext-end-tag-name-state
	case .RAWTEXTEndTagName:
		if is_eof {
			emit_char(p, '<')
			emit_char(p, '/')
			emit_temp_buffer(p) 
			t.state = .RAWTEXT
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			if is_appropriate_end_tag(t) {
				t.state = .BeforeAttributeName
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .RAWTEXT
				reconsume(t.input)
			}
		case '/':
			if is_appropriate_end_tag(t) {
				t.state = .SelfClosingStartTag
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .RAWTEXT
				reconsume(t.input)
			}
		case '>':
			if is_appropriate_end_tag(t) {
				t.state = .Data
				emit_cur_tag(p)
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
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
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .RAWTEXT
				reconsume(t.input)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-less-than-sign-state
	case .ScriptDataLessThanSign:
		if is_eof {
			emit_char(p, '<')
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
			emit_char(p, '<')
			emit_char(p, '!')
		case:
			emit_char(p, '<')
			t.state = .ScriptData
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-end-tag-open-state
	case .ScriptDataEndTagOpen:
		if is_eof {
			emit_char(p, '<')
			emit_char(p, '/')
			t.state = .ScriptData
			reconsume(t.input)
			return
		}
		if utils.is_ascii_alpha(c) {
			create_end_tag(t, "")
			t.state = .ScriptDataEndTagName
			reconsume(t.input)
		} else {
			emit_char(p, '<')
			emit_char(p, '/')
			t.state = .ScriptData
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-end-tag-name-state
	case .ScriptDataEndTagName:
		if is_eof {
			emit_char(p, '<')
			emit_char(p, '/')
			emit_temp_buffer(p) 
			t.state = .ScriptData
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			if is_appropriate_end_tag(t) {
				t.state = .BeforeAttributeName
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .ScriptData
				reconsume(t.input)
			}
		case '/':
			if is_appropriate_end_tag(t) {
				t.state = .SelfClosingStartTag
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .ScriptData
				reconsume(t.input)
			}
		case '>':
			if is_appropriate_end_tag(t) {
				t.state = .Data
				emit_cur_tag(p)
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
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
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
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
			emit_char(p, '-')
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
			emit_char(p, '-')
		case:
			t.state = .ScriptData
			reconsume(t.input)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-state
	case .ScriptDataEscaped:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataEscapedDash
			emit_char(p, '-')
		case '<':
			t.state = .ScriptDataEscapedLessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char(p, '\uFFFD')
		case:
			emit_char(p, c)
		}
        
    // https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-dash-state
	case .ScriptDataEscapedDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataEscapedDashDash
			emit_char(p, '-')
		case '<':
			t.state = .ScriptDataEscapedLessThanSign
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			t.state = .ScriptDataEscaped
			emit_char(p, '\uFFFD')
		case:
			t.state = .ScriptDataEscaped
			emit_char(p, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-dash-dash-state
	case .ScriptDataEscapedDashDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			emit_char(p, '-')
		case '<':
			t.state = .ScriptDataEscapedLessThanSign
		case '>':
			t.state = .ScriptData
			emit_char(p, '>')
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			t.state = .ScriptDataEscaped
			emit_char(p, '\uFFFD')
		case:
			t.state = .ScriptDataEscaped
			emit_char(p, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-less-than-sign-state
	case .ScriptDataEscapedLessThanSign:
		if is_eof {
			emit_char(p, '<')
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
				emit_char(p, '<')
				reconsume(t.input)
				t.state = .ScriptDataDoubleEscapeStart
			} else {
				emit_char(p, '<')
				reconsume(t.input)
				t.state = .ScriptDataEscaped
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-end-tag-open-state
	case .ScriptDataEscapedEndTagOpen:
		if is_eof {
			emit_char(p, '<')
			emit_char(p, '/')
			t.state = .ScriptDataEscaped
			reconsume(t.input)
			return
		}
		if utils.is_ascii_alpha(c) {
			create_end_tag(t, "")
			reconsume(t.input)
			t.state = .ScriptDataEscapedEndTagName
		} else {
			emit_char(p, '<')
			emit_char(p, '/')
			reconsume(t.input)
			t.state = .ScriptDataEscaped
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-escaped-end-tag-name-state
	case .ScriptDataEscapedEndTagName:
		if is_eof {
			emit_char(p, '<')
			emit_char(p, '/')
			emit_temp_buffer(p) 
			t.state = .ScriptDataEscaped
			reconsume(t.input)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			if is_appropriate_end_tag(t) {
				t.state = .BeforeAttributeName
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .ScriptDataEscaped
				reconsume(t.input)
			}
		case '/':
			if is_appropriate_end_tag(t) {
				t.state = .SelfClosingStartTag
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
				t.state = .ScriptDataEscaped
				reconsume(t.input)
			}
		case '>':
			if is_appropriate_end_tag(t) {
				t.state = .Data
				emit_cur_tag(p)
			} else {
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
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
				emit_char(p, '<')
				emit_char(p, '/')
				emit_temp_buffer(p) 
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
			emit_char(p, c)
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_temp_buffer(t, c + 0x0020)
				emit_char(p, c)
			} else if utils.is_ascii_lower_alpha(c) {
				append_to_temp_buffer(t, c)
				emit_char(p, c)
			} else {
				reconsume(t.input)
				t.state = .ScriptDataEscaped
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escaped-state
	case .ScriptDataDoubleEscaped:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataDoubleEscapedDash
			emit_char(p, '-')
		case '<':
			t.state = .ScriptDataDoubleEscapedLessThanSign
			emit_char(p, '<')
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			emit_char(p, '\uFFFD')
		case:
			emit_char(p, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escaped-dash-state
	case .ScriptDataDoubleEscapedDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			t.state = .ScriptDataDoubleEscapedDashDash
			emit_char(p, '-')
		case '<':
			t.state = .ScriptDataDoubleEscapedLessThanSign
			emit_char(p, '<')
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			t.state = .ScriptDataDoubleEscaped
			emit_char(p, '\uFFFD')
		case:
			t.state = .ScriptDataDoubleEscaped
			emit_char(p, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escaped-dash-dash-state
	case .ScriptDataDoubleEscapedDashDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInScriptHtmlCommentLikeText, c)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			emit_char(p, '-')
		case '<':
			t.state = .ScriptDataDoubleEscapedLessThanSign
			emit_char(p, '<')
		case '>':
			t.state = .ScriptData
			emit_char(p, '>')
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			t.state = .ScriptDataDoubleEscaped
			emit_char(p, '\uFFFD')
		case:
			t.state = .ScriptDataDoubleEscaped
			emit_char(p, c)
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
			emit_char(p, '/')
		case:
			reconsume(t.input)
			t.state = .ScriptDataDoubleEscaped
		}

    // https://html.spec.whatwg.org/multipage/parsing.html#script-data-double-escape-end-state
	case .ScriptDataDoubleEscapeEnd:
		if is_eof {
			reconsume(t.input)
			t.state = .ScriptDataDoubleEscaped
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ', '/', '>':
			if strings.to_string(t.temp_buffer) == "script" {
				t.state = .ScriptDataEscaped
			} else {
				t.state = .ScriptDataDoubleEscaped
			}
			emit_char(p, c)
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_temp_buffer(t, c + 0x0020)
				emit_char(p, c)
			} else if utils.is_ascii_lower_alpha(c) {
				append_to_temp_buffer(t, c)
				emit_char(p, c)
			} else {
				reconsume(t.input)
				t.state = .ScriptDataDoubleEscaped
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#before-attribute-name-state
	case .BeforeAttributeName:
		if is_eof {
			reconsume(t.input)
			t.state = .AfterAttributeName
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			// Ignore
		case '/', '>':
			reconsume(t.input)
			t.state = .AfterAttributeName
		case '=':
			if t.on_error != nil do t.on_error(.UnexpectedEqualsSignBeforeAttributeName, c)
			start_new_attr(t)
			append_to_cur_attr_name(t, '=')
			t.state = .AttributeName
		case:
			start_new_attr(t)
			reconsume(t.input)
			t.state = .AttributeName
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#attribute-name-state
	case .AttributeName:
		if is_eof {
			leave_attr_name(t)
			reconsume(t.input)
			t.state = .AfterAttributeName
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ', '/', '>':
			leave_attr_name(t)
			reconsume(t.input)
			t.state = .AfterAttributeName
		case '=':
			leave_attr_name(t)
			t.state = .BeforeAttributeValue
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_cur_attr_name(t, '\uFFFD')
		case '"', '\'', '<':
			if t.on_error != nil do t.on_error(.UnexpectedCharacterInAttributeName, c)
			append_to_cur_attr_name(t, c)
		case:
			if utils.is_ascii_upper_alpha(c) {
				append_to_cur_attr_name(t, c + 0x0020)
			} else {
				append_to_cur_attr_name(t, c)
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#after-attribute-name-state
	case .AfterAttributeName:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInTag, c)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			// Ignore
		case '/':
			t.state = .SelfClosingStartTag
		case '=':
			t.state = .BeforeAttributeValue
		case '>':
			t.state = .Data
			emit_cur_tag(p)
		case:
			start_new_attr(t)
			reconsume(t.input)
			t.state = .AttributeName
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#before-attribute-value-state
	case .BeforeAttributeValue:
		if is_eof {
			reconsume(t.input)
			t.state = .AttributeValueUnquoted
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			// Ignore
		case '"':
			t.state = .AttributeValueDoubleQuoted
		case '\'':
			t.state = .AttributeValueSingleQuoted
		case '>':
			if t.on_error != nil do t.on_error(.MissingAttributeValue, c)
			t.state = .Data
			emit_cur_tag(p)
		case:
			reconsume(t.input)
			t.state = .AttributeValueUnquoted
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#attribute-value-double-quoted-state
	case .AttributeValueDoubleQuoted:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInTag, c)
			emit_eof(p)
			return
		}
		switch c {
		case '"':
			t.state = .AfterAttributeValueQuoted
		case '&':
			t.return_state = .AttributeValueDoubleQuoted
			t.state = .CharacterReference
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_cur_attr_val(t, '\uFFFD')
		case:
			append_to_cur_attr_val(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#attribute-value-single-quoted-state
	case .AttributeValueSingleQuoted:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInTag, c)
			emit_eof(p)
			return
		}
		switch c {
		case '\'':
			t.state = .AfterAttributeValueQuoted
		case '&':
			t.return_state = .AttributeValueSingleQuoted
			t.state = .CharacterReference
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_cur_attr_val(t, '\uFFFD')
		case:
			append_to_cur_attr_val(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#attribute-value-unquoted-state
	case .AttributeValueUnquoted:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInTag, c)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			t.state = .BeforeAttributeName
		case '&':
			t.return_state = .AttributeValueUnquoted
			t.state = .CharacterReference
		case '>':
			t.state = .Data
			emit_cur_tag(p)
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_cur_attr_val(t, '\uFFFD')
		case '"', '\'', '<', '=', '`':
			if t.on_error != nil do t.on_error(.UnexpectedCharacterInUnquotedAttributeValue, c)
			append_to_cur_attr_val(t, c)
		case:
			append_to_cur_attr_val(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#after-attribute-value-quoted-state
	case .AfterAttributeValueQuoted:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInTag, c)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\x0C', ' ':
			t.state = .BeforeAttributeName
		case '/':
			t.state = .SelfClosingStartTag
		case '>':
			t.state = .Data
			emit_cur_tag(p)
		case:
			if t.on_error != nil do t.on_error(.MissingWhitespaceBetweenAttributes, c)
			reconsume(t.input)
			t.state = .BeforeAttributeName
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#self-closing-start-tag-state
	case .SelfClosingStartTag:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInTag, c)
			emit_eof(p)
			return
		}
		switch c {
		case '>':
			set_self_closing_flag(t)
			t.state = .Data
			emit_cur_tag(p)
		case:
			if t.on_error != nil do t.on_error(.UnexpectedSolidusInTag, c)
			reconsume(t.input)
			t.state = .BeforeAttributeName
		}

    // https://html.spec.whatwg.org/multipage/parsing.html#bogus-comment-state
	case .BogusComment:
		if is_eof {
			emit_cur_comment(p)
			emit_eof(p)
			return
		}
		switch c {
		case '>':
			t.state = .Data
			emit_cur_comment(p)
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_comment_data(t, '\uFFFD')
		case:
			append_to_comment_data(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#markup-declaration-open-state 
	case .MarkupDeclarationOpen:
		if match(t.input, "--") {
			consume_n(t.input, 2)
			create_comment(t, "")
			t.state = .CommentStart
		} else if match_insensitive(t.input, "DOCTYPE") {
			consume_n(t.input, 7)
			t.state = .DOCTYPE
		} else if match(t.input, "[CDATA[") {
            // ---TODO---
		} else {
			if t.on_error != nil do t.on_error(.IncorrectlyOpenedComment, c)
			create_comment(t, "")
			reconsume(t.input)
			t.state = .BogusComment
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-start-state
	case .CommentStart:
		if is_eof {
			reconsume(t.input)
			t.state = .Comment
			return
		}
		switch c {
		case '-':
			t.state = .CommentStartDash
		case '>':
			if t.on_error != nil do t.on_error(.AbruptClosingOfEmptyComment, c)
			t.state = .Data
			emit_cur_comment(p)
		case:
			reconsume(t.input)
			t.state = .Comment
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-start-dash-state
	case .CommentStartDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInComment, c)
			emit_cur_comment(p)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			t.state = .CommentEnd
		case '>':
			if t.on_error != nil do t.on_error(.AbruptClosingOfEmptyComment, c)
			t.state = .Data
			emit_cur_comment(p)
		case:
			append_to_comment_data(t, '-')
			reconsume(t.input)
			t.state = .Comment
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-state
	case .Comment:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInComment, c)
			emit_cur_comment(p)
			emit_eof(p)
			return
		}
		switch c {
		case '<':
			append_to_comment_data(t, '<')
			t.state = .CommentLessThanSign
		case '-':
			t.state = .CommentEndDash
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_comment_data(t, '\uFFFD')
		case:
			append_to_comment_data(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-less-than-sign-state
	case .CommentLessThanSign:
		if is_eof {
			reconsume(t.input)
			t.state = .Comment
			return
		}
		switch c {
		case '!':
			append_to_comment_data(t, '!')
			t.state = .CommentLessThanSignBang
		case '<':
			append_to_comment_data(t, '<')
		case:
			reconsume(t.input)
			t.state = .Comment
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-less-than-sign-bang-state
	case .CommentLessThanSignBang:
		if is_eof {
			reconsume(t.input)
			t.state = .Comment
			return
		}
		switch c {
		case '-':
			t.state = .CommentLessThanSignBangDash
		case:
			reconsume(t.input)
			t.state = .Comment
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-less-than-sign-bang-dash-state
	case .CommentLessThanSignBangDash:
		if is_eof {
			reconsume(t.input)
			t.state = .CommentEndDash
			return
		}
		switch c {
		case '-':
			t.state = .CommentLessThanSignBangDashDash
		case:
			reconsume(t.input)
			t.state = .CommentEndDash
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-less-than-sign-bang-dash-dash-state
	case .CommentLessThanSignBangDashDash:
		if is_eof || c == '>' {
			reconsume(t.input)
			t.state = .CommentEnd
		} else {
			if t.on_error != nil do t.on_error(.NestedComment, c)
			reconsume(t.input)
			t.state = .CommentEnd
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-end-dash-state
	case .CommentEndDash:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInComment, c)
			emit_cur_comment(p)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			t.state = .CommentEnd
		case:
			append_to_comment_data(t, '-')
			reconsume(t.input)
			t.state = .Comment
		}

    // https://html.spec.whatwg.org/multipage/parsing.html#comment-end-state
	case .CommentEnd:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInComment, 0)
			emit_cur_comment(p)
			emit_eof(p)
			return
		}
		switch c {
		case '>':
			t.state = .Data
			emit_cur_comment(p)
		case '!':
			t.state = .CommentEndBang
		case '-':
			append_to_comment_data(t, '-')
		case:
			append_to_comment_data(t, '-')
			append_to_comment_data(t, '-')
			reconsume(t.input)
			t.state = .Comment
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#comment-end-bang-state
	case .CommentEndBang:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInComment, 0)
			emit_cur_comment(p)
			emit_eof(p)
			return
		}
		switch c {
		case '-':
			append_to_comment_data(t, '-')
			append_to_comment_data(t, '-')
			append_to_comment_data(t, '!')
			t.state = .CommentEndDash
		case '>':
			if t.on_error != nil do t.on_error(.IncorrectlyClosedComment, c)
			t.state = .Data
			emit_cur_comment(p)
		case:
			append_to_comment_data(t, '-')
			append_to_comment_data(t, '-')
			append_to_comment_data(t, '!')
			reconsume(t.input)
			t.state = .Comment
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#doctype-state
	case .DOCTYPE:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			create_doctype_token(t)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
			t.state = .BeforeDOCTYPEName
		case '>':
			reconsume(t.input)
			t.state = .BeforeDOCTYPEName
		case:
			if t.on_error != nil do t.on_error(.MissingWhitespaceBeforeDOCTYPEName, c)
			reconsume(t.input)
			t.state = .BeforeDOCTYPEName
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#before-doctype-name-state
	case .BeforeDOCTYPEName:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			create_doctype_token(t)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
            // Ignore
		case 'A'..='Z':
			create_doctype_token(t)
			append_to_doctype_name(t, c + 0x20)
			t.state = .DOCTYPEName
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			create_doctype_token(t)
			append_to_doctype_name(t, '\uFFFD')
			t.state = .DOCTYPEName
		case '>':
			if t.on_error != nil do t.on_error(.MissingDOCTYPEName, c)
			create_doctype_token(t)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			create_doctype_token(t)
			append_to_doctype_name(t, c)
			t.state = .DOCTYPEName
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#doctype-name-state
	case .DOCTYPEName:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
			t.state = .AfterDOCTYPEName
		case '>':
			t.state = .Data
			emit_cur_doctype(p)
		case 'A'..='Z':
			append_to_doctype_name(t, c + 0x20)
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_doctype_name(t, '\uFFFD')
		case:
			append_to_doctype_name(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-name-state
	case .AfterDOCTYPEName:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
			// Ignore
		case '>':
			t.state = .Data
			emit_cur_doctype(p)
		case:
			if match_insensitive(t.input, "PUBLIC") {
				consume_n(t.input, 6)
				t.state = .AfterDOCTYPEPublicKeyword
			} else if match_insensitive(t.input, "SYSTEM") {
				consume_n(t.input, 6)
				t.state = .AfterDOCTYPESystemKeyword
			} else {
				if t.on_error != nil do t.on_error(.InvalidCharacterSequenceAfterDOCTYPEName, c)
				set_doctype_force_quirks(t, true)
				reconsume(t.input)
				t.state = .BogusDOCTYPE
			}
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-public-keyword-state
	case .AfterDOCTYPEPublicKeyword:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
			t.state = .BeforeDOCTYPEPublicIdentifier
		case '"':
			if t.on_error != nil do t.on_error(.MissingWhitespaceAfterDOCTYPEPublicKeyword, c)
			init_doctype_public_ident(t)
			t.state = .DOCTYPEPublicIdentifierDoubleQuoted
		case '\'':
			if t.on_error != nil do t.on_error(.MissingWhitespaceAfterDOCTYPEPublicKeyword, c)
			init_doctype_public_ident(t)
			t.state = .DOCTYPEPublicIdentifierSingleQuoted
		case '>':
			if t.on_error != nil do t.on_error(.MissingDOCTYPEPublicIdentifier, c)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			if t.on_error != nil do t.on_error(.MissingQuoteBeforeDOCTYPEPublicIdentifier, c)
			set_doctype_force_quirks(t, true)
			reconsume(t.input)
			t.state = .BogusDOCTYPE
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#before-doctype-public-identifier-state
	case .BeforeDOCTYPEPublicIdentifier:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
			// Ignore
		case '"':
			init_doctype_public_ident(t)
			t.state = .DOCTYPEPublicIdentifierDoubleQuoted
		case '\'':
			init_doctype_public_ident(t)
			t.state = .DOCTYPEPublicIdentifierSingleQuoted
		case '>':
			if t.on_error != nil do t.on_error(.MissingDOCTYPEPublicIdentifier, c)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			if t.on_error != nil do t.on_error(.MissingQuoteBeforeDOCTYPEPublicIdentifier, c)
			set_doctype_force_quirks(t, true)
			reconsume(t.input)
			t.state = .BogusDOCTYPE
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#doctype-public-identifier-(double-quoted)-state
	case .DOCTYPEPublicIdentifierDoubleQuoted:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '"':
			t.state = .AfterDOCTYPEPublicIdentifier
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_doctype_public_ident(t, '\uFFFD')
		case '>':
			if t.on_error != nil do t.on_error(.AbruptDOCTYPEPublicIdentifier, c)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			append_to_doctype_public_ident(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#doctype-public-identifier-(single-quoted)-state
	case .DOCTYPEPublicIdentifierSingleQuoted:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\'':
			t.state = .AfterDOCTYPEPublicIdentifier
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_doctype_public_ident(t, '\uFFFD')
		case '>':
			if t.on_error != nil do t.on_error(.AbruptDOCTYPEPublicIdentifier, c)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			append_to_doctype_public_ident(t, c)
		}

    // https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-public-identifier-state
	case .AfterDOCTYPEPublicIdentifier:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
			t.state = .BetweenDOCTYPEPublicAndSystemIdentifiers
		case '>':
			t.state = .Data
			emit_cur_doctype(p)
		case '"':
			if t.on_error != nil do t.on_error(.MissingWhitespaceBetweenDOCTYPEPublicAndSystemIdentifiers, c)
			init_doctype_system_identifier(t)
			t.state = .DOCTYPESystemIdentifierDoubleQuoted
		case '\'':
			if t.on_error != nil do t.on_error(.MissingWhitespaceBetweenDOCTYPEPublicAndSystemIdentifiers, c)
			init_doctype_system_identifier(t)
			t.state = .DOCTYPESystemIdentifierSingleQuoted
		case:
			if t.on_error != nil do t.on_error(.MissingQuoteBeforeDOCTYPESystemIdentifier, c)
			set_doctype_force_quirks(t, true)
			reconsume(t.input)
			t.state = .BogusDOCTYPE
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#between-doctype-public-and-system-identifiers-state
	case .BetweenDOCTYPEPublicAndSystemIdentifiers:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
            // Ignore
		case '>':
			t.state = .Data
			emit_cur_doctype(p)
		case '"':
			init_doctype_system_identifier(t)
			t.state = .DOCTYPESystemIdentifierDoubleQuoted
		case '\'':
			init_doctype_system_identifier(t)
			t.state = .DOCTYPESystemIdentifierSingleQuoted
		case:
			if t.on_error != nil do t.on_error(.MissingQuoteBeforeDOCTYPESystemIdentifier, c)
			set_doctype_force_quirks(t, true)
			reconsume(t.input)
			t.state = .BogusDOCTYPE
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-system-keyword-state
	case .AfterDOCTYPESystemKeyword:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
			t.state = .BeforeDOCTYPESystemIdentifier
		case '"':
			if t.on_error != nil do t.on_error(.MissingWhitespaceAfterDOCTYPESystemKeyword, c)
			init_doctype_system_identifier(t)
			t.state = .DOCTYPESystemIdentifierDoubleQuoted
		case '\'':
			if t.on_error != nil do t.on_error(.MissingWhitespaceAfterDOCTYPESystemKeyword, c)
			init_doctype_system_identifier(t)
			t.state = .DOCTYPESystemIdentifierSingleQuoted
		case '>':
			if t.on_error != nil do t.on_error(.MissingDOCTYPESystemIdentifier, c)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			if t.on_error != nil do t.on_error(.MissingQuoteBeforeDOCTYPESystemIdentifier, c)
			set_doctype_force_quirks(t, true)
			reconsume(t.input)
			t.state = .BogusDOCTYPE
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#before-doctype-system-identifier-state
	case .BeforeDOCTYPESystemIdentifier:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
            // Ignore
		case '"':
			init_doctype_system_identifier(t)
			t.state = .DOCTYPESystemIdentifierDoubleQuoted
		case '\'':
			init_doctype_system_identifier(t)
			t.state = .DOCTYPESystemIdentifierSingleQuoted
		case '>':
			if t.on_error != nil do t.on_error(.MissingDOCTYPESystemIdentifier, c)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			if t.on_error != nil do t.on_error(.MissingQuoteBeforeDOCTYPESystemIdentifier, c)
			set_doctype_force_quirks(t, true)
			reconsume(t.input)
			t.state = .BogusDOCTYPE
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#doctype-system-identifier-(double-quoted)-state
	case .DOCTYPESystemIdentifierDoubleQuoted:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '"':
			t.state = .AfterDOCTYPESystemIdentifier
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_doctype_system_identifier(t, '\uFFFD')
		case '>':
			if t.on_error != nil do t.on_error(.AbruptDOCTYPESystemIdentifier, c)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			append_to_doctype_system_identifier(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#doctype-system-identifier-(single-quoted)-state
	case .DOCTYPESystemIdentifierSingleQuoted:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\'':
			t.state = .AfterDOCTYPESystemIdentifier
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
			append_to_doctype_system_identifier(t, '\uFFFD')
		case '>':
			if t.on_error != nil do t.on_error(.AbruptDOCTYPESystemIdentifier, c)
			set_doctype_force_quirks(t, true)
			t.state = .Data
			emit_cur_doctype(p)
		case:
			append_to_doctype_system_identifier(t, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#after-doctype-system-identifier-state
	case .AfterDOCTYPESystemIdentifier:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInDOCTYPE, 0)
			set_doctype_force_quirks(t, true)
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '\t', '\n', '\f', ' ':
		case '>':
			t.state = .Data
			emit_cur_doctype(p)
		case:
			if t.on_error != nil do t.on_error(.UnexpectedCharacterAfterDOCTYPESystemIdentifier, c)
			reconsume(t.input)
			t.state = .BogusDOCTYPE
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#bogus-doctype-state
	case .BogusDOCTYPE:
		if is_eof {
			emit_cur_doctype(p)
			emit_eof(p)
			return
		}
		switch c {
		case '>':
			t.state = .Data
			emit_cur_doctype(p)
		case 0x0000:
			if t.on_error != nil do t.on_error(.UnexpectedNullCharacter, c)
		case:
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#cdata-section-state
	case .CDATASection:
		if is_eof {
			if t.on_error != nil do t.on_error(.EofInCDATA, 0)
			emit_eof(p)
			return
		}
		switch c {
		case ']':
			t.state = .CDATASectionBracket
		case:
			emit_char(p, c)
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#cdata-section-bracket-state
	case .CDATASectionBracket:
		if is_eof {
			emit_char(p, ']')
			reconsume(t.input)
			t.state = .CDATASection
			return
		}
		switch c {
		case ']':
			t.state = .CDATASectionEnd
		case:
			emit_char(p, ']')
			reconsume(t.input)
			t.state = .CDATASection
		}

    // https://html.spec.whatwg.org/multipage/parsing.html#cdata-section-end-state
	case .CDATASectionEnd:
		if is_eof {
			emit_char(p, ']')
			emit_char(p, ']')
			reconsume(t.input)
			t.state = .CDATASection
			return
		}
		switch c {
		case ']':
			emit_char(p, ']')
		case '>':
			t.state = .Data
		case:
			emit_char(p, ']')
			emit_char(p, ']')
			reconsume(t.input)
			t.state = .CDATASection
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#character-reference-state
	case .CharacterReference:
		strings.builder_reset(&t.temp_buffer)
		strings.write_rune(&t.temp_buffer, '&')
		if is_eof {
			flush_code_points_consumed_as_char_ref(p)
			reconsume(t.input)
			t.state = t.return_state
			return
		}
		switch {
		case utils.is_ascii_alphanum(c):
			reconsume(t.input)
			t.state = .NamedCharacterReference
		case c == '#':
			strings.write_rune(&t.temp_buffer, c)
			t.state = .NumericCharacterReference
		case:
			flush_code_points_consumed_as_char_ref(p)
			reconsume(t.input)
			t.state = t.return_state
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#named-character-reference-state
	case .NamedCharacterReference:
		match_found, is_last_semicolon, matched_str := try_consume_named_char_ref(t)
		if match_found {
			next_c, has_next := peek(t.input).? 
			if is_consumed_as_part_of_attr(t) && !is_last_semicolon && has_next && (next_c == '=' || utils.is_ascii_alphanum(next_c)) {
				flush_code_points_consumed_as_char_ref(p)
				t.state = t.return_state
			} else {
				if !is_last_semicolon {
					if t.on_error != nil do t.on_error(.MissingSemicolonAfterCharacterReference, 0)
				}
				strings.builder_reset(&t.temp_buffer)
				strings.write_string(&t.temp_buffer, matched_str)
				flush_code_points_consumed_as_char_ref(p)
				t.state = t.return_state
			}
		} else {
			flush_code_points_consumed_as_char_ref(p)
			t.state = .AmbiguousAmpersand
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#ambiguous-ampersand-state
	case .AmbiguousAmpersand:
		if is_eof {
			reconsume(t.input)
			t.state = t.return_state
			return
		}
		switch {
		case utils.is_ascii_alphanum(c):
			if is_consumed_as_part_of_attr(t) {
				append_to_cur_attr_val(t, c)
			} else {
				emit_char(p, c)
			}
		case c == ';':
			if t.on_error != nil do t.on_error(.UnknownNamedCharacterReference, c)
			reconsume(t.input)
			t.state = t.return_state
		case:
			reconsume(t.input)
			t.state = t.return_state
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#numeric-character-reference-state
	case .NumericCharacterReference:
		t.char_ref_code = 0
		if is_eof {
			reconsume(t.input)
			t.state = .DecimalCharacterReferenceStart
			return
		}
		switch c {
		case 'x', 'X':
			strings.write_rune(&t.temp_buffer, c)
			t.state = .HexadecimalCharacterReferenceStart
		case:
			reconsume(t.input)
			t.state = .DecimalCharacterReferenceStart
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#hexadecimal-character-reference-start-state
	case .HexadecimalCharacterReferenceStart:
		if is_eof {
			if t.on_error != nil do t.on_error(.AbsenceOfDigitsInNumericCharacterReference, 0)
			flush_code_points_consumed_as_char_ref(p)
			reconsume(t.input)
			t.state = t.return_state
			return
		}
		switch {
		case utils.is_ascii_hex_digit(c):
			reconsume(t.input)
			t.state = .HexadecimalCharacterReference
		case:
			if t.on_error != nil do t.on_error(.AbsenceOfDigitsInNumericCharacterReference, c)
			flush_code_points_consumed_as_char_ref(p)
			reconsume(t.input)
			t.state = t.return_state
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#decimal-character-reference-start-state
	case .DecimalCharacterReferenceStart:
		if is_eof {
			if t.on_error != nil do t.on_error(.AbsenceOfDigitsInNumericCharacterReference, 0)
			flush_code_points_consumed_as_char_ref(p)
			reconsume(t.input)
			t.state = t.return_state
			return
		}
		switch {
		case utils.is_ascii_digit(c):
			reconsume(t.input)
			t.state = .DecimalCharacterReference
		case:
			if t.on_error != nil do t.on_error(.AbsenceOfDigitsInNumericCharacterReference, c)
			flush_code_points_consumed_as_char_ref(p)
			reconsume(t.input)
			t.state = t.return_state
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#hexadecimal-character-reference-state
	case .HexadecimalCharacterReference:
		if is_eof {
			if t.on_error != nil do t.on_error(.MissingSemicolonAfterCharacterReference, 0)
			reconsume(t.input)
			t.state = .NumericCharacterReferenceEnd
			return
		}
		switch {
		case utils.is_ascii_digit(c):
			t.char_ref_code = t.char_ref_code * 16 + (c - 0x0030)
		case utils.is_ascii_upper_hex_digit(c):
			t.char_ref_code = t.char_ref_code * 16 + (c - 0x0037)
		case utils.is_ascii_lower_hex_digit(c):
			t.char_ref_code = t.char_ref_code * 16 + (c - 0x0057)
		case c == ';':
			t.state = .NumericCharacterReferenceEnd
		case:
			if t.on_error != nil do t.on_error(.MissingSemicolonAfterCharacterReference, c)
			reconsume(t.input)
			t.state = .NumericCharacterReferenceEnd
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#decimal-character-reference-state
	case .DecimalCharacterReference:
		if is_eof {
			if t.on_error != nil do t.on_error(.MissingSemicolonAfterCharacterReference, 0)
			reconsume(t.input)
			t.state = .NumericCharacterReferenceEnd
			return
		}
		switch {
		case utils.is_ascii_digit(c):
			t.char_ref_code = t.char_ref_code * 10 + (c - 0x0030)
		case c == ';':
			t.state = .NumericCharacterReferenceEnd
		case:
			if t.on_error != nil do t.on_error(.MissingSemicolonAfterCharacterReference, c)
			reconsume(t.input)
			t.state = .NumericCharacterReferenceEnd
		}

	// https://html.spec.whatwg.org/multipage/parsing.html#numeric-character-reference-end-state
	case .NumericCharacterReferenceEnd:
		code := t.char_ref_code
		if code == 0x00 {
			if t.on_error != nil do t.on_error(.NullCharacterReference, 0)
			code = 0xFFFD
		} else if code > 0x10FFFF {
			if t.on_error != nil do t.on_error(.CharacterReferenceOutsideUnicodeRange, 0)
			code = 0xFFFD
		} else if utils.is_surrogate(code) {
			if t.on_error != nil do t.on_error(.SurrogateCharacterReference, 0)
			code = 0xFFFD
		} else if utils.is_noncharacter(code) {
			if t.on_error != nil do t.on_error(.NoncharacterCharacterReference, 0)
		} else if code == 0x0D || (utils.is_control(code) && !utils.is_ascii_whitespace(code)) {
			if t.on_error != nil do t.on_error(.ControlCharacterReference, 0)
			switch code {
			case 0x80: code = 0x20AC
			case 0x82: code = 0x201A
			case 0x83: code = 0x0192
			case 0x84: code = 0x201E
			case 0x85: code = 0x2026
			case 0x86: code = 0x2020
			case 0x87: code = 0x2021
			case 0x88: code = 0x02C6
			case 0x89: code = 0x2030
			case 0x8A: code = 0x0160
			case 0x8B: code = 0x2039
			case 0x8C: code = 0x0152
			case 0x8E: code = 0x017D
			case 0x91: code = 0x2018
			case 0x92: code = 0x2019
			case 0x93: code = 0x201C
			case 0x94: code = 0x201D
			case 0x95: code = 0x2022
			case 0x96: code = 0x2013
			case 0x97: code = 0x2014
			case 0x98: code = 0x02DC
			case 0x99: code = 0x2122
			case 0x9A: code = 0x0161
			case 0x9B: code = 0x203A
			case 0x9C: code = 0x0153
			case 0x9E: code = 0x017E
			case 0x9F: code = 0x0178
			}
		}

		strings.builder_reset(&t.temp_buffer)
		strings.write_rune(&t.temp_buffer, rune(code))
		flush_code_points_consumed_as_char_ref(p)
		t.state = t.return_state
    }
}

tokenize :: proc(p: ^Parser) {
	for {
        step_tokenizer(p)
		if p.tokenizer.pause_flag {
			return
		}
	}
}
