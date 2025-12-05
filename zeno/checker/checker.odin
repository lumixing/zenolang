package checker

import "core:fmt"
import "../ast"
import "../diagn"

Info :: struct {
	root_scope: ast.Scope,
}

@(require_results)
// pass top_stmts by ptr??
check :: proc(info: ^Info, top_stmts: ^[]ast.TopStmt) -> (err: Maybe(diagn.Error)) {
	for &tstmt in top_stmts {
		switch &tstmt in tstmt {
		case ast.Directive:
			switch dir in tstmt {
			case ast.DirectiveForeign:
				if dir.func_sign.name in info.root_scope.funcs {
					err = error("Function %q is already defined in root_scope.funcs", dir.func_sign.name)
					return
				}

				info.root_scope.funcs[dir.func_sign.name] = dir.func_sign
			}
		case ast.FuncDef:
			if tstmt.sign.name in info.root_scope.funcs {
				err = error("Function %q is already defined in root_scope.funcs", tstmt.sign.name)
				return
			}

			info.root_scope.funcs[tstmt.sign.name] = tstmt.sign
			check_block(&tstmt.body, &info.root_scope) or_return
		}
	}

	return
}

@(require_results)
check_block :: proc(block: ^ast.Block, parent_scope: ^ast.Scope) -> (err: Maybe(diagn.Error)) {
	scope: ast.Scope
	scope.parent_scope = parent_scope

	for &stmt in block.stmts {
		check_stmt(&stmt, &scope) or_return
	}
	block.scope = scope

	return
}

@(require_results)
check_stmt :: proc(stmt: ^ast.Stmt, scope: ^ast.Scope) -> (err: Maybe(diagn.Error)) {
	#partial switch &stmt in stmt {
	case ast.While:
		check_block(&stmt.body, scope) or_return
	case ast.VarDef:
		var := get_var(stmt.name, scope^)
		assert(var == nil)

		scope.vars[stmt.name] = stmt
	// case: unimplemented()
	}

	return
}

@(require_results)
get_var :: proc(name: string, scope: ast.Scope) -> Maybe(ast.VarDef) {
	if var, ok := scope.vars[name]; ok {
		return var
	}
	if scope.parent_scope != nil {
		return get_var(name, scope.parent_scope^)
	}
	return nil
}

@(require_results)
get_func :: proc(name: string, scope: ast.Scope) -> Maybe(ast.FuncSign) {
	if func, ok := scope.funcs[name]; ok {
		return func
	}
	if scope.parent_scope != nil {
		return get_func(name, scope.parent_scope^)
	}
	return nil
}

@(require_results)
expr_type :: proc(expr: ast.Expr, scope: ast.Scope) -> ast.Type {
	switch expr in expr {
	case ^ast.Expr:
		return expr_type(expr^, scope)
	case ast.Atom:
		switch atom in expr {
		case ast.Literal:
			switch lit in atom {
			case int:    return .i32
			case string: return .string
			case bool:   return .bool
			}
		case ast.Ident:
			var := get_var(string(atom), scope).?
			return var.type
		case ast.FuncCall:
			func := get_func(atom.name, scope).?
			return func.return_type
		}
	case ^ast.Bin:
		#partial switch expr.op {
		case .LessThan, .GreaterThan, .Eq:
			return .bool
		}
		return expr_type(expr.lhs, scope)
	case ^ast.Un:
		return expr_type(expr.expr, scope)
	}

	unimplemented()
}

@(require_results)
error :: proc(fmtstr: string, args: ..any, allocator := context.allocator) -> diagn.Error {
	context.allocator = allocator

	return {
		message = fmt.aprintf(fmtstr, ..args),
	}
}
