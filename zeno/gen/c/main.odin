package cgen

import "core:fmt"
import "core:c/libc"
import "core:strings"
import "core:os"
import "../../ast"
import "../../../cgen"
import check "../../checker"

gen :: proc(top_stmts: []ast.TopStmt, info: ^check.Info) {
	state: cgen.State
	includes: map[string]bool

	includes["stdint.h"] = true

	cgen.include(&state, "stdint.h", .Bracket)
	includes["stdbool.h"] = true
	cgen.include(&state, "stdbool.h", .Bracket)

	// includes
	for top_stmt in top_stmts[:] {
		#partial switch tstmt in top_stmt {
		case ast.Directive:
			switch dir in tstmt {
			case ast.DirectiveForeign:
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
	for top_stmt in top_stmts[:] {
		#partial switch tstmt in top_stmt {
		case ast.FuncDef:
			cgen.func_sign(
				&state,
				type_to_c(info, &state, tstmt.sign.return_type),
				tstmt.sign.name,
				params_to_c_params(info, &state, tstmt.sign.params),
				.Semicolon,
			)
		}
	}
	cgen.newline(&state)

	// func defs
	for top_stmt in top_stmts[:] {
		#partial switch tstmt in top_stmt {
		case ast.FuncDef:
			cgen.func_sign(
				&state,
				type_to_c(info, &state, tstmt.sign.return_type),
				tstmt.sign.name,
				params_to_c_params(info, &state, tstmt.sign.params),
				.Brace,
			)

			gen_block(info, &state, tstmt.body, 1)

			cgen.brace(&state)
			cgen.newline(&state)
		}
	}

	assert(os.write_entire_file("main.c", transmute([]u8)strings.join(state.lines[:], "\n")))

	libc.system(`gcc main.c -o out -L"C:\Users\lumix\scoop\apps\raylib-mingw\5.5\raylib-5.5_win64_mingw-w64\lib" -lraylib -lopengl32 -lgdi32 -lwinmm && out.exe`)
}

gen_block :: proc(info: ^check.Info, state: ^cgen.State, block: ast.Block, depth: uint) {
	for stmt in block {
		switch stmt in stmt {
		case ast.Assign:
			cgen.assign(
				state, depth,
				expr_to_c(state, stmt.lhs),
				expr_to_c(state, stmt.rhs),
			)
		case ast.While:
			cgen.while(state, depth, expr_to_c(state, stmt.cond))
			gen_block(info, state, stmt.body, depth + 1)
			cgen.brace(state, depth)
		case ast.If:
			cgen.if_(state, depth, expr_to_c(state, stmt.cond))
			gen_block(info, state, stmt.body, depth + 1)
			cgen.brace(state, depth)
		case ast.FuncCall:
			cgen.func_call(state, depth, stmt.name, args_to_c(state, stmt.args))
		case ast.VarDef:
			cgen.var_def(
				state, depth,
				type_to_c(info, state, stmt.type),
				stmt.name,
				expr_to_c(state, stmt.value),
			)
		case ast.Return:
			if value, ok := stmt.value.?; ok {
				cgen.ret_expr(state, depth, expr_to_c(state, value))
			} else {
				cgen.ret(state, depth)
			}
		}
	}
}

param_to_c_param :: proc(info: ^check.Info, state: ^cgen.State, param: ast.Param) -> cgen.Param {
	return {
		name = param.name,
		type = type_to_c(info, state, param.type),
	}
}

params_to_c_params :: proc(info: ^check.Info, state: ^cgen.State, params: []ast.Param) -> []cgen.Param {
	c_params: [dynamic]cgen.Param

	for param in params {
		append(&c_params, param_to_c_param(info, state, param))
	}

	return c_params[:]
}

args_to_c :: proc(state: ^cgen.State, args: []ast.Expr) -> []cgen.Expr {
	c_args: [dynamic]cgen.Expr

	for expr in args {
		append(&c_args, expr_to_c(state, expr))
	}

	return c_args[:]
}

expr_to_c :: proc(state: ^cgen.State, expr: ast.Expr) -> cgen.Expr {
	atoms: [dynamic]cgen.ExprAtom

	switch it in expr {
	case ^ast.Expr:
		append(&atoms, expr_to_c(state, it^))  // cheecky fucking deref
	case ast.Atom:
		switch atom in it {
		case ast.Ident:
			append(&atoms, cgen.Ident(atom))
		case ast.Literal:
			switch lit in atom {
			case string:
				append(&atoms, cgen.Literal(lit))
			case int:
				append(&atoms, cgen.Literal(lit))
			case bool:
				append(&atoms, cgen.Literal(lit))
			}
		case ast.FuncCall:
			append(&atoms, cgen.FuncCall {
				name = atom.name,
				args = args_to_c(state, atom.args),
			})
		}
	case ^ast.Un:
		switch it.op {
		case .Neg:
			append(&atoms, cgen.Unop.Neg)
			append(&atoms, expr_to_c(state, it.expr))
		case .BW_Not:
			append(&atoms, cgen.Unop.BW_Not)
			append(&atoms, expr_to_c(state, it.expr))
		case .Deref:
			append(&atoms, cgen.Unop.Deref)
			append(&atoms, expr_to_c(state, it.expr))
		}
	case ^ast.Bin:
		// we can very easily DRY this
		switch it.op {
		case .Eq:
			append(&atoms, expr_to_c(state, it.lhs))
			append(&atoms, cgen.Binop.Eq)
			append(&atoms, expr_to_c(state, it.rhs))
		case .Add:
			append(&atoms, expr_to_c(state, it.lhs))
			append(&atoms, cgen.Binop.Add)
			append(&atoms, expr_to_c(state, it.rhs))
		case .Sub:
			append(&atoms, expr_to_c(state, it.lhs))
			append(&atoms, cgen.Binop.Sub)
			append(&atoms, expr_to_c(state, it.rhs))
		case .Mult:
			append(&atoms, expr_to_c(state, it.lhs))
			append(&atoms, cgen.Binop.Mult)
			append(&atoms, expr_to_c(state, it.rhs))
		case .LessThan:
			append(&atoms, expr_to_c(state, it.lhs))
			append(&atoms, cgen.Binop.LessThan)
			append(&atoms, expr_to_c(state, it.rhs))
		case .GreaterThan:
			append(&atoms, expr_to_c(state, it.lhs))
			append(&atoms, cgen.Binop.GreaterThan)
			append(&atoms, expr_to_c(state, it.rhs))
		}
	}

	return cgen.Expr(atoms[:])
}

type_to_c :: proc(info: ^check.Info, state: ^cgen.State, type: ast.Type) -> cgen.Type {
	switch type in type {
	case ast.Variadic: unimplemented()
	case ast.Pointer:
		ptype := type_to_c(info, state, info.type_map[uint(type)])
		return cgen.type_ptr(state, ptype)
	case ast.BasicType:
		switch type {
		case .void:   return .void
		case .string: return cgen.type_ptr(state, .char)
		case .u8:     return .uint8_t
		case .u32:    return .uint32_t
		case .i32:    return .int32_t
		case .bool:   return .bool
		case .any:    unimplemented()
		}
	case ast.UserType: unimplemented()
	}

	unimplemented()
}
