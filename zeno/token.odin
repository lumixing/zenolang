package zeno

import "diagn"

Token :: struct {
	type: TokenType,
	value: TokenValue,
	span: diagn.Span,
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
	EqEq,
	Exclaim,
	Plus,
	Asterisk,
	Hyphen,

	LessThan,
	GreaterThan,

	Ident,
	String,
	Integer,
	
	KW_string,
	KW_void,
	KW_any,
	KW_u8,
	KW_u32,
	KW_i32,
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
