package parse

Attribute :: struct {
    name: string,
    value: string,
}

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


