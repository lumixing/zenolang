package cc

import "core:strings"
import "core:fmt"

afmt :: fmt.aprintf

// removing this distinct has a chance of a compiler assertion failure!!!
// veeery weird bug i reported
Expr :: distinct []ExprAtom

expr_str :: proc(state: ^State, expr: Expr) -> string {
	atom_str: [dynamic]string

	for atom in expr {
		append(&atom_str, expr_atom_str(state, atom))
	}

	return strings.join(atom_str[:], " ")
}

ExprAtom :: union #no_nil {
	Expr,  // paren
	Literal,
	Ident,
	Unop,
	Binop,
	Index,
	FuncCall,
	Ternary,
	Assign,
	Cast,
}

expr_atom_str :: proc(state: ^State, expr_atom: ExprAtom) -> string {
	switch atom in expr_atom {
	case Expr:     return afmt("(%s)", expr_str(state, atom))
	case Literal:  return literal_str(atom)
	case Ident:    return afmt("%s", atom)
	case Unop:     return unop_str(atom)
	case Binop:    return binop_str(atom)
	case Index:    return index_str(state, atom)
	case FuncCall: return func_call_str(state, atom)
	case Ternary:  return ternary_str(state, atom)
	case Assign:   return assign_str(state, atom)
	case Cast:     return cast_str(state, atom)
	}

	unreach()
}

Literal :: union #no_nil {
	string,
	int,
	bool,
}

literal_str :: proc(lit: Literal) -> string {
	switch lit in lit {
	case string:
		return afmt("%q", lit)
	case int:
		return afmt("%d", lit)
	case bool:
		return afmt("%s", lit ? "true" : "false")
	}

	unreach()
}

Ident :: distinct string

Unop :: enum {
	Not,
	Neg,
	Inc,
	Decr,
	Deref,
	Field,
	DerefField,
}

unop_str :: proc(unop: Unop) -> string {
	switch unop {
	case .Not:        return "!"
	case .Neg:        return "-"
	case .Inc:        return "++"
	case .Decr:       return "--"
	case .Deref:      return "*"
	case .Field:      return "."
	case .DerefField: return "->"
	}

	unreach()
}

Binop :: enum {
	Add,
	Mult,
	Div,

	BW_And,
	BW_Or,
	BW_RShift,

	LessThan,
	GreaterThan,
}

binop_str :: proc(binop: Binop) -> string {
	switch binop {
	case .Add:       return "+"
	case .Mult:      return "*"
	case .Div:       return "/"
	case .BW_And:    return "&"
	case .BW_Or:     return "|"
	case .BW_RShift: return ">>"
	case .LessThan:  return "<"
	case .GreaterThan:  return ">"
	}

	unreach()
}

//Paren :: distinct Expr

Index :: struct {
	value: Expr,
	index: Expr,
}

index_str :: proc(state: ^State, index: Index) -> string {
	return afmt(
		"%s[%s]",
		expr_str(state, index.value),
		expr_str(state, index.index),
	)
}

FuncCall :: struct {
	name: string,
	args: []Expr,
}

func_call_str :: proc(state: ^State, call: FuncCall) -> string {
	return afmt("%s(%s)", call.name, args_str(state, call.args))
}

args_str :: proc(state: ^State, args: []Expr) -> string {
	args_str: [dynamic]string

	for arg in args {
		append(&args_str, expr_str(state, arg))
	}

	return strings.join(args_str[:], ", ")
}

Ternary :: struct {
	cond:  Expr,
	true:  Expr,
	false: Expr,
}

ternary_str :: proc(state: ^State, tern: Ternary) -> string {
	return afmt(
		"%s ? %s : %s",
		expr_str(state, tern.cond),
		expr_str(state, tern.true),
		expr_str(state, tern.false),
	)
}

Assign :: struct {
	lhs: Expr,
	rhs: Expr,
}

assign_str :: proc(state: ^State, assign: Assign) -> string {
	return afmt(
		"%s = %s",
		expr_str(state, assign.lhs),
		expr_str(state, assign.rhs),
	)
}

Cast :: struct {
	type: Type,
	expr: Expr,
}

cast_str :: proc(state: ^State, cast_: Cast) -> string {
	return afmt(
		"(%s)%s",
		str_type(state, cast_.type),
		expr_str(state, cast_.expr),
	)
}
