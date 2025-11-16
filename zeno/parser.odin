package zeno

import "base:runtime"
import "core:fmt"

Parser :: struct {
	tokens: []Token,
	top_stmts: [dynamic]TopStmt,
	span: Span,
	info: ^Info,
}

prs_parse :: proc(prs: ^Parser, info: ^Info, tokens: []Token, allocator := context.allocator) -> (error: Maybe(Error)) {
	context.allocator = allocator

	prs.tokens = tokens
	prs.info = info

	for !prs_end(prs) {
		prs.span.lo = prs.span.hi

		for (prs_peek(prs) or_return).type != .EOF {
			prs_forgive_newlines(prs) or_return
			top_stmt := prs_top_stmt(prs) or_return
			append(&prs.top_stmts, top_stmt)
		}

		_ = prs_expect(prs, .EOF) or_return
	}

	return
}

prs_top_stmt :: proc(prs: ^Parser, allocator := context.allocator) -> (top_stmt: TopStmt, error: Maybe(Error)) {
	context.allocator = allocator

	token := prs_peek(prs) or_return

	#partial switch token.type {
	case .Hash:
		_ = prs_expect(prs, .Hash) or_return
		name := (prs_expect(prs, .Ident) or_return).(string)

		switch name {
		case "foreign":
			dir := prs_dir_foreign(prs) or_return
			top_stmt = Directive(dir)
		case:
			error = prs_error(prs, "Unknown directive: %q", name)
		}
	case .Ident:
		top_stmt = prs_func_def(prs) or_return
	case:
		error = prs_error(prs, "Expected top statement but got %v", token.type)
	}

	return
}

prs_dir_foreign :: proc(prs: ^Parser, allocator := context.allocator) -> (dir_foreign: DirectiveForeign, error: Maybe(Error)) {
	context.allocator = allocator

	_ = prs_expect(prs, .LParen) or_return
	filename := (prs_expect(prs, .String) or_return).(string)
	_ = prs_expect(prs, .RParen) or_return

	prs_forgive_newlines(prs) or_return

	func_sign := prs_func_sign(prs) or_return
	_ = prs_expect(prs, .Newline) or_return

	dir_foreign = {
		filename = filename,
		func_sign = func_sign,
	}
	return
}

prs_func_def :: proc(prs: ^Parser, allocator := context.allocator) -> (func_def: FuncDef, error: Maybe(Error)) {
	context.allocator = allocator
	
	func_sign := prs_func_sign(prs) or_return
	block := prs_block(prs) or_return

	func_def = {
		sign = func_sign,
		body = block,
	}
	return
}

prs_func_sign :: proc(prs: ^Parser, allocator := context.allocator) -> (func_sign: FuncSign, error: Maybe(Error)) {
	context.allocator = allocator

	name := (prs_expect(prs, .Ident) or_return).(string)

	_ = prs_expect(prs, .LParen) or_return
	prs_forgive_newlines(prs) or_return

	params: [dynamic]Param
	if (prs_peek(prs) or_return).type != .RParen {
		expr := prs_param(prs) or_return
		append(&params, expr)

		if (prs_peek(prs) or_return).type == .Comma {
			for (prs_peek(prs) or_return).type != .RParen {
				_ = prs_expect(prs, .Comma) or_return
				expr := prs_param(prs) or_return
				append(&params, expr)
				prs_forgive_newlines(prs) or_return
			}
		}
	}

	prs_forgive_newlines(prs) or_return
	_ = prs_expect(prs, .RParen) or_return
	return_type := prs_type(prs) or_return

	func_sign = {
		name = name,
		params = params[:],
		return_type = return_type,
	}
	return
}

prs_param :: proc(prs: ^Parser, allocator := context.allocator) -> (param: Param, error: Maybe(Error)) {
	context.allocator = allocator

	prs_forgive_newlines(prs) or_return
	name := (prs_expect(prs, .Ident) or_return).(string)
	type := prs_type(prs) or_return

	param = {
		name = name,
		type = type,
	}
	return
}

prs_type :: proc(prs: ^Parser, allocator := context.allocator) -> (type: Type, error: Maybe(Error)) {
	context.allocator = allocator

	token := prs_eat(prs) or_return

	#partial switch token.type {
	case .DotDot:
		type = Variadic(type_ptr(prs.info, prs_type(prs) or_return))
	case .Caret:
		type = Pointer(type_ptr(prs.info, prs_type(prs) or_return))
	case .Ident:
		type = UserType(token.value.(string))
	case .KW_void:   type = .void
	case .KW_string: type = .string
	case .KW_any:    type = .any
	case .KW_u8:     type = .u8
	case .KW_u32:    type = .u32
	case:
		error = prs_error(prs, "Expected type but got %v (%v)", token.type, token.value)
	}

	return
}

prs_block :: proc(prs: ^Parser, allocator := context.allocator) -> (block: Block, error: Maybe(Error)) {
	context.allocator = allocator

	prs_forgive_newlines(prs) or_return
	_ = prs_expect(prs, .LBrace) or_return
	stmts: [dynamic]Stmt

	prs_forgive_newlines(prs) or_return
	for (prs_peek(prs) or_return).type != .RBrace {
		prs_forgive_newlines(prs) or_return
		stmt := prs_stmt(prs) or_return

		if (prs_peek(prs) or_return).type == .RBrace {
			append(&stmts, stmt)
			break
		}

		_ = prs_expect(prs, .Newline) or_return
		append(&stmts, stmt)
	}

	_ = prs_expect(prs, .RBrace) or_return
	_ = prs_expect(prs, .Newline) or_return

	block = stmts[:]
	return
}

@(require_results)
prs_forgive_newlines :: proc(prs: ^Parser) -> (error: Maybe(Error)) {
	for (prs_peek(prs) or_return).type == .Newline {
		prs_eat(prs) or_return
	}

	return
}

prs_stmt :: proc(prs: ^Parser, allocator := context.allocator) -> (stmt: Stmt, error: Maybe(Error)) {
	context.allocator = allocator

	token := prs_peek(prs) or_return

	#partial switch token.type {
	case .Ident:
		token_1 := prs_peek(prs, 1) or_return

		#partial switch token_1.type {
		case .LParen:
			stmt = prs_func_call(prs) or_return
		case:
			// @temp: eventually ill have to do prs_is_type() or something similar
			stmt = prs_var_def(prs) or_return
			//error = prs_error(prs, "Unexpected token: %v (%v)", token_1.type, token_1.value)
		}
	case .KW_return:
		stmt = prs_return(prs) or_return
	case:
		error = prs_error(prs, "Expected statement but got %v", token.type)
	}

	return
}

prs_func_call :: proc(prs: ^Parser, allocator := context.allocator) -> (func_call: FuncCall, error: Maybe(Error)) {
	context.allocator = allocator

	name := (prs_expect(prs, .Ident) or_return).(string)
	_ = prs_expect(prs, .LParen) or_return
	args: [dynamic]Expr

	if (prs_peek(prs) or_return).type != .RParen {
		expr := prs_expr(prs) or_return
		append(&args, expr)

		if (prs_peek(prs) or_return).type == .Comma {
			for (prs_peek(prs) or_return).type != .RParen {
				_ = prs_expect(prs, .Comma) or_return
				expr := prs_expr(prs) or_return
				append(&args, expr)
			}
		}
	}

	_ = prs_expect(prs, .RParen) or_return

	func_call = {
		name = name,
		args = args[:],
	}
	return
}

prs_var_def :: proc(prs: ^Parser, allocator := context.allocator) -> (var_def: VarDef, error: Maybe(Error)) {
	context.allocator = allocator

	name := (prs_expect(prs, .Ident) or_return).(string)
	type := prs_type(prs) or_return
	_ = prs_expect(prs, .Eq) or_return
	value := prs_expr(prs) or_return

	var_def = {
		name = name,
		type = type,
		value = value,
	}
	return
}

prs_return :: proc(prs: ^Parser, allocator := context.allocator) -> (ret: Return, error: Maybe(Error)) {
	context.allocator = allocator

	_ = prs_expect(prs, .KW_return) or_return

	if (prs_peek(prs) or_return).type == .Newline {
		return
	}

	ret.value = prs_expr(prs) or_return
	return
}

prs_expr :: proc(prs: ^Parser, allocator := context.allocator) -> (expr: Expr, error: Maybe(Error)) {
	context.allocator = allocator

	dyn_expr: [dynamic]ExprAtom
	token := prs_peek(prs) or_return
	
	#partial switch token.type {
	case .String:
		_ = prs_eat(prs) or_return
		append(&dyn_expr, Literal(token.value.(string)))
	case .Integer:
		_ = prs_eat(prs) or_return
		append(&dyn_expr, Literal(token.value.(int)))
	case .Ident:
		token_1 := prs_peek(prs, 1) or_return

		#partial switch token_1.type {
		case .LParen:
			append(&dyn_expr, prs_func_call(prs) or_return)
		case:
			_ = prs_eat(prs) or_return
			append(&dyn_expr, Ident(token.value.(string)))
		}
	case:
		error = prs_error(prs, "Expected expression but got %v (%v)", token.type, token.value)
		return
	}

	expr = Expr(dyn_expr[:])
	return
}

@(require_results)
prs_expect :: proc(prs: ^Parser, type: TokenType, allocator := context.allocator) -> (value: TokenValue, error: Maybe(Error)) {
	context.allocator = allocator

	token := prs_eat(prs) or_return

	if token.type == type {
		value = token.value
	} else {
		error = prs_error(prs, "Expected %v but got %v (%v)", type, token.type, token.value)
	}

	return
}

prs_error :: proc(prs: ^Parser, fmtstr: string, args: ..any, allocator := context.allocator) -> Error {
	context.allocator = allocator

	return {
		message = fmt.aprintf(fmtstr, ..args),
		span = prs.span,
	}
}

prs_eat :: proc(prs: ^Parser) -> (token: Token, error: Maybe(Error)) {
	if prs_end(prs) {
		error = prs_error(prs, "Could not eat")
		return
	}

	defer prs.span.hi += 1
	token = prs_peek(prs) or_return
	return
}

prs_peek :: proc(prs: ^Parser, ahead: uint = 0) -> (token: Token, error: Maybe(Error)) {
	if prs_end(prs, ahead) {
		error = prs_error(prs, "Could not peek")
		return
	}

	token = prs.tokens[prs.span.hi + ahead]
	return
}

prs_end :: proc(prs: ^Parser, ahead: uint = 0) -> bool {
	return prs.span.hi + ahead >= len(prs.tokens)
}
