package iris

import "core:os"
import "core:strings"
import "../nasm"

gen :: proc(top_stmts: []TopStmt, info: Info) {
	nasm.global("main")

	lines_str := strings.join(nasm.lines[:], "\n")
	os.write_entire_file("out.asm", transmute([]u8)lines_str)
}
