package parse

InsertionMode :: enum {
	Initial,
	BeforeHtml,
	BeforeHead,
	InHead,
	InHeadNoscript,
	AfterHead,
	InBody,
	Text,
	InTable,
	InTableText,
	InCaption,
	InColumnGroup,
	InTableBody,
	InRow,
	InCell,
	InTemplate,
	AfterBody,
	InFrameset,
	AfterFrameset,
	AfterAfterBody,
	AfterAfterFrameset,
}

Parser :: struct {
    // insertion mode
    ins_mode: InsertionMode,
    // original insertion mode
    orig_ins_mode: InsertionMode,
    // template insertion mode
    temp_insert_modes: [dynamic]InsertionMode,
    // current insertion mode
    cur_temp_insert_modes: int, 
}

// https://html.spec.whatwg.org/multipage/parsing.html#reset-the-insertion-mode-appropriately
reset_insertion_mode_appropriately :: proc(parser: ^Parser) {
    last := false
} 

handle_token :: proc(t: Token) {

}
