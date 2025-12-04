package iris

import "core:fmt"
import str "core:strings"

@(private)
sb: str.Builder

// since program has maps, order is random, need to do some kinda "sorting"
out :: proc(program: Program) -> string {
	sb = {}

	for it in program.extern {
		write("extern $%s\n", it)
	}
	newline()

	for _, it in program.data {
		write("data $%s = {{ ", it.name)
		for it in it.data {
			write("%s ", it.type)
			switch it in it.value {
			case string:  write("%q", it)
			case Literal: write_literal(it)
			}
			write(", ")
		}
		write(" }}\n")
	}
	newline()

	for _, it in program.func {
		write("func %s $%s(", it.type, it.name)
		for it in it.params {
			write("%s %%%s, ", it.type, it.value)
		}
		write(") {{\n")
		for it in it.body {
			switch it in it {
			case LocalDef:
				write("\t%s %%%s = %s ", it.type, it.name, it.value.mnem)
				write_args(it.value.args)
			case Instr:
				write("\t%s ", it.mnem)
				write_args(it.args)
			case Label:
				write("@%s:", it)
			}
			newline()
		}
		write("}}\n\n")
	}

	return str.to_string(sb)
}

@(private)
write :: proc(fmtstr: string, args: ..any) {
	str.write_string(&sb, fmt.tprintf(fmtstr, ..args))
}

@(private)
newline :: proc() {
	write("\n")
}

@(private)
write_args :: proc(args: []Arg) {
	for it in args {
		switch it in it {
		case Label:
			write("@%s", it)
		case ArgValue:
			write("%s ", it.type)
			switch it in it.value {
			case Literal: write_literal(it)
			case Local:   write("%%%s", it)
			case Global:  write("$%s", it)
			}
		}
		write(", ")
	}
}

@(private)
write_literal :: proc(lit: Literal) {
	switch it in lit {
	case int: write("%d", it)
	case f32: write("%f", it)
	}
}
