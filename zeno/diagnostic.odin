package zeno

import "base:runtime"

Error :: struct {
	message: string,
	span: Span,
	loc: runtime.Source_Code_Location,
}

span_to_line_col :: proc(file: []u8, span: Span) -> (line, col: uint) {
	line, col = 1, 1

	for char, idx in file[:span.hi] {
		if char == '\n' {
			line += 1
			col = 1
		} else {
			col += 1
		}
	}

	return
}
