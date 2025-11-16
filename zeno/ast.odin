package zeno

// @todo: add #no_nil
TopStmt :: union {
	FuncDef,
	Directive,
}

FuncSign :: struct {
	name:        string,
	params:      []Param,
	return_type: Type,
}

// @todo: add #no_nil
Directive :: union {
	DirectiveForeign,
}

DirectiveForeign :: struct {
	filename:  string,
	func_sign: FuncSign,
}

Param :: struct {
	name: string,
	type: Type,
}

Type :: union #no_nil {
	Pointer,
	Variadic,
	BasicType,
	UserType,
}

Pointer :: distinct uint
Variadic :: distinct uint

BasicType :: enum {
	bool,
	string,
	u8,
	u32,
	void,
	any,
}

UserType :: distinct string

FuncDef :: struct {
	sign: FuncSign,
	body: Block,
}

Block :: []Stmt

// @todo: add #no_nil
Stmt :: union {
	FuncCall,
	Return,
	VarDef,
}

FuncCall :: struct {
	name: string,
	args: []Expr,
}

Return :: struct {
	value: Maybe(Expr),
}

VarDef :: struct {
	name: string,
	type: Type,
	value: Expr,
}

Expr :: distinct []ExprAtom

ExprAtom :: union #no_nil {
	Expr,
	Literal,
	Ident,
	FuncCall,
	Unop, // i just had a revolation, what if Unop/Binop was distinct Expr
}

Literal :: union #no_nil {
	string,
	int,
	bool,
}

Ident :: distinct string

Unop :: enum {
	Not,
}
