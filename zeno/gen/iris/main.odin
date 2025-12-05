package irisgen

import "../../../iris"
import "../../ast"
import check "../../checker"
import "core:fmt"

afmt :: fmt.aprintf

program: iris.Program
glob_idx := 0
iv_idx := 0

gen :: proc(top_stmts: []ast.TopStmt, info: ^check.Info) -> iris.Program {
	for it in top_stmts {
		#partial switch it in it {
		case ast.FuncDef:
			stmts: [dynamic]iris.Stmt
			//fmt.printfln("%#v", it.body.scope)
			for stmt in it.body.stmts {
				gen_stmt(&stmts, stmt, it.body.scope.?)
			}

			program.func[it.sign.name] = {
				type   = from_type(it.sign.return_type),
				name   = it.sign.name,
				params = from_params(it.sign.params),
				body   = stmts[:],
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

call :: proc(name: string, args: []iris.Arg) -> (instr: iris.Instr) {
	instr.mnem = .call

	args_dyn: [dynamic]iris.Arg
	append(&args_dyn, iris.ArgValue{.ptr, iris.Global(name)})
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

gen_stmt :: proc(stmts: ^[dynamic]iris.Stmt, stmt: ast.Stmt, scope: ast.Scope) {
	#partial switch stmt in stmt {
	case ast.While:
		append(stmts, iris.Label("loop"))
		cond := gen_expr(stmts, stmt.cond, scope)
		append(stmts, instr(.jnz, cond, iris.Label("body"), iris.Label("break")))
		append(stmts, iris.Label("body"))
		for istmt in stmt.body.stmts {
			gen_stmt(stmts, istmt, stmt.body.scope.?)
		}
		append(stmts, instr(.jmp, iris.Label("loop")))
		append(stmts, iris.Label("break"))
	case ast.VarDef:
		value := instr(.copy, gen_expr(stmts, stmt.value, scope))
		append(stmts, local_def(stmt.name, from_type(stmt.type), value))
	case ast.Return:
		if value, ok := stmt.value.?; ok {
			append(stmts, instr(.ret, gen_expr(stmts, value, scope)))
		} else {
			append(stmts, instr(.ret))
		}
	case ast.FuncCall:
		func_name := iris.ArgValue{.ptr, iris.Global(stmt.name)}
		append(stmts, call(stmt.name, from_args(stmts, stmt.args, scope)))
	case:
		fmt.println("unimpl", stmt)
		unimplemented()
	}
}

new_iv :: proc() -> string {
	defer iv_idx += 1
	return afmt(".iv.%d", iv_idx)
}

data :: proc(name: string, args: ..iris.DataValue) -> (d: iris.Data) {
	d.name = name

	args_dyn: [dynamic]iris.DataValue
	append(&args_dyn, ..args)
	d.data = args_dyn[:]

	return
}

gen_expr :: proc(stmts: ^[dynamic]iris.Stmt, expr: ast.Expr, scope: ast.Scope) -> iris.ArgValue {
	type := from_type(check.expr_type(expr, scope))

	#partial switch expr in expr {
	case ast.Atom:
		switch atom in expr {
		case ast.Literal:
			switch lit in atom {
			case int:
				return {type, iris.Literal(lit)}
			case bool:
				return {type, iris.Literal(int(lit ? 1 : 0))}
			case string:
				iv := new_iv()
				program.data[iv] = data(iv, {.i8, lit}, {.i8, iris.Literal(int(0))})
				return {type, iris.Global(iv)}
			}
		case ast.Ident:
			return {type, iris.Local(atom)}
		case ast.FuncCall:
			func_name := iris.ArgValue{.ptr, iris.Global(atom.name)}
			iv := new_iv()
			append(stmts, local_def(iv, type, call(atom.name, from_args(stmts, atom.args, scope))))
			return {type, iris.Local(iv)}
		}
	case ^ast.Bin:
		#partial switch expr.op {
		case .Add:
			lhs := gen_expr(stmts, expr.lhs, scope)
			rhs := gen_expr(stmts, expr.rhs, scope)
			iv := new_iv()
			append(stmts, local_def(iv, type, instr(.add, lhs, rhs)))
			return {type, iris.Local(iv)}
		case .Mult:
			lhs := gen_expr(stmts, expr.lhs, scope)
			rhs := gen_expr(stmts, expr.rhs, scope)
			iv := new_iv()
			append(stmts, local_def(iv, type, instr(.mul, lhs, rhs)))
			return {type, iris.Local(iv)}
		case .LessThan:
			lhs := gen_expr(stmts, expr.lhs, scope)
			rhs := gen_expr(stmts, expr.rhs, scope)
			iv := new_iv()
			append(stmts, local_def(iv, type, instr(.clt, lhs, rhs)))
			return {type, iris.Local(iv)}
		case:
			fmt.println("unimpl", expr.op)
			unimplemented()
		}
	case:
		fmt.println("unimpl", expr)
		unimplemented()
	}

	unimplemented()
}

from_params :: proc(params: []ast.Param) -> []iris.Param {
	params_arr: [dynamic]iris.Param

	for it in params {
		append(&params_arr, iris.Param {
			type = from_type(it.type),
			value = it.name,
		})
	}

	return params_arr[:]
}

from_args :: proc(stmts: ^[dynamic]iris.Stmt, args: []ast.Expr, scope: ast.Scope) -> []iris.Arg {
	args_arr: [dynamic]iris.Arg

	for expr in args {
		append(&args_arr, gen_expr(stmts, expr, scope))
	}

	return args_arr[:]
}

from_type :: proc(type: ast.Type) -> iris.Type {
	switch it in type {
	case ast.Pointer:
		return .ptr
	case ast.Variadic:
		unimplemented()
		//return from_type(it)
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
