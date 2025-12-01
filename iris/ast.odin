package iris

TopStmt :: union #no_nil {
	Extern,
	Data,
	Func,
}

Extern :: struct {
	name: string,
	variadic: bool,
}

DataValue :: Typed(union {
		string,
		int,
		Global,
	})

Data :: struct {
	name: string,
	data: []DataValue,
}

Param :: Typed(string)

Func :: struct {
	type: Type,
	name: string,
	params: []Param,
	body: []Stmt,
}

Stmt :: union #no_nil {
	Instr,
	Call,
	LocalDef,
}

LocalDef :: struct {
	type: Type,
	name: string,
	value: union {
		Instr,
		Call,
	},
}

Arg :: Typed(union {
		Literal,
		Local,
		Global,
	})

Call :: struct {
	name: string,
	args: []Arg,
}

Instr :: struct {
	mnem: Mnemonic,
	args: []Arg,
}

Mnemonic :: enum {
	ret,
	add,
	copy,
}

Literal :: union #no_nil {
	int,
	f32,
}

Local :: distinct string
Global :: distinct string

Typed :: struct($T: typeid) {
	type: Type,
	value: T,
}

Type :: enum {
	void,
	ptr,
	i8,
	i32,
}
