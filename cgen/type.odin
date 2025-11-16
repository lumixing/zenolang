package cgen

import "core:fmt"

type_ptr :: proc(state: ^State, type: Type) -> Type {
	for k, v in state.type_map {
		if type == v {
			return Pointer(k)
		}
	}

	state.type_map[state.type_map_ptr] = type
	defer state.type_map_ptr += 1
	
	return Pointer(state.type_map_ptr)
}

Type :: union #no_nil {
	Pointer,
	BasicType,
	UserType,
}

str_type :: proc(state: ^State, type: Type) -> string {
	switch type in type {
	case Pointer:
		return fmt.aprintf("%s*", str_type(state, state.type_map[type]))
	case BasicType:
		return fmt.aprintf("%s", type)
	case UserType:
		return string(type)
	}

	unreach()
}

Pointer :: distinct uint

BasicType :: enum {
	void,
	int8_t,
	int16_t,
	int32_t,
	int64_t,
	uint8_t,
	uint16_t,
	uint32_t,
	uint64_t,
	float,
	double,
	bool,
	char,
	int,
}

UserType :: distinct string
