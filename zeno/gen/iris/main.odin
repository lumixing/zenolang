package irisgen

import "core:fmt"
import "../../../iris"
import check "../../checker"
import "../../ast"

afmt :: fmt.aprintf

tstmts: [dynamic]iris.TopStmt
glob_idx := 0
iv_idx := 0

gen :: proc(top_stmts: []ast.TopStmt, info: ^check.Info) -> []iris.TopStmt {
	for it in top_stmts {
		#partial switch it in it {
		case ast.FuncDef:
			stmts: [dynamic]iris.Stmt
			for it in it.body {
				gen_stmt(info, &stmts, it)
			}

			append(&tstmts, iris.Func{
				type = from_type(info, it.sign.return_type),
				name = it.sign.name,
				params = from_params(info, it.sign.params),
				body = stmts[:],
			})
		case ast.Directive:
			switch it in it {
			case ast.DirectiveForeign:
				append(&tstmts, iris.Extern{it.func_sign.name, false})
			}
		}
	}
	
	return tstmts[:]
}

instr :: proc(mnem: iris.Mnemonic, args: ..iris.Arg) -> (instr: iris.Instr) {
	instr.mnem = mnem

	// intentionally leaking memory
	args_dyn: [dynamic]iris.Arg
	append(&args_dyn, ..args)
	instr.args = args_dyn[:]

	return
}

data :: proc(name: string, args: ..iris.DataValue) -> (d: iris.Data) {
	d.name = name

	args_dyn: [dynamic]iris.DataValue
	append(&args_dyn, ..args)
	d.data = args_dyn[:]

	return
}

local_def :: proc(name: string, type: iris.Type, value: iris.LocalDefValue) -> iris.LocalDef {
	return {
		name = name,
		type = type,
		value = value,
	}
}

gen_stmt :: proc(info: ^check.Info, stmts: ^[dynamic]iris.Stmt, stmt: ast.Stmt) {
	#partial switch it in stmt {
	case ast.Return:
		if it, ok := it.value.?; ok {
			append(stmts, instr(.ret, {.i32, gen_expr(info, stmts, it)}))
		} else {
			append(stmts, instr(.ret))
		}
	case ast.VarDef:
		iv := gen_expr(info, stmts, it.value)
		append(stmts, iris.LocalDef {
			name = it.name,
			type = from_type(info, it.type),
			value = instr(.copy, {.i32, iris.Local(iv)}),
		})
	case ast.FuncCall:
		args: [dynamic]iris.Arg
		for it in it.args {
			iv := gen_expr(info, stmts, it)
			append(&args, iris.Arg{.i32, iv})
		}
		append(stmts, iris.Call {
			name = it.name,
			args = args[:],
		})
	case: fmt.println("!! unimpl", it)
	}
}

gen_expr :: proc(info: ^check.Info, stmts: ^[dynamic]iris.Stmt, expr: ast.Expr) -> iris.Local {
	switch it in expr {
	case ^ast.Expr: unimplemented()
	case ast.Atom:
		switch it in it {
		case ast.Ident:
			// todo: find correct type instead of i32
			iv := new_iv()
			append(stmts, local_def(iv, .i32, instr(.copy, {.i32, iris.Local(it)})))
			return iris.Local(iv)
		case ast.Literal:
			switch it in it {
			case int:
				iv := new_iv()
				append(stmts, local_def(iv, .i32, instr(.copy, {.i32, iris.Literal(it)})))
				return iris.Local(iv)
			case bool: unimplemented()
			case string:
				iv := new_iv()
				append(&tstmts, data("str", {.i8, it}, {.i8, 0}))
				append(stmts, local_def(iv, .i32, instr(.copy, {.i32, iris.Global("str")})))
				return iris.Local(iv)
			}
		case ast.FuncCall: unimplemented()
		}
	case ^ast.Un: unimplemented()
	case ^ast.Bin:
		#partial switch it.op {
		case .Add:
			iv1 := gen_expr(info, stmts, it.lhs)
			iv2 := gen_expr(info, stmts, it.rhs)
			append(stmts, instr(.add, {.i32, iris.Local(iv1)}, {.i32, iris.Local(iv2)}))
			return iris.Local(iv1)
		case .Mult:
			iv1 := gen_expr(info, stmts, it.lhs)
			iv2 := gen_expr(info, stmts, it.rhs)
			append(stmts, instr(.mul, {.i32, iris.Local(iv1)}, {.i32, iris.Local(iv2)}))
			return iris.Local(iv1)
		case: unimplemented()
		}
	}

	unimplemented()
}

new_iv :: proc() -> string {
	defer iv_idx += 1
	return afmt(".iv.%d", iv_idx)
}

expr_arg :: proc(expr: ast.Expr) -> iris.Arg {
	#partial switch it in expr {
	case ast.Atom:
		#partial switch it in it {
		case ast.Literal:
			#partial switch it in it {
			case int: return {.i32, iris.Literal(it)}
			}
		}
	case ^ast.Bin:
		fmt.println(it)
		unimplemented("oops!")
	}

	unimplemented()
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
