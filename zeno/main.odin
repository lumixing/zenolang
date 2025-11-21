package zeno

import "core:fmt"
import check "checker"
import "diagn"
import cgen "gen/c"

FILE :: "raylib.zn"

main :: proc() {
	file := #load("../" + FILE)
	lexer: Lexer
	err := lexer_scan(&lexer, file)
	if err, ok := err.?; ok {
		fmt.println(err.message)
		return
	}

	info: check.Info

	//for token in lexer.tokens {
	//	fmt.println(token)
	//}

	prs: Parser
	err2 := prs_parse(&prs, &info, lexer.tokens[:])
	if err, ok := err2.?; ok {
		line, col := diagn.span_to_line_col(file, prs.tokens[err.span.hi].span)
		fmt.printfln(FILE + ":%d:%d: %s\n(%v)", line, col, err.message, err.loc)
		return
	}
	//fmt.printfln("%#v", prs.top_stmts[:])

	err3 := check.check(&info, prs.top_stmts[:])
	if err, ok := err3.?; ok {
		fmt.println(err.message)
		return
	}

	cgen.gen(prs.top_stmts[:], &info)
	//irisgen.gen(prs.top_stmts[:], &info)

	fmt.println("done")
}
