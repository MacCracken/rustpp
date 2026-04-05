# Cyrius Language Guide

> The complete reference for writing Cyrius programs and kernels.

## Quick Start

```sh
sh bootstrap/bootstrap.sh                    # Build toolchain (40ms)
echo 'var x = 42;' | ./build/cc2 > prog     # Compile
chmod +x prog && ./prog; echo $?            # Run → 42
```

## Types

Everything is a 64-bit integer. No floats, no separate pointer type at the value level. Type annotations are optional and don't enforce:

```
var x = 42;
var y: i64 = 42;      # Same thing — annotation is documentation
```

## Variables

```
var x = 10;            # Global or local (context-dependent)
var buf[256];           # Array (256 * 8 = 2048 bytes)
x = x + 1;             # Reassignment
```

## Functions

```
fn add(a, b) {
    return a + b;
}
var r = add(20, 22);   # r = 42
```

- Up to 6 register params, 7+ passed on stack
- Forward calls work (functions can call functions defined later)
- All functions return a value (`return 0;` if nothing to return)

## Control Flow

```
# If / elif / else
if (x == 1) { ... }
elif (x == 2) { ... }
else { ... }

# While
while (x < 10) { x = x + 1; }

# For
for (var i = 0; i < 10; i = i + 1) { ... }

# Break / Continue (in while and for)
while (1 == 1) {
    if (done == 1) { break; }
    if (skip == 1) { continue; }
}
```

## Operators

```
# Arithmetic
+ - * / %

# Comparison (return 1 or 0)
== != < > <= >=

# Bitwise
& | ^ ~ << >>

# Logical (short-circuit, chainable)
&&  ||
```

## Memory

```
var buf[16];
store8(&buf, 65);              # Write byte
var c = load8(&buf);           # Read byte → 65

store16(&buf, 0x1234);         # 16-bit
store32(&buf, 0x12345678);     # 32-bit
store64(&buf, 0x123456789ABC); # 64-bit

var v = load16(&buf);          # Corresponding reads
var v = load32(&buf);
var v = load64(&buf);
```

## Pointers

```
var x = 42;
var p = &x;            # Address of x
var v = *p;            # Dereference → 42
*p = 99;               # Write through pointer

# Typed pointers (auto-scale arithmetic)
var buf[64];
store64(&buf, 10);
store64(&buf + 8, 20);
var p: *i64 = &buf;
var a = *p;            # 10
var b = *(p + 1);      # 20 (adds 8 bytes, not 1)
```

## Structs

```
struct Point { x; y; }

var p = Point { 10, 20 };
var sum = p.x + p.y;    # 30
p.x = 42;               # Field assignment

# Nested structs
struct Rect { tl: Point; br: Point; }
var r = Rect { 0, 0, 10, 5 };
var w = r.br.x - r.tl.x;   # 10
```

## Strings

```
syscall(1, 1, "hello\n", 6);   # Write to stdout
# Escape sequences: \n \t \0 \\ \"
# Strings are null-terminated in the data section
```

## Syscalls

```
syscall(1, 1, "hello", 5);          # write(fd=1, buf, len=5)
var n = syscall(0, 0, &buf, 256);   # read(fd=0, buf, len=256)
syscall(60, 0);                      # exit(0)
```

## Includes

```
include "stage1/lib/string.cyr"
# Textual inclusion — file contents replace the include line
```

## Inline Assembly

```
# Raw bytes
asm { 0x90; }                    # nop

# Mnemonics (kernel instructions)
asm { cli; }                     # Clear interrupts
asm { sti; }                     # Set interrupts
asm { hlt; }                     # Halt CPU
asm { mov cr3, rax; }           # Load page table
asm { lgdt [rax]; }             # Load GDT
asm { lidt [rax]; }             # Load IDT
asm { iretq; }                  # Return from interrupt
asm { int 3; }                  # Software interrupt
asm { invlpg [rax]; }           # Flush TLB entry
asm { in al, dx; }              # Port input
asm { out dx, al; }             # Port output
asm { wrmsr; rdmsr; cpuid; }    # System instructions
```

## Kernel Mode

```
kernel;                          # Emit bare-metal ELF (multiboot1)
# Rest of the file is kernel code
# Entry point: 32-bit boot shim → 64-bit Cyrius code
# Boot: qemu-system-x86_64 -kernel build/kernel -serial stdio
```

## Enums

```
enum Color { RED; GREEN; BLUE; }     # RED=0, GREEN=1, BLUE=2
enum Error { OK = 0; NOT_FOUND = 44; PERM = 13; }  # Explicit values

var c = BLUE;                        # c = 2
```

## Switch

```
fn classify(n) {
    switch (n) {
        case 0: return 0;
        case 1: return 1;
        default: return 99;
    }
    return 0;
}
```

Note: case values must be integer literals. No fallthrough — each case is independent.

## Function Pointers

```
fn add(a, b) { return a + b; }
var fp = &add;                       # Get function address

# Call through pointer (using fnptr library):
include "stage1/lib/fnptr.cyr"
var result = fncall2(fp, 20, 22);    # result = 42
```

## Global Initializers

Variables can be declared among function definitions:

```
fn get_value() { return global_var; }
var global_var = 42;             # Visible to functions above
var r = get_value();             # r = 42
```

## String Standard Library

```
include "stage1/lib/string.cyr"

strlen(s)              # Length of null-terminated string
streq(a, b)            # Compare strings (1=equal, 0=not)
memeq(a, b, n)         # Compare n bytes
memcpy(dst, src, n)    # Copy n bytes
memset(dst, val, n)    # Fill n bytes
memchr(s, c, n)        # Find byte in buffer (-1 if not found)
strchr(s, c)           # Find byte in string (-1 if not found)
print_num(n)           # Print decimal to stdout
println(s)             # Print string + newline
```

## Standard Libraries

```
include "stage1/lib/string.cyr"  # strlen, streq, memcpy, memset, memchr, strchr, print_num, println
include "stage1/lib/alloc.cyr"   # alloc_init, alloc, alloc_reset, alloc_used (bump allocator)
include "stage1/lib/str.cyr"     # Str type: str_from, str_len, str_eq, str_cat, str_sub, str_print
include "stage1/lib/vec.cyr"     # Dynamic array: vec_new, vec_push, vec_pop, vec_get, vec_set, vec_len
include "stage1/lib/io.cyr"      # File I/O: file_open, file_read, file_write, file_close, file_read_all
include "stage1/lib/fmt.cyr"     # Formatting: fmt_int, fmt_hex, fmt_hex0x, fmt_bool, fmt_byte
include "stage1/lib/args.cyr"    # CLI args: args_init, argc, argv
include "stage1/lib/fnptr.cyr"   # Function pointers: fncall0, fncall1, fncall2
```

## AGNOS System Libraries

```
# Shared types (agnostik)
include "stage1/lib/agnostik/error.cyr"    # Error codes (1001-1010), err_is_retriable, err_print
include "stage1/lib/agnostik/types.cyr"    # AgentType, AgentStatus, MessageType, SystemStatus enums
include "stage1/lib/agnostik/security.cyr" # Permission (bitmask), Role, SecurityContext struct
include "stage1/lib/agnostik/agent.cyr"    # AgentConfig, AgentInfo, AgentStats structs
include "stage1/lib/agnostik/audit.cyr"    # AuditSeverity, AuditEntry, audit_print
include "stage1/lib/agnostik/config.cyr"   # AgnosConfig, environment profiles

# Syscall bindings (agnosys)
include "stage1/lib/agnosys/syscalls.cyr"  # 50 syscall numbers, 20+ wrappers, sigset, epoll, timerfd

# Init system (kybernet)
include "stage1/lib/kybernet/console.cyr"  # PID 1 stdio redirect
include "stage1/lib/kybernet/signals.cyr"  # Signal blocking + signalfd
include "stage1/lib/kybernet/reaper.cyr"   # Zombie process reaper (waitpid loop)
include "stage1/lib/kybernet/privdrop.cyr" # Privilege dropping (setgroups/setgid/setuid)
include "stage1/lib/kybernet/mount.cyr"    # Essential filesystem mounts
include "stage1/lib/kybernet/cgroup.cyr"   # Cgroup v2 service management
include "stage1/lib/kybernet/eventloop.cyr"# Epoll + timerfd event loop
```

## Known Limitations

- No block scoping: `var` in loop bodies allocates new stack slot per iteration. Declare variables outside loops.
- No comparison expressions in function args: `f(x == 1)` fails. Use `if (x == 1) { f(1); }`.
- Exit codes truncated to 0-255 (Linux limitation).
- Inline asm operates on register state directly — know the calling convention.
- `for` loop step must be a simple assignment (`i = i + 1`), not a complex expression.
- Max ~64 global vars with initializers (use enums for constants to avoid overflow).

## Building

```sh
# Bootstrap from seed
sh bootstrap/bootstrap.sh

# Build a program
echo 'var x = 42;' | ./build/cc2 > prog && chmod +x prog

# Build the kernel
cat kernel/agnos.cyr | ./build/cc2 > build/agnos

# Cross-compile for aarch64
cat prog.cyr | ./build/cc2_aarch64 > prog_arm

# Run tests
sh stage1/test_cc.sh ./build/cc2 ./build/stage1f
sh stage1/programs/test_programs.sh ./build/cc2
sh stage1/test_asm.sh ./build/asm

# Boot kernel
qemu-system-x86_64 -kernel build/agnos -serial stdio -display none
```

## Example Programs

See `stage1/programs/` for 46 examples:
- **CLI tools**: cat, echo, head, wc, grep, hexdump, tail, tr, uniq, sort, basename, cols, count, toupper, rot13, rev, nl, seq, tee, yes, true, false
- **Algorithms**: fizzbuzz, primes, sieve, collatz, ackermann, gcd, brainfuck, life, xor
- **Data structures**: struct_list (linked list), alloctest (heap), strtype (fat strings)
- **Systems**: bitfield (PTE/GDT/IDT), asmtest (18 mnemonics), points (nested structs + typed ptrs)
- **Kernel**: kernel_hello (VGA), isr_stub (interrupt patterns), boot_serial, agnos (full kernel)

## Architecture

```
bootstrap/asm (29KB seed)
  → stage1f (12KB compiler)
    → cc.cyr (monolithic, bridge)
      → cc2 (modular, 182 functions, 92KB)
        → cc2_aarch64 (cross-compiler)
        → agnos.cyr (AGNOS kernel)
```
