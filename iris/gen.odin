package iris

import "core:fmt"
import "core:os"
import "core:strings"
import "../nasm"

gen :: proc(program: Program) {
	nasm.global("main")
	nasm.newline()

	for it in program.extern {
		nasm.extern(it)
	}
	nasm.newline()

	nasm.section("data")
	for _, it in program.data {
		nasm.label(it.name)
		for it in it.data {
			// unimpl
		}
	}
	nasm.newline()

	nasm.section("text")
	//for it in top_stmts {
	//	#partial switch it in it {
	//	case Func:
	//		off: uint = 0
	//		locals: map[string]uint

	//		nasm.label(it.name)

	//		nasm.push_reg({.qword, .rbp})
	//		nasm.mov_reg_reg({.qword, .rbp}, {.qword, .rsp})

	//		for it in it.body {
	//			switch it in it {
	//			case Instr:
	//				switch it.mnem {
	//				case .ret:
	//					//// bad!
	//					//if len(it.args) == 0 {
	//					//	nasm.ret()
	//					//} else if len(it.args) == 1 {
	//					//	//arg := it.args[0]
	//					//	//nasm.mov_reg_base_reg_dis({.dword, .rax}, {.qword, .rbp}, )
	//					//	nasm.ret()
	//					//} else {
	//					//	panic("expected return to have 0 or 1 args")
	//					//}
	//				case .add:
	//				case .sub:
	//				case .mul:
	//				case .copy:
	//				}
	//			case Call:
	//			case LocalDef:
	//				type := from_type(it.type)
	//				type_size := nasm.type_size[type]

	//				if it.name not_in locals {
	//					off += type_size
	//					locals[it.name] = off
	//					nasm.sub_reg_int({.qword, .rsp}, int(type_size))
	//				}

	//				local_off := locals[it.name]
	//				//switch it in it.value {

	//				//}
	//				nasm.mov_base_reg_dis_int({.qword, .rbp}, int(local_off), 69)
	//			}
	//		}

	//		nasm.add_reg_int({.qword, .rsp}, int(off))
	//		nasm.pop_reg({.qword, .rbp})
	//		nasm.ret()
	//	}
	//}

	lines_str := strings.join(nasm.lines[:], "\n")
	os.write_entire_file("out.asm", transmute([]u8)lines_str)
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

unreach :: proc(v: $T, loc := #caller_location) -> ! {
	fmt.panicf("unreachable: %v", v, loc = loc)
}
