package iris

import "core:fmt"
import "core:strings"
import "./nasm"

gen :: proc(program: Program) -> string {
	nasm.global("main")
	nasm.newline()

	for extern in program.extern {
		nasm.extern(extern)
	}
	nasm.newline()

	nasm.section("data")
	for _, data in program.data {
		nasm.label(data.name)
		for data in data.data {
			switch v in data.value {
			case Literal:
				switch lit in v {
				case int:
					nasm.db({lit})
				case f32: unimplemented()
				}
			case string:
				// todo: escape string
				nasm.db({v})
			}
		}
	}
	nasm.newline()

	nasm.section("text")
	for _, func in program.func {
		nasm.label(func.name)

		nasm.push_reg({.qword, .rbp})
		nasm.mov_reg_reg({.qword, .rbp}, {.qword, .rsp})
		nasm.newline()

		for stmt in func.body {
			defer nasm.newline()

			switch stmt in stmt {
			case LocalDef:
			case Instr:
				#partial switch stmt.mnem {
				case .ret:
					if len(stmt.args) == 1 {
						arg := stmt.args[0].(ArgValue)
						switch value in arg.value {
						case Literal:
							switch lit in value {
							case int:
								nasm.mov_reg_int({from_type(arg.type), .rax}, lit)
							case f32: unimplemented()
							}
						case Local: unimplemented()
						case Global: unimplemented()
						}
					} else {
						assert(len(stmt.args) == 0)
					}
					nasm.jmp(".postlude")
				case .call:
					assert(len(stmt.args) > 1)
					func := stmt.args[0]
					args := stmt.args[1:]
					assert(len(args) <= 6)

					for arg, arg_idx in args {
						arg := arg.(ArgValue)
						reg := nasm.Register{from_type(arg.type), arg_order[arg_idx]}
						switch value in arg.value {
						case Literal:
							switch lit in value {
							case int:
								nasm.mov_reg_int(reg, lit)
							case f32: unimplemented()
							}
						case Local: unimplemented()
						case Global:
							nasm.mov_reg_label(reg, string(value))
						}
					}
					nasm.call(string(func.(ArgValue).value.(Global)))
				case: unreach(stmt.mnem)
				}
			case Label:
				nasm.label(string(stmt))
			}
		}

		nasm.label(".postlude")
		nasm.pop_reg({.qword, .rbp})
		nasm.ret()
		nasm.newline()
	}

	nasm.note_gnu_stack()
	lines_str := strings.join(nasm.lines[:], "\n")
	return lines_str
}

from_type :: proc(type: Type) -> nasm.Type {
	switch type {
	case .i8, .u8:   return .byte
	case .i16, .u16: return .word
	case .i32, .u32: return .dword
	case .i64, .u64: return .qword
	case .ptr:       return .qword
	case .void:      unimplemented()
	case: unreach(type)
	}
}

@(rodata)
arg_order := [6]nasm.RegisterKind{.rdi, .rsi, .rdx, .rcx, .r8, .r9}

unreach :: proc(v: $T, loc := #caller_location) -> ! {
	fmt.panicf("unreachable: %v", v, loc = loc)
}
