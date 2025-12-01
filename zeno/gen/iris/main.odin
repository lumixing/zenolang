package irisgen

import "core:fmt"
import "../../../iris"
import check "../../checker"
import "../../ast"

afmt :: fmt.aprintf

tstmts: [dynamic]iris.TopStmt
glob_idx := 0

gen :: proc(top_stmts: []ast.TopStmt, info: ^check.Info) -> []iris.TopStmt {
	for it in top_stmts {
		#partial switch it in it {
		case ast.FuncDef:
			stmts: [dynamic]iris.Stmt
			for it in it.body {
				append(&stmts, gen_stmt(info, it))
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

gen_stmt :: proc(info: ^check.Info, stmt: ast.Stmt) -> iris.Stmt {
	#partial switch it in stmt {
	case ast.VarDef:
		type := from_type(info, it.type)
		name := it.name
		istmt := iris.LocalDef {
			type = type,
			name = name,
		}
		#partial switch it in it.value {
		case ast.Atom:
			#partial switch it in it {
			case ast.Ident:
				istmt.value = instr(.copy, {type, iris.Local(name)})
			case ast.Literal:
				switch it in it {
				case string:
					strlit_name := afmt(".%s.strlit.%d", name, glob_idx)
					append(&tstmts, data(strlit_name, {.i8, it}, {.i8, 0}))
					glob_idx += 1
					str_name := afmt(".%s.str.%d", name, glob_idx)
					append(&tstmts, data(str_name, {.i32, len(it)}, {.ptr, iris.Global(strlit_name)}))
					glob_idx += 1
					istmt.value = instr(.copy, {.ptr, iris.Global(str_name)})
				case int:
					istmt.value = instr(.copy, {.i32, iris.Literal(it)})
				case bool:
					istmt.value = instr(.copy, {.i32, iris.Literal(int(it))})
				}
			}
		}
		return istmt
	}

	return iris.Instr{.ret, {}}
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
