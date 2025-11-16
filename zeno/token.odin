package zeno

Token :: struct {
	type: TokenType,
	value: TokenValue,
	span: Span,
}

TokenType :: enum {
	LParen,
	RParen,
	LBrace,
	RBrace,
	Comma,
	Dot,
	DotDot,
	Hash,
	Caret = '^', // omg pls try this idea i beg you
	Eq,

	Ident,
	String,
	Integer,
	
	KW_string,
	KW_void,
	KW_any,
	KW_u8,
	KW_u32,
	KW_bool,
	KW_true,
	KW_false,
	KW_for,
	KW_if,
	KW_return,

	Newline,
	EOF,
}

TokenValue :: union {
	string,
	int,
}

Span :: struct {
	lo, hi: uint,
}
