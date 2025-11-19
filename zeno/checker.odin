package zeno

import "core:fmt"

Info :: struct {
	funcs: map[string]Func,

	type_map:     map[uint]Type,
	type_map_ptr: uint,
}

type_ptr :: proc(info: ^Info, type: Type) -> uint {
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
	sign: FuncSign,
}

check :: proc(info: ^Info, top_stmts: []TopStmt) -> Maybe(Error) {
	for top_stmt in top_stmts {
		switch tstmt in top_stmt {
		case Directive:
			switch dir in tstmt {
			case DirectiveForeign:
				check_func_sign(info, dir.func_sign) or_return
			}
		case FuncDef:
			check_func_sign(info, tstmt.sign) or_return
		}
	}

	if "main" not_in info.funcs {
		return check_error(`Function "main" is not defined`)
	}

	for top_stmt in top_stmts {
		#partial switch tstmt in top_stmt {
		case FuncDef:
			check_block(info, tstmt.body) or_return
		}
	}

	return nil
}

@(require_results)
check_block :: proc(info: ^Info, block: Block) -> (error: Maybe(Error)) {
	for stmt in block {
		// @partial
		#partial switch stmt in stmt {
		case FuncCall:
			check_func_call(info, stmt) or_return
		case VarDef:
			check_var_def(info, stmt) or_return
		}
	}

	return
}

@(require_results)
check_var_def :: proc(info: ^Info, var_def: VarDef) -> (error: Maybe(Error)) {
	value_type := expr_type(info, var_def.value)
	check_type_eq(var_def.type, value_type) or_return

	return
}

@(require_results)
check_func_sign :: proc(info: ^Info, func_sign: FuncSign) -> (error: Maybe(Error)) {
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
check_func :: proc(info: ^Info, name: string) -> (func: Func, error: Maybe(Error)) {
	if name not_in info.funcs {
		error = check_error("Function %q is not declared", name)
		return
	}

	func = info.funcs[name]
	return
}

@(require_results)
check_func_call :: proc(info: ^Info, stmt: FuncCall) -> (error: Maybe(Error)) {
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
check_type_eq :: proc(type1, type2: Type) -> (error: Maybe(Error)) {
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

expr_atom_type :: proc(info: ^Info, expr_atom: ExprAtom) -> Maybe(Type) {
	switch atom in expr_atom {
	case Expr: return nil
	case Literal:
		switch lit in atom {
		case string: return .string
		case int: 	 return .i32
		case bool:   return .bool
		}
	case Ident: return nil
	case FuncCall:
		return info.funcs[atom.name].sign.return_type
	case Unop: return nil
	case Binop: return nil
	}

	unreachable()
}

expr_type :: proc(info: ^Info, expr: Expr) -> Type {
	assert(len(expr) != 0)

	for atom in expr {
		if type, ok := expr_atom_type(info, atom).?; ok {
			return type
		} else {
			continue
		}
	}

	unimplemented("oops")
}

check_error :: proc(fmtstr: string, args: ..any, allocator := context.allocator) -> Error {
	context.allocator = allocator

	return {
		message = fmt.aprintf(fmtstr, ..args),
	}
}
