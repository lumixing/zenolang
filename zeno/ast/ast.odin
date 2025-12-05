package ast

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

Pointer  :: distinct ^Type
Variadic :: distinct ^Type

BasicType :: enum {
	bool,
	string,
	u8,
	u32,
	i32,
	void,
	any,
}

UserType :: distinct string

FuncDef :: struct {
	sign: FuncSign,
	body: Block,
}

Scope :: struct {
	parent_scope: ^Scope,
	funcs: map[string]FuncSign,
	vars:  map[string]VarDef,
}

Block :: struct {
	stmts: []Stmt,

	scope: Maybe(Scope),
}

// @todo: add #no_nil
Stmt :: union {
	FuncCall,
	Return,
	VarDef,
	While,
	If,
	Assign,
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

While :: struct {
	cond: Expr,
	body: Block,
}

If :: struct {
	cond: Expr,
	body: Block,
}

Assign :: struct {
	lhs: Expr,
	rhs: Expr,
}

Expr :: union #no_nil {
	^Expr,
	Atom,
	^Un,
	^Bin,
}

Atom :: union #no_nil {
	Ident,
	Literal,
	FuncCall,
}

Ident :: distinct string

Literal :: union #no_nil {
	string,
	int,
	bool,
}

Op :: union #no_nil {
	Unop,
	Binop,
}

Un :: struct {
	op: Unop,
	expr: Expr,
}

Unop :: enum {
	BW_Not,
	Neg,
	Deref,
}

Bin :: struct {
	op: Binop,
	lhs: Expr,
	rhs: Expr,
}

Binop :: enum {
	Add,
	Sub,
	Mult,
	LessThan,
	GreaterThan,
	Eq,
}

prefix_bp :: proc(op: Op) -> u8 {
	#partial switch it in op {
	case Unop:
		switch it {
		case .Neg, .BW_Not, .Deref:
			return 9
		}
	}

	panic("you did something very VERY wrong")
}

infix_bp :: proc(op: Op) -> (u8, u8) {
	#partial switch op in op {
	case Binop:
		switch op {
		case .Eq:
			return 1, 2
		case .LessThan, .GreaterThan:
			return 3, 4
		case .Add, .Sub:
			return 5, 6
		case .Mult:
			return 7, 8
		}
	}

	panic("you did something very VERY wrong")
}
