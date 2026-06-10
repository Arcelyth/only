package parse

ParseErrorProc :: #type proc(err: ParseError, c: rune)

ParseError :: enum {
    SurrogateInInputStream,
    NoncharacterInInputStream,
    ControlCharacterInInputStream,
    UnexpectedNullCharacter,
    EofBeforeTagName,
    UnexpectedQuestionMarkInsteadOfTagName,
    InvalidFirstCharacterOfTagName,
    MissingEndTagName,
    EofInTag,
    EofInScriptHtmlCommentLikeText,
    UnexpectedEqualsSignBeforeAttributeName,
    UnexpectedCharacterInAttributeName,
    MissingAttributeValue,
    MissingWhitespaceBetweenAttributes,
    UnexpectedSolidusInTag,
    DuplicateAttribute,
    UnexpectedCharacterInUnquotedAttributeValue,
    IncorrectlyOpenedComment,
    IncorrectlyClosedComment,
    AbruptClosingOfEmptyComment,
    EofInComment,
    NestedComment,
    EofInDOCTYPE,
    MissingWhitespaceBeforeDOCTYPEName,
    MissingDOCTYPEName,
    InvalidCharacterSequenceAfterDOCTYPEName,
    MissingWhitespaceAfterDOCTYPEPublicKeyword,
    MissingDOCTYPEPublicIdentifier,
    MissingQuoteBeforeDOCTYPEPublicIdentifier,
    AbruptDOCTYPEPublicIdentifier,
}


