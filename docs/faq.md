# FAQ & Troubleshooting

## Common Questions

### What is Cyrius?
A self-hosting systems language that bootstraps from a 29KB binary. No Rust, no LLVM, no Python. Designed to write the AGNOS operating system kernel.

### What can I build with it?
CLI tools, system utilities, kernels, init systems, package managers. Anything that runs on Linux x86_64 or aarch64. See `programs/` for 52 examples.

### How is everything i64?
Every value is a 64-bit integer. Strings are pointers (which are integers). Structs are contiguous memory (accessed via integer offsets). This simplifies the compiler enormously while still being practical for systems code.

### Where are the types?
Type annotations (`var x: i64 = 42`) are documentation. Generics (`fn foo<T>()`) are parsed but not enforced. The compiler warns on pointer/scalar mismatches at assignment. Full type checking is on the roadmap.

### Is it fast?
The compiler self-compiles in 11ms. Programs are 10-233x smaller than GNU equivalents. `wc` is 20x faster than GNU on large files. See [benchmarks](benchmarks.md).

---

## Troubleshooting

### "error at token N (type=T)"
The compiler hit unexpected syntax. Common causes:
- **type=5 (SEMICOLON)**: Missing expression before `;`. Check for empty assignments like `var x = ;`
- **type=17 (==)**: Comparison in wrong context. Did you put `==` inside a function call before the comparison-in-args fix?
- **type=33 (RETURN)**: `return` outside a function body, or `default` used as a parameter name (it's a keyword)
- **type=19 (LT)**: `<` being parsed as comparison when you meant generics. Make sure generics are on function/struct definitions, not in expressions.

### "error: duplicate var at token N"
Two `var` declarations with the same name in the same function. Cyrius has no block scoping — all vars in a function share one scope. Rename the duplicate.

### "error: fixup table full (1024)"
Too many variable references in one compilation. Your program + includes exceed 1024 fixup entries. Solutions:
- Split into smaller files compiled separately
- Reduce the number of includes
- Contact us if you need a larger limit

### Program exits with wrong code
Exit codes are truncated to 0-255 (Linux limitation). Use `print_num()` or `fmt_int()` to display values larger than 255.

### Enum values are 0 inside functions
This was a bug (fixed in 0.9.0). If you're on an older version, update. The fix: enum init code must run before global var init code in cc3.cyr.

### "include" string literal breaks compilation
The preprocessor eats `"include "` patterns in string literals. Workaround: build the pattern at runtime using `store8()`. See the cyrc source for an example.

### aarch64 binary crashes with SIGILL
Check that you're using `cc2_aarch64` (not `cc3`) and running via `qemu-aarch64`. Common encoding bugs were fixed in 0.9.0.

### Vec bounds check aborts
`vec_get`/`vec_set` abort on out-of-bounds access. Check your indices. Use `vec_len()` to verify before accessing.

### `alloc()` returns 0
You forgot to call `alloc_init()` at the start of `main()`.

### Strings print garbage
String literals are null-terminated, but if you're building strings manually, make sure to `store8(buf + len, 0)` for the null terminator.

---

## Known Limitations

1. No `&&`/`||` mixed in same condition — use nested `if`
2. For loop step must be simple assignment (`i = i + 1`)
3. Exit codes truncated to 0-255
4. Max ~64 global vars with initializers (use enums for constants)
5. Max 1024 fixup entries per compilation
6. Max 256 functions per compilation
7. No negative literals — use `(0 - N)` instead of `-N`
8. `default`, `match`, `in` are keywords — don't use as variable names
9. Block closures (`|x| { ... }`) only work inside functions, not at global scope

## Gotchas

1. **Dynamic loop bounds**: `for (var i = 0; i < GLOBAL; i = i + 1)` re-evaluates
   `GLOBAL` each iteration. If the body modifies `GLOBAL`, the loop count changes.
   Fix: `var limit = GLOBAL; for (var i = 0; i < limit; ...)`.

2. **Operator overloading with stack structs**: `a + b` where `a` is a struct
   literal (`var a = Point { 1, 2 }`) passes the first field value, not the address.
   Works correctly for pointer-based types (`Str`, `Vec`).

3. **Enum constructors need alloc**: `Ok(42)` calls `alloc(16)` internally.
   Must call `alloc_init()` before using auto-generated constructors.
