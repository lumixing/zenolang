package zeno

import "core:fmt"
import check "checker"
import "diagn"
import cgen "gen/c"
import irisgen "gen/iris"
import "../iris"

FILE :: "hello.zn"

main :: proc() {
	file := #load("../" + FILE)
	lexer: Lexer
	fmt.println("lexing")
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
	fmt.println("parsing")
	err2 := prs_parse(&prs, &info, lexer.tokens[:])
	if err, ok := err2.?; ok {
		line, col := diagn.span_to_line_col(file, prs.tokens[err.span.hi].span)
		fmt.printfln(FILE + ":%d:%d: %s\n(%v)", line, col, err.message, err.loc)
		return
	}
	fmt.printfln("%#v", prs.top_stmts[:])

	fmt.println("checking")
	err3 := check.check(&info, prs.top_stmts[:])
	if err, ok := err3.?; ok {
		fmt.println(err.message)
		return
	}

	fmt.println("generating")
	//cgen.gen(prs.top_stmts[:], &info)
	tstmts := irisgen.gen(prs.top_stmts[:], &info)
	//fmt.printfln("%#v", tstmts)
	fmt.println(iris.out(tstmts))

	//fmt.println("done")
}
