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

Pointer :: distinct uint
Variadic :: distinct uint

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

Block :: []Stmt

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
}

prefix_bp :: proc(op: Op) -> u8 {
	#partial switch it in op {
	case Unop:
		switch it {
		case .Neg, .BW_Not:
			return 7
		}
	}

	panic("you did something very VERY wrong")
}

infix_bp :: proc(op: Op) -> (u8, u8) {
	#partial switch op in op {
	case Binop:
		switch op {
		case .LessThan, .GreaterThan:
			return 1, 2
		case .Add, .Sub:
			return 3, 4
		case .Mult:
			return 5, 6
		}
	}

	panic("you did something very VERY wrong")
}
