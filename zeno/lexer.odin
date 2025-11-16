package zeno

import "core:unicode"
import "core:strconv"
import "core:fmt"

Lexer :: struct {
	input: []u8,
	tokens: [dynamic]Token,
	span: Span,
}

lexer_scan :: proc(lexer: ^Lexer, input: []u8, allocator := context.allocator) -> (error: Maybe(Error)) {
	context.allocator = allocator

	lexer.input = input

	for !lexer_end(lexer) {
		lexer.span.lo = lexer.span.hi
		char := lexer_eat(lexer) or_return

		switch char {
		case ' ', '\t', '\r': // ignore
		case '\n': lexer_add_token(lexer, .Newline)
		case '(':  lexer_add_token(lexer, .LParen)
		case ')':  lexer_add_token(lexer, .RParen)
		case '{':  lexer_add_token(lexer, .LBrace)
		case '}':  lexer_add_token(lexer, .RBrace)
		case ',':  lexer_add_token(lexer, .Comma)
		case '#':  lexer_add_token(lexer, .Hash)
		case '^':  lexer_add_token(lexer, .Caret)
		case '=':  lexer_add_token(lexer, .Eq)
		case '.':
			if (lexer_peek(lexer) or_return) == '.' {
				lexer_eat(lexer) or_return
				lexer_add_token(lexer, .DotDot)
			} else {
				lexer_add_token(lexer, .Dot)
			}
		case '"':
			for {
				char := lexer_eat(lexer) or_return
				if char == '\n' {
					error = lexer_error(lexer, "Unterminated string")
					return
				}
				if char == '"' do break
			}

			res, alloc, ok := strconv.unquote_string(lexer_lexeme(lexer))
			if !ok {
				error = lexer_error(lexer, "Could not unquote string literal")
				return
			}

			lexer_add_token(lexer, .String, res)
		case:
			if ident_char(char, false) {
				for {
					char := lexer_peek(lexer) or_return
					if !ident_char(char, true) do break
					lexer_eat(lexer) or_return
				}

				lexeme := lexer_lexeme(lexer)
				switch lexeme {
				case "void":   lexer_add_token(lexer, .KW_void)
				case "string": lexer_add_token(lexer, .KW_string)
				case "any":    lexer_add_token(lexer, .KW_any)
				case "u8":     lexer_add_token(lexer, .KW_u8)
				case "u32":    lexer_add_token(lexer, .KW_u32)
				case "return": lexer_add_token(lexer, .KW_return)
				case:          lexer_add_token(lexer, .Ident, lexeme)
				}
			} else if unicode.is_digit(rune(char)) {
				for {
					char := lexer_peek(lexer) or_return
					if !unicode.is_digit(rune(char)) do break
					lexer_eat(lexer) or_return
				}

				lexeme := lexer_lexeme(lexer)
				value, ok := strconv.parse_int(lexeme)

				if !ok {
					error = lexer_error(lexer, "Could not parse integer %q", lexeme)
					return
				}

				lexer_add_token(lexer, .Integer, value)
			} else {
				error = lexer_error(lexer, "Unknown character: %c (%d)", char, char)
				return
			}
		}
	}

	lexer_add_token(lexer, .EOF)

	return
}

ident_char :: proc(char: u8, allow_digits: bool) -> bool {
	return unicode.is_alpha(rune(char)) ||
		   (allow_digits && unicode.is_digit(rune(char))) ||
		   char == '_'
}

lexer_lexeme :: proc(lexer: ^Lexer) -> string {
	return string(lexer.input[lexer.span.lo:lexer.span.hi])
}

lexer_add_token :: proc(lexer: ^Lexer, type: TokenType, value: TokenValue = nil) {
	append(&lexer.tokens, Token {
		type  = type,
		value = value,
		span  = lexer.span,
	})
}

lexer_error :: proc(lexer: ^Lexer, fmtstr: string, args: ..any, allocator := context.allocator) -> Error {
	context.allocator = allocator

	return {
		message = fmt.aprintf(fmtstr, ..args),
		span    = lexer.span,
	}
}

lexer_eat :: proc(lexer: ^Lexer) -> (char: u8, error: Maybe(Error)) {
	if lexer_end(lexer) {
		error = lexer_error(lexer, "Could not eat")
		return
	}

	defer lexer.span.hi += 1
	char = lexer_peek(lexer) or_return
	return
}

lexer_peek :: proc(lexer: ^Lexer) -> (char: u8, error: Maybe(Error)) {
	if lexer_end(lexer) {
		error = lexer_error(lexer, "Could not peek")
		return
	}

	char = lexer.input[lexer.span.hi]
	return
}

lexer_end :: proc(lexer: ^Lexer) -> bool {
	return lexer.span.hi >= len(lexer.input)
}
