package cgen

import "core:strings"
import "core:fmt"

Param :: struct {
	type: Type,
	name: string,
}

str_param :: proc(state: ^State, param: Param) -> string {
	return fmt.aprintf("%s %s", str_type(state, param.type), param.name)
}

str_params :: proc(state: ^State, params: []Param) -> string {
	// uh oh leak
	params_str: [dynamic]string
	for param in params {
		append(&params_str, str_param(state, param))
	}

	return strings.join(params_str[:], ", ")
}
