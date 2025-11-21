package irisgen

import "../../../iris"
import check "../../checker"
import "../../ast"

gen :: proc(top_stmts: []ast.TopStmt, info: ^check.Info) {
	tstmts: [dynamic]iris.TopStmt
	for it in top_stmts {
		#partial switch it in it {
		case ast.FuncDef:
			append(&tstmts, iris.Func{
				type = type_to_iris(info, it.sign.return_type),
				name = it.sign.name,
				params = params_to_iris(info, it.sign.params),
				body = {},
			})
		}
	}
}

params_to_iris :: proc(info: ^check.Info, params: []ast.Param) -> []iris.Param {
	params_arr: [dynamic]iris.Param

	for it in params {
		append(&params_arr, iris.Param {
			type = type_to_iris(info, it.type),
			value = it.name,
		})
	}

	return params_arr[:]
}

type_to_iris :: proc(info: ^check.Info, type: ast.Type) -> iris.Type {
	switch it in type {
	case ast.Pointer:
		return type_to_iris(info, info.type_map[uint(it)])
	case ast.Variadic:
		return type_to_iris(info, info.type_map[uint(it)])
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
