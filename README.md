## zeno
```zn
#foreign("stdio.h") printf(fmt string, args ..any) u32

main() i32 {
	printf("Hello world!\n")

	name string = "lumix"
	greet(name)

	printf("%d\n", add_one(18))

	return 0
}

greet(name string) void {
	printf("Hey, %s.\n", name)
}

add_one(x u32) u32 {
	return x + 1
}
```

## usage
```
zeno -help
zeno main.zn
zeno main.zn -o main.exe
```

## iris
iris is a custom IR *(intermediate representation)* language.  
it sits between [QBE](https://c9x.me/compile/) and [LLVM IR](https://llvm.org/docs/LangRef.html) mainly as an abstraction from [NASM](https://www.nasm.us/) (target).  
its AST *(abstract syntax tree)* is currently only in memory, so no parsing.  
here is a clean translation of the above zeno example to iris:
```iris
extern $printf

; null terminated strings
; .str suffix is semantical, can be named anything
data $hello.str = { b "Hello world!\n", b 0 }
data $name.str  = { b "lumix", b 0 }
data $fmt.str   = { b "%d\n", b 0 }
data $hey.str   = { b "Hey, %s.\n", b 0 }

func i32 $main() {
	; variadic function call
	vcall ptr $printf, ptr $hello.str

	; local definition (temporary value on stack)
	ptr %name = copy ptr $name.str
	call ptr $greet(ptr %name)

	; intermediate value (semantical name)
	u32 %.iv = call ptr $add_one, u32 18
	vcall ptr $printf, ptr $fmt.str, u32 %.iv

	ret i32 0
}

func void $greet(ptr %name) {
	vcall ptr $printf, ptr $hey.str, ptr %name
	ret
}

func u32 $add_one(u32 %x) {
	u32 %.iv = add u32 %x, u32 1
	ret u32 %.iv
}
```
