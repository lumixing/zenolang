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

Data :: struct {
	name: string,
	data: []Typed(union {
		string,
		int,
	})
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
		Literal,
		Instr,
		Call,
	},
}

Call :: struct {
	name: string,
	args: []Typed(union {
		Literal,
		Local,
		Global,
	}),
}

Instr :: struct {
	mnem: Mnemonic,
	args: []Typed(union {
		Literal,
		Local,
		Global,
	}),
}

Mnemonic :: enum {
	ret,
	add,
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
