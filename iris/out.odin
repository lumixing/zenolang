package iris

//import "core:fmt"
//import str "core:strings"

//State :: struct {
//	sb: str.Builder,	
//}

//state: State

//// fucking genius
//// I AM ALSO *VERY* AGAINST @(PRIVATE) FUNCTIONS AND SUCH
//// MAYBE IF YOU ABSOLUTELY WANT TO HIDE IT FROM BINARY
//// FOR SECURITY REASONS(??) THEN THERE COULD BE A COMPILER
//// FLAG FOR PRIVATING _PREFIXED FUNCTIONS AND SUCH (EXTRA CHECKS)

////main :: proc() {
////	extern("printf", true)
////	newline()

////	data("fmt", {{.i8, "hello world %d"}, {.i8, '\n'}, {.i8, 0}})
////	newline()

////	func(.i32, "main", {{.i32, "argc"}, {.ptr, "argv"}})
////	local_def(.i32, "r", Call{"add", {{.i32, 34}, {.i32, 35}}})
////	brace()

////	fmt.println(str.to_string(state.sb))
////}

//_write :: proc(fmtstr: string, args: ..any) {
//	str.write_string(&state.sb, fmt.aprintf(fmtstr, ..args))
//}

//newline :: proc() {
//	_write("\n")
//}

//extern :: proc(name: string, variadic: bool) {
//	// go to the second starred tab on claude
//	// also we are making global state for cleaner code :D
//	_write("extern $%s%s\n", name, variadic ? " variadic" : "")
//}

//data :: proc(name: string, data: []Typed(ConstValue)) {
//	_write("data $%s = {{ ", name)
//		for it, it_idx in data {
//			_write("%s %v", it.type, it.value)
//			_comma(data, it_idx)
//		}
//	_write(" }}\n")
//}

//func :: proc(type: Type, name: string, params: []Typed(string)) {
//	_write("func %s $%s(", type, name)
//	for it, it_idx in params {
//		_write("%s %%%s", it.type, it.value)
//		_comma(params, it_idx)
//	}
//	_write(") {{\n")
//}

//brace :: proc() {
//	_write("}}\n")
//}

//local_def :: proc(type: Type, name: string, local_value: LocalValue) {
//	_write("\t%s %%%s = ", type, name)
//	switch it in local_value {
//	case Call:
//		call(it.name, it.args, tab = false)
//	case Instr:
//		instr(it.mnem, it.operands, tab = false)
//	case Literal:
//		_write("%v\n", it)
//	}
//}

//call :: proc(name: string, args: []Typed(OperandValue), tab := true) {
//	if tab do _write("\t")
//	_write("call $%s(", name)
//	_write_operand_values(args)
//	fmt.println(args)
//	_write(")\n")
//}

//instr :: proc(mnem: Mnemonic, operands: []Typed(OperandValue), tab := true) {
//	if tab do _write("\t")
//	_write("%s ", mnem)
//	_write_operand_values(operands)
//	newline()
//}

//_write_operand_values :: proc(operands: []Typed(OperandValue)) {
//	for it, it_idx in operands {
//		_write("%s ", it.type)
//		switch it in it.value {
//		case Literal:
//			_write("%v", it)
//		case Local:
//			_write("%%%s", it)
//		case Global:
//			_write("$%s", it)
//		}
//	}
//}

//// engenius
//_comma :: proc(arr: []$T, idx: int) {
//	_write(idx + 1 == len(arr) ? "" : ", ")
//}

//write_data :: proc(data: []Typed(Literal)) {
//	for it, it_idx in data {
//		_write("%s %s", it.type, it)
//		_comma(data, it_idx)
//	}
//}
