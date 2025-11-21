package iris

Info :: struct {
	funcs: map[string]InfoFunc,
}

InfoFunc :: struct {
	locals: map[string]InfoLocal,
}

InfoLocal :: struct {
	type: Type,
	offset: int,
}
