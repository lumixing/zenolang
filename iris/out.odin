package iris

import "core:fmt"
import str "core:strings"

sb: str.Builder

write :: proc(fmtstr: string, args: ..any) {
	str.write_string(&sb, fmt.tprintf(fmtstr, ..args))
}

out :: proc(top_stmts: []TopStmt) -> string {
	sb = {}

	for it in top_stmts {
		switch it in it {
		case Extern:
			write("extern $%s%s\n", it.name, it.variadic ? " variadic" : "")
		case Data:
			write("data $%s = {{ ", it.name)
			for it in it.data {
				write("%s ", it.type)
				switch it in it.value {
				case int:    write("%v", it)
				case string: write("%q", it)
				case Global: write("$%s", it)
				}
				write(", ")
			}
			write(" }}\n")
		case Func:
			write("func %s $%s(", it.type, it.name)
			for it in it.params {
				write("%s %%%s, ", it.type, it.value)
			}
			write(") {{\n")
			for it in it.body {
				write("\t")
				defer write("\n")
				switch it in it {
				case Instr:
					 _out_instr(it)
				case Call:
					_out_call(it)
				case LocalDef:
					write("%s %%%s = ", it.type, it.name)
					switch it in it.value {
					case Instr: _out_instr(it)
					case Call:  _out_call(it)
					}
				}
			}
			write("}}\n\n")
		}
	}

	return str.to_string(sb)
}

_out_instr :: proc(it: Instr) {
	write("%s ", it.mnem)
	for it in it.args {
		write("%s ", it.type)
		defer write(", ")
		#partial switch it in it.value {
		case Literal: write("%v",   it)
		case Local:   write("%%%s", it)
		case Global:  write("$%s",  it)
		}
	}
}

_out_call :: proc(it: Call) {
	write("call $%s(")
	for it in it.args {
		write("%s ", it.type)
		defer write(", ")
		switch it in it.value {
		case Literal: write("%v",   it)
		case Local:   write("%%%s", it)
		case Global:  write("$%s",  it)
		}
	}
	write(")")
}
