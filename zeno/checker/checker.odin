package checker

import "core:fmt"
import "../ast"
import "../diagn"

Info :: struct {
	funcs: map[string]Func,

	type_map:     map[uint]ast.Type,
	type_map_ptr: uint,

	current_scope: ^Scope,
}

Scope :: struct {
	prev_scope: ^Scope,
	vars: map[string]Var,
}

Var :: struct {
	type: ast.Type,
}

type_ptr :: proc(info: ^Info, type: ast.Type) -> uint {
	for k, v in info.type_map {
		if type == v {
			return k
		}
	}

	info.type_map[info.type_map_ptr] = type
	defer info.type_map_ptr += 1
	
	return info.type_map_ptr
}

Func :: struct {
	sign: ast.FuncSign,
}

check :: proc(info: ^Info, top_stmts: []ast.TopStmt) -> Maybe(diagn.Error) {
	for top_stmt in top_stmts {
		switch tstmt in top_stmt {
		case ast.Directive:
			switch dir in tstmt {
			case ast.DirectiveForeign:
				check_func_sign(info, dir.func_sign) or_return
			}
		case ast.FuncDef:
			check_func_sign(info, tstmt.sign) or_return
		}
	}

	if "main" not_in info.funcs {
		return check_error(`Function "main" is not defined`)
	}

	for top_stmt in top_stmts {
		#partial switch tstmt in top_stmt {
		case ast.FuncDef:
			check_block(info, tstmt.body) or_return
		}
	}

	return nil
}

@(require_results)
check_block :: proc(info: ^Info, block: ast.Block) -> (error: Maybe(diagn.Error)) {
	scope: Scope
	scope.prev_scope = info.current_scope
	info.current_scope = &scope

	for it in block {
		switch it in it {
		case ast.FuncCall:
			check_func_call(info, it) or_return
		case ast.VarDef:
			//check_var_def(info, it) or_return
			var := get_var(info, info.current_scope, it.name)
			if var != nil {
				error = check_error("Variable %q is already defined", it.name)
				return
			}

			check_expr(info, it.value) or_return
			check_type_eq(it.type, expr_type(info, it.value)) or_return

			info.current_scope.vars[it.name] = {
				type = expr_type(info, it.value),
			}
		case ast.Return:
			// todo: check return type
			if it, ok := it.value.?; ok {
				check_expr(info, it) or_return
			}
		case ast.While:
		case ast.If:
		case ast.Assign:
		}
	}

	return
}

@(require_results)
check_expr :: proc(info: ^Info, expr: ast.Expr) -> (error: Maybe(diagn.Error)) {
	switch it in expr {
	case ast.Atom:
		switch it in it {
		case ast.Literal:
		case ast.Ident:
			var := get_var(info, info.current_scope, string(it))
			if var == nil {
				error = check_error("Variable %q is not defined", it)
				return
			}
		case ast.FuncCall:
			check_func_call(info, it) or_return
		}
	case ^ast.Un: unimplemented()
	case ^ast.Bin:
		check_expr(info, it.lhs) or_return
		check_expr(info, it.rhs) or_return
		check_type_eq(expr_type(info, it.lhs), expr_type(info, it.rhs)) or_return
	}

	return
}

@(require_results)
get_var :: proc(info: ^Info, scope: ^Scope, name: string) -> ^Var {
	if var, ok := &scope.vars[name]; ok {
		return var
	}
	if scope.prev_scope != nil {
		return get_var(info, scope.prev_scope, name)
	}

	return nil
}

//@(require_results)
//check_var_def :: proc(info: ^Info, var_def: VarDef) -> (error: Maybe(diagn.Error)) {
//	value_type := expr_type(info, var_def.value)
//	// i need to actually make an idectical check_type_eq but less strict
//	// for var_def.value *LITERALS*, for example it should allow:
//	// x u32 = 32  // even though this literal is default i32
//	// but now allow this:
//	// y u8 = 679  // not in bounds of u8
//	check_type_eq(var_def.type, value_type) or_return

//	return
//}

@(require_results)
check_func_sign :: proc(info: ^Info, func_sign: ast.FuncSign) -> (error: Maybe(diagn.Error)) {
	if func_sign.name in info.funcs {
		error = check_error("Function %q is already defined", func_sign.name)
		return
	}

	//if func_sign.return_type.variadic {
	//	error = check_error("Function %q has variadic return type", func_sign.name)
	//	return
	//}

	//for param, idx in func_sign.params {
	//	if param.type.type == .Void {
	//		error = check_error("In function %q, parameter %q has void type", func_sign.name, param.name)
	//		return
	//	}

	//	if param.type.variadic && idx != len(func_sign.params) - 1 {
	//		error = check_error("Function %q has non-final variadic parameter", func_sign.name)
	//		return
	//	}
	//}

	info.funcs[func_sign.name] = {
		sign = func_sign,
	}

	return
}

@(require_results)
check_func :: proc(info: ^Info, name: string) -> (func: Func, error: Maybe(diagn.Error)) {
	if name not_in info.funcs {
		error = check_error("Function %q is not declared", name)
		return
	}

	func = info.funcs[name]
	return
}

@(require_results)
check_func_call :: proc(info: ^Info, stmt: ast.FuncCall) -> (error: Maybe(diagn.Error)) {
	func := check_func(info, stmt.name) or_return
	func_is_variadic := false

	//for param in func.sign.params {
	//	if param.type.variadic {
	//		func_is_variadic = true
	//		break
	//	}
	//}

	//if !func_is_variadic {
	//	if len(func.sign.params) != len(stmt.args) {
	//		error = check_error(
	//			"Function %q expected %d arguments but got %d",
	//			func.sign.name, len(func.sign.params), len(stmt.args),
	//		)
	//		return
	//	}
	//} else {
	//	if len(func.sign.params) - 1 > len(stmt.args) {
	//		error = check_error(
	//			"Function %q expected at least %d arguments but got %d",
	//			func.sign.name, len(func.sign.params) - 1, len(stmt.args),
	//		)
	//		return
	//	}
	//}

	//if !func_is_variadic {
	//	for param, idx in func.sign.params {
	//		arg_type := expr_type(stmt.args[idx])
	//		check_type_eq(param.type, arg_type) or_return
	//	}
	//} else {
	//	for arg, idx in stmt.args {
	//		param := func.sign.params[len(func.sign.params) - 1]
	//		if idx < len(func.sign.params) - 1 {
	//			param = func.sign.params[idx]
	//		}
	//		arg_type := expr_type(arg)
	//		check_type_eq(param.type, arg_type) or_return
	//	}
	//}

	return
}

@(require_results)
check_type_eq :: proc(type1, type2: ast.Type) -> (error: Maybe(diagn.Error)) {
	//if type1.type == type2.type {
	//	return
	//}

	//if type1.type == .Any || type2.type == .Any {
	//	return
	//}
	
	if type1 == type2 {
		return
	}
	
	return check_error("Expected type %v but got %v", type1, type2)
}

expr_type :: proc(info: ^Info, expr: ast.Expr) -> ast.Type {
	switch it in expr {
	case ast.Atom:
		switch it in it {
		case ast.Ident:
			var := get_var(info, info.current_scope, string(it))
			assert(var != nil, "should have called check_expr before")
			return var.type
		case ast.Literal:
			switch it in it {
			case string: return .string
			case int:    return .i32,;;;  // valid btw?!
			case bool:   return .bool
			}
		case ast.FuncCall:
			assert(it.name in info.funcs)
			return info.funcs[it.name].sign.return_type
		}
	case ^ast.Un: unimplemented()
	case ^ast.Bin:
		return expr_type(info, it.lhs)
	}

	unreachable()
}

check_error :: proc(fmtstr: string, args: ..any, allocator := context.allocator) -> diagn.Error {
	context.allocator = allocator

	return {
		message = fmt.aprintf(fmtstr, ..args),
	}
}
