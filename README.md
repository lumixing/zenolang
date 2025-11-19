## zeno
```zn
#foreign("stdio.h") printf(fmt string, args ..any) u32

main() void {
	printf("Hello world!\n")

	name string = "lumix"
	greet(name)

	printf("%d\n", add_one(18))
}

greet(name string) void {
	printf("Hey, %s.\n", name)
}

add_one(x u32) u32 {
	return x + 1
}
```
