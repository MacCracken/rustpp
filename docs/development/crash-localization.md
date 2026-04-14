# Crash Localization with CYRIUS_SYMS

Since v4.3.1, cc3 can dump a symbol table during compilation. Combined with
systemd-coredump and a little ELF arithmetic, this turns an opaque SIGSEGV
into a concrete `function + offset` trace — even without gdb installed.

## Usage

```sh
# Compile with symbols written to a side-file
CYRIUS_SYMS=/tmp/myproj-syms.txt cat src/main.cyr | cc3 > build/myproj

# File format: one function per line, `VA name`
#   000000000040007d strlen
#   0000000000400106 streq
#   00000000004001a8 memeq
#   ...
```

Zero cost when the env var is unset — the feature is purely opt-in.

## Mapping a crash to a function

```sh
# 1. Run the failing binary; coredumpctl captures the core
./build/myproj

# 2. Grab the stack trace (no gdb needed)
coredumpctl info | grep "Stack trace" -A 10
#   #0  0x0000000000400219 n/a (/tmp/myproj + 0x219)
#   #1  0x000000000045284d n/a (/tmp/myproj + 0x5284d)

# 3. Resolve each frame against the symbol file
python3 -c '
import sys
syms = sorted((int(l.split()[0],16), l.split()[1]) for l in open(sys.argv[1]))
for addr in [int(a,16) for a in sys.argv[2:]]:
    prev = None
    for off, name in syms:
        if off > addr: break
        prev = (off, name)
    print(f"0x{addr:x} -> {prev[1]} + 0x{addr-prev[0]:x}")
' /tmp/myproj-syms.txt 0x400219 0x45284d
# 0x400219 -> memeq + 0x71
# 0x45284d -> test_patrastore_append_load + 0x235
```

## Reading the offset

`memeq + 0x71` means the crash instruction is 113 bytes into `memeq`. Count
instructions in the .cyr source or dump the binary bytes to find the exact
statement. Tail calls (Cyrius emits `mov rsp,rbp; pop rbp; jmp target`)
don't appear in the stack — the callee's caller is the next frame up.

## When you need more

- **Register state at crash**: install `gdb`, run `coredumpctl gdb <pid>`,
  then `info registers`.
- **Data memory dump**: same gdb workflow; use `x/64gx <addr>` to peek.
- **Live tracing**: install `strace` — syscall-level tracing shows which
  fd/path/size combo preceded the fault.

## Known open bugs (diagnosed with this tool)

- **libro PatraStore Heisenbug** (v3.4.8+): `memeq` called with a NUL data
  pointer from `str_eq(entry_hash(a), entry_hash(b))`. Layout-dependent —
  each `println` added shifts the crash site. Root cause is memory
  corruption in libro's globals region under the full test load; CFG pass
  in v4.4.0 should expose which function writes the bad byte.
