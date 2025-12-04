package iris

Typed :: struct($T: typeid) {
	type:  Type,
	value: T,
}

Type :: enum {
	void, ptr,
	i8, i16, i32, i64,
	u8, u16, u32, u64,
}

Program :: struct {
	extern: map[string]bool,
	data:   map[string]Data,
	func:   map[string]Func,
}

Data :: struct {
	name: string,
	data: []DataValue,
}

DataValue :: Typed(union #no_nil {
	Literal,
	string,
	//Global,
})

Func :: struct {
	type:   Type,
	name:   string,
	params: []Param,
	body:   []Stmt,
}

Param :: Typed(string)

Stmt :: union #no_nil {
	LocalDef,
	Instr,
	Label,
}

LocalDef :: struct {
	type:  Type,
	name:  string,
	value: Instr,
}

LocalDefInstr :: struct {
	mnem: LocalDefInstrMnem,
	args: []Arg,
}

LocalDefInstrMnem :: enum {
	copy,
}

Instr :: struct {
	mnem: InstrMnem,
	args: []Arg,
}

InstrMnem :: enum {
	ret,
	add,
	sub,
	mul,
}

Arg :: union #no_nil {
	Label,
	ArgValue,
}

ArgValue :: Typed(union #no_nil {
	Literal,
	Local,
	Global,
})

Label  :: distinct string
Local  :: distinct string
Global :: distinct string

Literal :: union #no_nil {
	int,
	f32,
}

