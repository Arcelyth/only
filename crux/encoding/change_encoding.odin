package encoding

EncodingChangeResult :: enum {
	NoChange,
	ChangedOnTheFly,
	RestartedFromMemory,
	RestartedFromNetwork,
	IgnoredNewEncoding,
}

norm_for_change :: proc(enc: string) -> string {
	if ascii_eq_ci(enc, "UTF-16LE") || ascii_eq_ci(enc, "UTF-16BE") {
		return "UTF-8"
	}
	if ascii_eq_ci(enc, "x-user-defined") {
		return "windows-1252"
	}
	return enc
}

same_unicode_prefix :: proc(
	prefix: []byte,
	old_enc: string,
	new_enc: string,
	decode_prefix: proc(bytes: []byte, enc: string) -> Maybe(string),
) -> bool {
	if len(prefix) == 0 do return true

	old_text_res := decode_prefix(prefix, old_enc)
	new_text_res := decode_prefix(prefix, new_enc)

	old_text, old_ok := old_text_res.?
	new_text, new_ok := new_text_res.?

	if !old_ok || !new_ok do return false
	return old_text == new_text
}

can_reparse_from_memory :: proc(
	have_full_body: bool,
	source_bytes: []byte,
) -> bool {
	return have_full_body && len(source_bytes) > 0
}

ChangeEncodingParams :: struct {
	old_enc: ^string,
	new_enc: string,
	confidence: ^Confidence,

	request_method: string,
	supports_on_the_fly: bool,

	source_bytes: []byte,
	last_converted_byte_index: int,
	have_full_body: bool,

	decode_prefix: proc(bytes: []byte, enc: string) -> Maybe(string),
	reparse_from_memory: proc(new_enc: string),
	restart_navigate_from_network: proc(new_enc: string, history_replace: bool, skip_sniff: bool) -> bool,
}

// https://html.spec.whatwg.org/multipage/parsing.html#changing-the-encoding-while-parsing
change_encoding :: proc(p: ChangeEncodingParams) -> EncodingChangeResult {
	if ascii_eq_ci(p.old_enc^, "UTF-16LE") || ascii_eq_ci(p.old_enc^, "UTF-16BE") {
		p.confidence^ = .Certain
		return .NoChange
	}

    resolved_new := label_to_name(p.new_enc).? or_else ""
	new_enc := norm_for_change(resolved_new)
	if len(new_enc) == 0 {
		p.confidence^ = .Certain
		return .IgnoredNewEncoding
	}

	old_norm := norm_for_change(p.old_enc^)
	if ascii_eq_ci(old_norm, new_enc) {
		p.confidence^ = .Certain
		return .NoChange
	}

    // If the decoded prefix is interpreted identically under both encodings and supports on-the-fly switching, then simply switch the decoder.
	prefix_end := p.last_converted_byte_index + 1
	if prefix_end < 0 do prefix_end = 0
	if prefix_end > len(p.source_bytes) do prefix_end = len(p.source_bytes)
	prefix := p.source_bytes[:prefix_end]

	if p.supports_on_the_fly && same_unicode_prefix(prefix, old_norm, new_enc, p.decode_prefix) {
		p.old_enc^ = new_enc
		p.confidence^ = .Certain
		return .ChangedOnTheFly
	}

	if can_reparse_from_memory(p.have_full_body, p.source_bytes) {
		p.old_enc^ = new_enc
		p.confidence^ = .Certain
		p.reparse_from_memory(new_enc)
		return .RestartedFromMemory
	}

    if !ascii_eq_ci(p.request_method, "GET") {
		p.confidence^ = .Certain
		return .IgnoredNewEncoding
	}

	// historyHandling = "replace", skip_sniff = true
	p.old_enc^ = new_enc
	p.confidence^ = .Certain
	_ = p.restart_navigate_from_network(new_enc, true, true)
	return .RestartedFromNetwork
}
