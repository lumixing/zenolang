package zeno

import "core:time"
import "core:fmt"
import "core:flags"
import check "checker"
import "diagn"
import irisgen "gen/iris"
import "../iris"
import "core:os"

Options :: struct {
	input_src:  os.Handle `args:"pos=0,required,file=r"`,
	output_exe: os.Handle `args:"pos=1,file=cw"`,

	print_tokens: bool,
	print_ast:    bool,

	output_iris:    bool,
	print_iris:     bool,
	print_iris_ast: bool,

	print_timings: bool,
}

TIMING_LEXER   :: "lexer_scan time: % 10.4f microseconds"
TIMING_PRS     :: "prs_parse time:  % 10.4f microseconds"
TIMING_CHECK   :: "check time:      % 10.4f microseconds"
TIMING_IRISGEN :: "irisgen time:    % 10.4f microseconds"
TIMING_TOTAL   :: "total time:      % 10.4f microseconds"

print_timing :: proc(fmtstr: string, timing: ^time.Time, flag := true) {
	if flag {
		fmt.printfln(fmtstr, time.duration_microseconds(time.since(timing^)))
		timing^ = time.now()
	}
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args)

	input_fi, fstat_err := os.fstat(opt.input_src)
	assert(fstat_err == nil)
	input_file, ok := os.read_entire_file(opt.input_src)
	assert(ok)

	info: check.Info

	start_time := time.now()
	last_time := start_time

	lexer: Lexer
	err := lexer_scan(&lexer, input_file)
	if err, ok := err.?; ok {
		fmt.println(err.message)
		return
	}

	print_timing(TIMING_LEXER, &last_time, opt.print_timings)
	if opt.print_tokens {
		fmt.printfln("%#v\n\n", lexer.tokens[:])
	}

	prs: Parser
	err2 := prs_parse(&prs, &info, lexer.tokens[:])
	if err, ok := err2.?; ok {
		line, col := diagn.span_to_line_col(input_file, prs.tokens[err.span.hi].span)
		fmt.printfln("%s:%d:%d: %s\n(%v)", input_fi.name, line, col, err.message, err.loc)
		return
	}

	print_timing(TIMING_PRS, &last_time, opt.print_timings)
	if opt.print_ast {
		fmt.printfln("%#v\n\n", prs.top_stmts[:])
	}

	err3 := check.check(&info, prs.top_stmts[:])
	if err, ok := err3.?; ok {
		fmt.println(err.message)
		return
	}

	print_timing(TIMING_CHECK, &last_time, opt.print_timings)

	tstmts := irisgen.gen(prs.top_stmts[:], &info)

	print_timing(TIMING_IRISGEN, &last_time, opt.print_timings)
	if opt.print_iris_ast {
		fmt.printfln("%#v\n\n", tstmts)
	}

	iris_src := iris.out(tstmts)
	if opt.print_iris {
		fmt.println(iris_src, "\n")
	}
	if opt.output_iris {
		ok := os.write_entire_file(".out.iris", transmute([]u8)iris_src)
		assert(ok)
	}
	//iris.gen(tstmts)

	print_timing(TIMING_TOTAL, &start_time, opt.print_timings)
}
