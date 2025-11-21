package nasm

import "core:os"
import "core:fmt"
import "core:slice"
import "core:strings"

ff :: fmt.aprintf
lines: [dynamic]string

@(private)
main :: proc() {
	global("main")

	section("text")
	label("main")
	push_reg({.qword, .rbp})
	mov_reg_reg({.qword, .rbp}, {.qword, .rsp})

	sub_reg_int({.qword, .rsp}, 0)

	mov_reg_reg({.qword, .rsp}, {.qword, .rbp})
	pop_reg({.qword, .rbp})
	mov_reg_int({.dword, .rax}, 0)
	ret()

	for line in lines {
		fmt.println(line)
	}

	lines_str := strings.join(lines[:], "\n")
	os.write_entire_file("out.asm", transmute([]u8)lines_str)
}

push_reg :: proc(reg: Register) {
	append(&lines, ff("\tpush %s", reg_str[reg.type][reg.kind]))
}

pop_reg :: proc(reg: Register) {
	append(&lines, ff("\tpop %s", reg_str[reg.type][reg.kind]))
}

newline :: proc() {
	append(&lines, "")
}

global :: proc(name: string) {
	append(&lines, ff("global %s", name))
}

extern :: proc(name: string) {
	append(&lines, ff("extern %s", name))
}

section :: proc(name: string) {
	append(&lines, ff("section .%s", name))
}

label :: proc(name: string) {
	append(&lines, ff("%s:", name))
}

db :: proc(args: []ConstExpr) {
	append(&lines, ff("\tdb %s", const_args_str(args)))
}

call :: proc(name: string) {
	append(&lines, ff("\tcall %s", name))
}

ret :: proc() {
	append(&lines, "\tret")
}

syscall :: proc() {
	append(&lines, "\tsyscall")
}

mov_reg_label :: proc(reg: Register, label: string) {
	append(&lines, ff("\tmov %s, %s", reg_str[reg.type][reg.kind], label))
}

mov_reg_int :: proc(reg: Register, value: int) {
	append(&lines, ff("\tmov %s, %d", reg_str[reg.type][reg.kind], value))
}

mov_reg_reg :: proc(reg1: Register, reg2: Register) {
	append(&lines, ff("\tmov %s, %s", reg_str[reg1.type][reg1.kind], reg_str[reg2.type][reg2.kind]))
}

mov_base_reg_dis_int :: proc(reg: Register, dis: int, value: int) {
	append(&lines, ff("\tmov [%s%+d], %d", reg_str[reg.type][reg.kind], dis, value))
}

sub_reg_int :: proc(reg: Register, value: int) {
	append(&lines, ff("\tsub %s, %d", reg_str[reg.type][reg.kind], value))
}

add_reg_int :: proc(reg: Register, value: int) {
	append(&lines, ff("\tadd %s, %d", reg_str[reg.type][reg.kind], value))
}

ConstExpr :: union #no_nil {
	string,
	int,
}

@(private)
const_expr_str :: proc(expr: ConstExpr) -> string {
	switch e in expr {
	case string: return ff("%q", e)
	case int:    return ff("%d", e)
	}

	unreachable()
}

@(private)
const_args_str :: proc(args: []ConstExpr) -> string {
	args_str := slice.mapper(args, const_expr_str)

	return strings.join(args_str, ", ")
}

Register :: struct {
	type: Type,
	kind: RegisterKind,
}

RegisterKind :: enum {
	rax, rbx, rcx, rdx, rsi, rdi, rbp, rsp,
	r8,  r9,  r10, r11, r12, r13, r14, r15,
}

Type :: enum {
	byte,
	word,
	dword,
	qword,
}

@(rodata)
type_size: [Type]uint = {
	.byte  = 1,
	.word  = 2,
	.dword = 4,
	.qword = 8,
}

@(rodata)
@(private)
reg_str: [Type][RegisterKind]string = {
	.qword = {
		.rax = "rax",
		.rbx = "rbx",
		.rcx = "rcx",
		.rdx = "rdx",
		.rsi = "rsi",
		.rdi = "rdi",
		.rbp = "rbp",
		.rsp = "rsp",
		.r8  = "r8",
		.r9  = "r9",
		.r10 = "r10",
		.r11 = "r11",
		.r12 = "r12",
		.r13 = "r13",
		.r14 = "r14",
		.r15 = "r15",
	},
	.dword = {
		.rax = "eax",
		.rbx = "ebx",
		.rcx = "ecx",
		.rdx = "edx",
		.rsi = "esi",
		.rdi = "edi",
		.rbp = "ebp",
		.rsp = "esp",
		.r8  = "r8d",
		.r9  = "r9d",
		.r10 = "r10d",
		.r11 = "r11d",
		.r12 = "r12d",
		.r13 = "r13d",
		.r14 = "r14d",
		.r15 = "r15d",
	},
	.word = {
		.rax = "ax",
		.rbx = "bx",
		.rcx = "cx",
		.rdx = "dx",
		.rsi = "si",
		.rdi = "di",
		.rbp = "bp",
		.rsp = "sp",
		.r8  = "r8w",
		.r9  = "r9w",
		.r10 = "r10w",
		.r11 = "r11w",
		.r12 = "r12w",
		.r13 = "r13w",
		.r14 = "r14w",
		.r15 = "r15w",
	},
	.byte = {
		.rax = "al",
		.rbx = "bl",
		.rcx = "cl",
		.rdx = "dl",
		.rsi = "sil",
		.rdi = "dil",
		.rbp = "bpl",
		.rsp = "spl",
		.r8  = "r8b",
		.r9  = "r9b",
		.r10 = "r10b",
		.r11 = "r11b",
		.r12 = "r12b",
		.r13 = "r13b",
		.r14 = "r14b",
		.r15 = "r15b",
	},
}
