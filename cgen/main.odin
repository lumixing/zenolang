package cc

import "core:fmt"
import "core:strings"

State :: struct {
	lines:        [dynamic]string,
	type_map:     map[Pointer]Type,
	type_map_ptr: Pointer,
}

unreach :: proc(loc := #caller_location) -> ! {
	panic("!!! unimplemented !!!", loc = loc)
}

main :: proc() {
	state: State

	include(&state, "stdint.h", .Bracket)
	include(&state, "stdio.h", .Bracket)
	newline(&state)

	func_sign(&state, .int, "main", {
		{.int, "argc"},
		{type_ptr(&state, type_ptr(&state, .char)), "argv"}
	}, .Brace)

	for_(&state, 1, {.int, "i", {0}}, {"i", .LessThan, 10}, {"i", .Inc})

	func_call(&state, 2, "printf", {
		{Literal("%d -> %s\n")},
		{"i"},
		{Index{{"argv"}, {"i"}}},
	})

	brace(&state, 1)
	newline(&state)

	ret_expr(&state, 1, {0})

	brace(&state)

	for line in state.lines {
		fmt.println(line)
	}
}

for_ :: proc(state: ^State, depth: uint, init: VarDef, cond: Expr, iter: Expr) {
	append(&state.lines, fmt.aprintf(
		"%sfor(%s; %s; %s) {{",
		indent(depth),
		var_def_str(state, init),
		expr_str(state, cond),
		expr_str(state, iter),
	))
}

while :: proc(state: ^State, depth: uint, cond: Expr) {
	append(&state.lines, fmt.aprintf(
		"%swhile(%s) {{",
		indent(depth),
		expr_str(state, cond),
	))
}

// for nesting (elseif/else) we could do if_(ifs: []{cond, body})
if_ :: proc(state: ^State, depth: uint, cond: Expr) {
	append(&state.lines, fmt.aprintf(
		"%sif(%s) {{",
		indent(depth),
		expr_str(state, cond),
	))
}

assign :: proc(state: ^State, depth: uint, lhs, rhs: Expr) {
	append(&state.lines, fmt.aprintf(
		"%s%s = %s;",
		indent(depth),
		expr_str(state, lhs),
		expr_str(state, rhs),
	))
}

VarDef :: struct {
	type:  Type,
	name:  string,
	value: Expr,
}

var_def :: proc(state: ^State, depth: uint, type: Type, name: string, value: Expr) {
	append(&state.lines, afmt("%s%s;", indent(depth), var_def_str(state, {type, name, value})))
}

var_def_str :: proc(state: ^State, var_def: VarDef) -> string {
	return fmt.aprintf(
		"%s %s = %s",
		str_type(state, var_def.type),
		var_def.name,
		expr_str(state, var_def.value),
	)
}

IncludeType :: enum {
	Quote,
	Bracket,
}

include :: proc(state: ^State, path: string, type: IncludeType) {
	switch type {
	case .Quote:
		append(&state.lines, fmt.aprintf("#include \"%s\"", path))
	case .Bracket:
		append(&state.lines, fmt.aprintf("#include <%s>", path))
	}
}

newline :: proc(state: ^State) {
	append(&state.lines, "")
}

brace :: proc(state: ^State, depth: uint = 0) {
	append(&state.lines, fmt.aprintf("%s}", indent(depth)))
}

FuncSignEnding :: enum {
	Semicolon,
	Brace,
}

func_sign :: proc(state: ^State, ret_type: Type, name: string, params: []Param, ending: FuncSignEnding) {
	switch ending {
	case .Semicolon:
		append(&state.lines, fmt.aprintf("%s %s(%s);", str_type(state, ret_type), name, str_params(state, params)))
	case .Brace:
		append(&state.lines, fmt.aprintf("%s %s(%s) {{", str_type(state, ret_type), name, str_params(state, params)))
	}
}

func_call :: proc(state: ^State, depth: uint, name: string, args: []Expr) {
	append(&state.lines, fmt.aprintf("%s%s(%s);", indent(depth), name, args_str(state, args)))
}

ret :: proc(state: ^State, depth: uint) {
	append(&state.lines, fmt.aprintf("%sreturn;", indent(depth)))
}

ret_expr :: proc(state: ^State, depth: uint, expr: Expr) {
	append(&state.lines, fmt.aprintf("%sreturn %s;", indent(depth), expr_str(state, expr)))
}

indent :: proc(depth: uint) -> string {
	return strings.repeat("\t", int(depth))
}
