package zeno

import "base:runtime"
import "core:fmt"
import "ast"
import "diagn"
import check "checker"

Parser :: struct {
	tokens: []Token,
	top_stmts: [dynamic]ast.TopStmt,
	span: diagn.Span,
	info: ^check.Info,
}

prs_parse :: proc(prs: ^Parser, info: ^check.Info, tokens: []Token, allocator := context.allocator) -> (error: Maybe(diagn.Error)) {
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

prs_top_stmt :: proc(prs: ^Parser, allocator := context.allocator) -> (top_stmt: ast.TopStmt, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	token := prs_peek(prs) or_return

	#partial switch token.type {
	case .Hash:
		_ = prs_expect(prs, .Hash) or_return
		name := (prs_expect(prs, .Ident) or_return).(string)

		switch name {
		case "foreign":
			dir := prs_dir_foreign(prs) or_return
			top_stmt = ast.Directive(dir)
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

prs_dir_foreign :: proc(prs: ^Parser, allocator := context.allocator) -> (dir_foreign: ast.DirectiveForeign, error: Maybe(diagn.Error)) {
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

prs_func_def :: proc(prs: ^Parser, allocator := context.allocator) -> (func_def: ast.FuncDef, error: Maybe(diagn.Error)) {
	context.allocator = allocator
	
	func_sign := prs_func_sign(prs) or_return
	block := prs_block(prs) or_return

	func_def = {
		sign = func_sign,
		body = block,
	}
	return
}

prs_func_sign :: proc(prs: ^Parser, allocator := context.allocator) -> (func_sign: ast.FuncSign, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	name := (prs_expect(prs, .Ident) or_return).(string)

	_ = prs_expect(prs, .LParen) or_return
	prs_forgive_newlines(prs) or_return

	params: [dynamic]ast.Param
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

prs_param :: proc(prs: ^Parser, allocator := context.allocator) -> (param: ast.Param, error: Maybe(diagn.Error)) {
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

prs_type :: proc(prs: ^Parser, allocator := context.allocator) -> (type: ast.Type, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	token := prs_eat(prs) or_return

	#partial switch token.type {
	case .DotDot:
		type = ast.Variadic(check.type_ptr(prs.info, prs_type(prs) or_return))
	case .Caret:
		type = ast.Pointer(check.type_ptr(prs.info, prs_type(prs) or_return))
	case .Ident:
		type = ast.UserType(token.value.(string))
	case .KW_void:   type = .void
	case .KW_string: type = .string
	case .KW_any:    type = .any
	case .KW_u8:     type = .u8
	case .KW_u32:    type = .u32
	case .KW_i32:    type = .i32
	case .KW_bool:   type = .bool
	case:
		error = prs_error(prs, "Expected type but got %v (%v)", token.type, token.value)
	}

	return
}

prs_block :: proc(prs: ^Parser, allocator := context.allocator) -> (block: ast.Block, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	prs_forgive_newlines(prs) or_return
	_ = prs_expect(prs, .LBrace) or_return
	stmts: [dynamic]ast.Stmt

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
prs_forgive_newlines :: proc(prs: ^Parser) -> (error: Maybe(diagn.Error)) {
	for (prs_peek(prs) or_return).type == .Newline {
		prs_eat(prs) or_return
	}

	return
}

prs_stmt :: proc(prs: ^Parser, allocator := context.allocator) -> (stmt: ast.Stmt, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	token := prs_peek(prs) or_return

	#partial switch token.type {
	case .KW_for:
		stmt = prs_while(prs) or_return
	case .KW_if:
		stmt = prs_if(prs) or_return
	case .Ident:
		token_1 := prs_peek(prs, 1) or_return

		#partial switch token_1.type {
		case .LParen:
			stmt = prs_func_call(prs) or_return
		case .Eq:
			stmt = prs_assign(prs) or_return
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

prs_while :: proc(prs: ^Parser, allocator := context.allocator) -> (while: ast.While, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	_ = prs_expect(prs, .KW_for) or_return
	cond, _ := prs_expr(prs) or_return
	body := prs_block(prs) or_return

	while = {
		cond = cond,
		body = body,
	}
	return
}

prs_if :: proc(prs: ^Parser, allocator := context.allocator) -> (if_: ast.If, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	_ = prs_expect(prs, .KW_if) or_return
	cond, _ := prs_expr(prs) or_return
	body := prs_block(prs) or_return

	if_ = {
		cond = cond,
		body = body,
	}
	return
}

prs_func_call :: proc(prs: ^Parser, allocator := context.allocator) -> (func_call: ast.FuncCall, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	name := (prs_expect(prs, .Ident) or_return).(string)
	_ = prs_expect(prs, .LParen) or_return
	args: [dynamic]ast.Expr

	if (prs_peek(prs) or_return).type != .RParen {
		expr, _ := prs_expr(prs) or_return
		append(&args, expr)

		if (prs_peek(prs) or_return).type == .Comma {
			for (prs_peek(prs) or_return).type != .RParen {
				_ = prs_expect(prs, .Comma) or_return
				expr, _ := prs_expr(prs) or_return
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

prs_assign :: proc(prs: ^Parser, allocator := context.allocator) -> (assign: ast.Assign, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	lhs, _ := prs_expr(prs) or_return
	_ = prs_expect(prs, .Eq) or_return
	rhs, _ := prs_expr(prs) or_return

	assign = {
		lhs = lhs,
		rhs = rhs,
	}
	return
}

prs_var_def :: proc(prs: ^Parser, allocator := context.allocator) -> (var_def: ast.VarDef, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	name := (prs_expect(prs, .Ident) or_return).(string)
	type := prs_type(prs) or_return
	_ = prs_expect(prs, .Eq) or_return
	value, _ := prs_expr(prs) or_return

	var_def = {
		name = name,
		type = type,
		value = value,
	}
	return
}

prs_return :: proc(prs: ^Parser, allocator := context.allocator) -> (ret: ast.Return, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	_ = prs_expect(prs, .KW_return) or_return

	if (prs_peek(prs) or_return).type == .Newline {
		return
	}

	// we could remove _ by not making it return consumed
	// instead prs_try_expr returns consumed
	// OR put consumed in Error
	value, _ := prs_expr(prs) or_return
	ret.value = value
	return
}

prs_expr :: proc(prs: ^Parser, min_bp: u8 = 0, allocator := context.allocator) -> (expr: ast.Expr, consumed: uint, error: Maybe(diagn.Error)) {
	context.allocator = allocator
	span_old := prs.span

	lhs: ast.Expr = prs_atom(prs) or_return

	for {
		op, op_consumed, op_err := prs_op(prs)
		if op_err != nil {
			prs.span.hi -= op_consumed
			break
		}

		l_bp, r_bp := ast.infix_bp(op)
		if l_bp < min_bp {
			prs.span.hi -= op_consumed
			break
		}

		rhs, _ := prs_expr(prs, r_bp) or_return

		lhs = new_clone(ast.Bin {
			op = op.(ast.Binop),
			lhs = lhs,
			rhs = rhs,
		})
	}

	consumed = prs.span.hi - span_old.hi
	expr = lhs
	return
}

prs_atom :: proc(prs: ^Parser, allocator := context.allocator) -> (atom: ast.Atom, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	token := prs_eat(prs) or_return
	#partial switch token.type {
	case .Ident:
		atom = ast.Ident(token.value.(string))
	case .String:
		atom = ast.Literal(token.value.(string))
	case .Integer:
		atom = ast.Literal(token.value.(int))
	case:
		error = prs_error(prs, "Expected atom but got %v (%v)", token.type, token.value)
	}

	return
}

prs_op :: proc(prs: ^Parser, allocator := context.allocator) -> (op: ast.Op, consumed: uint, error: Maybe(diagn.Error)) {
	context.allocator = allocator
	span_old := prs.span

	token := prs_eat(prs) or_return
	#partial switch token.type {
	case .Plus:
		op = .Add
	case .Asterisk:
		op = .Mult
	case:
		error = prs_error(prs, "Expected operator but got %v (%v)", token.type, token.value)
	}

	consumed = prs.span.hi - span_old.hi
	return
}

@(require_results)
prs_expect :: proc(prs: ^Parser, type: TokenType, allocator := context.allocator, loc := #caller_location) -> (value: TokenValue, error: Maybe(diagn.Error)) {
	context.allocator = allocator

	token := prs_eat(prs) or_return

	if token.type == type {
		value = token.value
	} else {
		error = prs_error(prs, "Expected %v but got %v (%v)", type, token.type, token.value, loc = loc)
	}

	return
}

prs_error :: proc(prs: ^Parser, fmtstr: string, args: ..any, allocator := context.allocator, loc := #caller_location) -> diagn.Error {
	context.allocator = allocator

	return {
		message = fmt.aprintf(fmtstr, ..args),
		span = prs.span,
		loc = loc,
	}
}

prs_eat :: proc(prs: ^Parser) -> (token: Token, error: Maybe(diagn.Error)) {
	if prs_end(prs) {
		error = prs_error(prs, "Could not eat")
		return
	}

	defer prs.span.hi += 1
	token = prs_peek(prs) or_return
	return
}

prs_peek :: proc(prs: ^Parser, ahead: uint = 0) -> (token: Token, error: Maybe(diagn.Error)) {
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
