# Binary Size Comparisons

> **Purpose**: authoritative source of `exit42`-minimum binary sizes across
> languages and platforms. Referenced by external articles and the
> agnosticos project. Updated as new compiler versions ship.
>
> **Last measured**: 2026-04-20, at Cyrius v5.5.10.
> **Methodology**: `int main() { return 42; }` (or language equivalent — all
> sources are ≤ 4 lines), no external dependencies, default invocation
> unless a size-oriented flag is documented. Sizes are raw `wc -c` bytes
> of the produced executable.

## exit42 — Linux x86_64 ELF

| Language | Toolchain | Invocation | Bytes | × Cyrius |
|----------|-----------|-----------|------:|---------:|
| **Cyrius** | cc5 5.5.10 | `echo 'syscall(60, 42);' \| cc5` | **152** | 1× |
| Zig | 0.15.2 `-OReleaseSmall` | `zig build-exe -OReleaseSmall` | 4,840 | 32× |
| Zig | 0.15.2 `-OReleaseSmall` Windows PE | `zig build-exe -target x86_64-windows -OReleaseSmall` | 4,608 | 30× |
| C (GCC) | gcc 15.2.1 `-O2 -s` | `gcc -O2 -s` | 14,248 | 94× |
| C (clang) | clang 20 `-O2 -s` | `clang -O2 -s` | 14,272 | 94× |
| C (GCC) | gcc 15.2.1 `-O2` | `gcc -O2` (w/ symbols) | 15,712 | 103× |
| C (GCC) | gcc 15.2.1 `-O2 -s -static` | full static w/ libc | 694,408 | 4,568× |
| Rust | rustc 1.93.0 `-O` stripped | `rustc -O && strip` | 344,856 | **2,269×** |
| Go | go 1.26.2 `-s -w` | `go build -ldflags="-s -w"` | 1,400,994 | 9,217× |
| Go | go 1.26.2 default | `go build` | 2,182,601 | 14,359× |
| Rust | rustc 1.93.0 `-O` (w/ symbols) | `rustc -O` | 3,887,480 | 25,575× |
| Rust | rustc 1.93.0 debug | `rustc` (default) | 3,888,160 | 25,580× |
| Zig | 0.15.2 debug | `zig build-exe` (default) | 7,388,344 | 48,608× |

## exit42 — Windows x86_64 PE32+

| Language | Toolchain | Invocation | Bytes | × Cyrius |
|----------|-----------|-----------|------:|---------:|
| **Cyrius** | cc5_win 5.5.10 native (on Windows) | `cc5_win.exe < exit42.cyr` | **1,536** | 1× |
| **Cyrius** | cc5 5.5.10 Linux cross-build | `CYRIUS_TARGET_WIN=1 cc5` | 1,536 | 1× (byte-identical to native) |
| Zig | 0.15.2 `-OReleaseSmall` | `zig build-exe -target x86_64-windows -OReleaseSmall` | 4,608 | 3× |
| Go | go 1.26.2 `-s -w` | `GOOS=windows GOARCH=amd64 go build -ldflags="-s -w"` | 1,492,992 | 972× |
| Go | go 1.26.2 default | `GOOS=windows GOARCH=amd64 go build` | 2,265,600 | 1,475× |

## Notes

- **Cyrius Linux ELF is 152 B** because cc5 emits a stripped minimum-viable
  ELF: the 64 B ELF header, one program header (56 B), a 5 B `mov eax, 60;
  syscall(42)` sequence, a handful of alignment bytes. No interpreter,
  no dynamic linker, no runtime. The binary talks directly to the
  kernel via syscalls.
- **Cyrius Windows PE is 1536 B** and runs end-to-end on Windows 11
  (build 26200, verified v5.5.10). Extra vs ELF is the PE format tax
  (DOS stub + NT headers + `.idata` import table for `kernel32!ExitProcess`
  + FileAlignment padding). Compiles natively on Windows; byte-identical
  to Linux cross-build output.
- **Rust + stripping**: stripping Rust removes ~3.6 MB of debug / symbol
  data but the baseline panic-handler, allocator, and runtime stay in
  — that's the 344 KB floor. `#![no_std]` + `#![no_main]` + a custom
  `panic_handler` can go lower (~8 KB range) but isn't idiomatic Rust.
- **Zig `-OReleaseSmall`** is the closest competitor at ~32× on Linux
  ELF / ~3× on Windows PE. Zig's `panic_handler` and `_start` are
  present but minimal.
- **Go** bundles a goroutine scheduler, garbage collector, and runtime
  reflection — the 1.4–2.3 MB is the Go runtime, not the user code.

## Cyrius self-host context

For perspective, the Cyrius v5.5.10 compiler itself (cc5) is **483,544 B**
on Linux ELF. It compiles itself byte-identically. At v5.5.10 it also
compiles itself byte-identically on Windows (cc5_win.exe native →
out.exe matches Linux cross-build md5). That's the whole
self-hosting compiler in less disk than Rust's stripped debug exit42.

- Cyrius cc5 (Linux ELF): 483,544 B
- cc5_win.exe (Windows PE): 553,984 B (PE format overhead)
- cc5 compiles itself in milliseconds (no cache, no incremental build —
  just `cat src/main.cyr | cc5 > cc5_new`).

## What this means

The numbers above measure **runtime overhead per binary**, not
"hello-world program written in X" as a proxy for language power. A C
hello-world is not 14 KB of application code — it's 4 KB of
statically-embedded libc startup plus program body. A Rust exit42 is
not 345 KB of business logic — it's 345 KB of "Rust is running in
this process" infrastructure.

Cyrius prints the smaller number because its runtime is zero. The
compiler emits a syscall and an exit, the kernel obliges.

## Methodology / reproduction

Source files, invocations, and the measurement script live in
`/tmp/sizecomp/` during development; commit the current results into
this file at each release that moves the needle. Re-run at every
minor bump.

```bash
# Minimum-viable repro (Linux x86_64):
echo 'syscall(60, 42);' | ./build/cc5 > /tmp/exit42_cyr; wc -c /tmp/exit42_cyr
echo 'int main(void) { return 42; }' > /tmp/exit42.c && \
    gcc -O2 -s /tmp/exit42.c -o /tmp/exit42_c && wc -c /tmp/exit42_c
# ... and so on for each row.
```

## Updates

- **v5.5.10** (2026-04-20): first comprehensive multi-platform measurement.
  Native Windows self-host byte-identical fixpoint achieved; Cyrius PE
  confirmed at 1536 B on real Windows 11.
