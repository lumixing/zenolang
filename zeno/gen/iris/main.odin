package irisgen

import "core:fmt"
import "../../../iris"
import check "../../checker"
import "../../ast"

afmt :: fmt.aprintf

program: iris.Program
glob_idx := 0
iv_idx := 0

gen :: proc(top_stmts: []ast.TopStmt, info: ^check.Info) -> iris.Program {
	for it in top_stmts {
		#partial switch it in it {
		case ast.FuncDef:
			stmts: [dynamic]iris.Stmt
			for it in it.body {
				gen_stmt(info, &stmts, it)
			}

			program.func[it.sign.name] = {
				type = from_type(info, it.sign.return_type),
				name = it.sign.name,
				params = from_params(info, it.sign.params),
				body = stmts[:],
			}
		case ast.Directive:
			switch it in it {
			case ast.DirectiveForeign:
				program.extern[it.func_sign.name] = true
			}
		}
	}
	
	return program
}

instr :: proc(mnem: iris.InstrMnem, args: ..iris.Arg) -> (instr: iris.Instr) {
	instr.mnem = mnem

	// intentionally leaking memory
	args_dyn: [dynamic]iris.Arg
	append(&args_dyn, ..args)
	instr.args = args_dyn[:]

	return
}

local_def :: proc(name: string, type: iris.Type, value: iris.Instr) -> iris.LocalDef {
	return {
		name = name,
		type = type,
		value = value,
	}
}

gen_stmt :: proc(info: ^check.Info, stmts: ^[dynamic]iris.Stmt, stmt: ast.Stmt) {
	#partial switch stmt in stmt {
	case ast.Return:
		if value, ok := stmt.value.?; ok {
			append(stmts, instr(.ret, gen_expr(info, stmts, value)))
		} else {
			append(stmts, instr(.ret))
		}
	}
}

new_iv :: proc() -> string {
	defer iv_idx += 1
	return afmt(".iv.%d", iv_idx)
}

gen_expr :: proc(info: ^check.Info, stmts: ^[dynamic]iris.Stmt, expr: ast.Expr) -> iris.ArgValue {
	type := from_type(info, check.expr_type(info, expr))

	#partial switch expr in expr {
	case ast.Atom:
		#partial switch atom in expr {
		case ast.Literal:
			#partial switch lit in atom {
			case int:
				return {type, iris.Literal(lit)}
			}
		}
	case ^ast.Bin:
		#partial switch expr.op {
		case .Add:
			lhs := gen_expr(info, stmts, expr.lhs)
			rhs := gen_expr(info, stmts, expr.rhs)
			iv := new_iv()
			append(stmts, local_def(iv, type, instr(.add, lhs, rhs)))
			return {type, iris.Local(iv)}
		case .Mult:
			lhs := gen_expr(info, stmts, expr.lhs)
			rhs := gen_expr(info, stmts, expr.rhs)
			iv := new_iv()
			append(stmts, local_def(iv, type, instr(.mul, lhs, rhs)))
			return {type, iris.Local(iv)}
		}
	}

	return {.void, iris.Literal(int(666))}
}

from_params :: proc(info: ^check.Info, params: []ast.Param) -> []iris.Param {
	params_arr: [dynamic]iris.Param

	for it in params {
		append(&params_arr, iris.Param {
			type = from_type(info, it.type),
			value = it.name,
		})
	}

	return params_arr[:]
}

from_type :: proc(info: ^check.Info, type: ast.Type) -> iris.Type {
	switch it in type {
	case ast.Pointer:
		return from_type(info, info.type_map[uint(it)])
	case ast.Variadic:
		return from_type(info, info.type_map[uint(it)])
	case ast.BasicType:
		switch it {
		case .bool: return .i8
		case .string: return .ptr
		case .void: return .void
		case .u8: return .i8
		case .u32: return .i32
		case .i32: return .i32
		case .any: unimplemented()
		}
	case ast.UserType: unimplemented()
	}

	unimplemented()
}
