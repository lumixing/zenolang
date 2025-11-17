package zeno

import "core:strings"
import "core:os"
import "core:c/libc"
import "core:fmt"
import "../cgen"

FILE :: "hello.zn"

main :: proc() {
	file := #load("../" + FILE)
	lexer: Lexer
	err := lexer_scan(&lexer, file)
	if err, ok := err.?; ok {
		fmt.println(err.message)
		return
	}

	info: Info

	//for token in lexer.tokens {
	//	fmt.println(token)
	//}

	prs: Parser
	err2 := prs_parse(&prs, &info, lexer.tokens[:])
	if err, ok := err2.?; ok {
		line, col := span_to_line_col(file, prs.tokens[err.span.hi].span)
		fmt.printfln(FILE + ":%d:%d: %s\n(%v)", line, col, err.message, err.loc)
		return
	}
	//fmt.printfln("%#v", prs.top_stmts[:])

	err3 := check(&info, prs.top_stmts[:])
	if err, ok := err3.?; ok {
		fmt.println(err.message)
		return
	}
	//fmt.println("done")

	state: cgen.State
	includes: map[string]bool

	includes["stdint.h"] = true
	cgen.include(&state, "stdint.h", .Bracket)
	includes["stdbool.h"] = true
	cgen.include(&state, "stdbool.h", .Bracket)

	// includes
	for top_stmt in prs.top_stmts[:] {
		#partial switch tstmt in top_stmt {
		case Directive:
			switch dir in tstmt {
			case DirectiveForeign:
				if dir.filename[0] == '!' {
					if dir.filename[1:] not_in includes {
						includes[dir.filename[1:]] = true
						cgen.include(&state, dir.filename[1:], .Quote)
					}
				} else {
					if dir.filename not_in includes {
						includes[dir.filename] = true
						cgen.include(&state, dir.filename, .Bracket)
					}
				}
			}
		}
	}
	cgen.newline(&state)

	// func signs
	for top_stmt in prs.top_stmts[:] {
		#partial switch tstmt in top_stmt {
		case FuncDef:
			cgen.func_sign(
				&state,
				type_to_c(&info, &state, tstmt.sign.return_type),
				tstmt.sign.name,
				params_to_c_params(&info, &state, tstmt.sign.params),
				.Semicolon,
			)
		}
	}
	cgen.newline(&state)

	// func defs
	for top_stmt in prs.top_stmts[:] {
		#partial switch tstmt in top_stmt {
		case FuncDef:
			cgen.func_sign(
				&state,
				type_to_c(&info, &state, tstmt.sign.return_type),
				tstmt.sign.name,
				params_to_c_params(&info, &state, tstmt.sign.params),
				.Brace,
			)

			gen_block(&info, &state, tstmt.body, 1)

			cgen.brace(&state)
			cgen.newline(&state)
		}
	}

	assert(os.write_entire_file("main.c", transmute([]u8)strings.join(state.lines[:], "\n")))

	libc.system(`gcc main.c -o out -L"C:\Users\lumix\scoop\apps\raylib-mingw\5.5\raylib-5.5_win64_mingw-w64\lib" -lraylib -lopengl32 -lgdi32 -lwinmm && out.exe`)
}

gen_block :: proc(info: ^Info, state: ^cgen.State, block: Block, depth: uint) {
	for stmt in block {
		switch stmt in stmt {
		case Assign:
			cgen.assign(
				state, depth,
				expr_to_c(state, stmt.lhs),
				expr_to_c(state, stmt.rhs),
			)
		case While:
			cgen.while(state, depth, expr_to_c(state, stmt.cond))
			gen_block(info, state, stmt.body, depth + 1)
			cgen.brace(state, depth)
		case If:
			cgen.if_(state, depth, expr_to_c(state, stmt.cond))
			gen_block(info, state, stmt.body, depth + 1)
			cgen.brace(state, depth)
		case FuncCall:
			cgen.func_call(state, depth, stmt.name, args_to_c(state, stmt.args))
		case VarDef:
			cgen.var_def(
				state, depth,
				type_to_c(info, state, stmt.type),
				stmt.name,
				expr_to_c(state, stmt.value),
			)
		case Return:
			if value, ok := stmt.value.?; ok {
				cgen.ret_expr(state, depth, expr_to_c(state, value))
			} else {
				cgen.ret(state, depth)
			}
		}
	}
}

param_to_c_param :: proc(info: ^Info, state: ^cgen.State, param: Param) -> cgen.Param {
	return {
		name = param.name,
		type = type_to_c(info, state, param.type),
	}
}

params_to_c_params :: proc(info: ^Info, state: ^cgen.State, params: []Param) -> []cgen.Param {
	c_params: [dynamic]cgen.Param

	for param in params {
		append(&c_params, param_to_c_param(info, state, param))
	}

	return c_params[:]
}

args_to_c :: proc(state: ^cgen.State, args: []Expr) -> []cgen.Expr {
	c_args: [dynamic]cgen.Expr

	for expr in args {
		append(&c_args, expr_to_c(state, expr))
	}

	return c_args[:]
}

expr_to_c :: proc(state: ^cgen.State, expr: Expr) -> cgen.Expr {
	atoms: [dynamic]cgen.ExprAtom

	for atom in expr {
		append(&atoms, expr_atom_to_c(state, atom))
	}

	return cgen.Expr(atoms[:])
}

expr_atom_to_c :: proc(state: ^cgen.State, expr_atom: ExprAtom) -> cgen.ExprAtom {
	switch atom in expr_atom {
	case Expr:
		return cgen.Expr(expr_to_c(state, atom))
	case Unop:
		switch atom {
		case .Not: return .Not
		case .Neg: return .Neg
		}
	case Binop:
		switch atom {
		case .Add: return .Add
		case .LessThan: return .LessThan
		case .GreaterThan: return .GreaterThan
		}
	case Literal:
		switch lit in atom {
		case string: return cgen.Literal(lit)
		case int:    return cgen.Literal(lit)
		case bool:   return cgen.Literal(lit)
		}
	case Ident:
		return cgen.Ident(atom)
	case FuncCall:
		return cgen.FuncCall{
			name = atom.name,
			args = args_to_c(state, atom.args),
		}
	}

	unreachable()
}

type_to_c :: proc(info: ^Info, state: ^cgen.State, type: Type) -> cgen.Type {
	switch type in type {
	case Variadic: unimplemented()
	case Pointer:
		ptype := type_to_c(info, state, info.type_map[uint(type)])
		return cgen.type_ptr(state, ptype)
	case BasicType:
		switch type {
		case .void:   return .void
		case .string: return cgen.type_ptr(state, .char)
		case .u8:     return .uint8_t
		case .u32:    return .uint32_t
		case .i32:    return .int32_t
		case .bool:   return .bool
		case .any:    unimplemented()
		}
	case UserType: unimplemented()
	}

	unreachable()
}
