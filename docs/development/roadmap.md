# Cyrius Development Roadmap

> **v1.6 shipped.** 136KB self-hosting compiler, both architectures.
> 263 tests, 0 failures. Self-hosting byte-identical. aarch64 on Raspberry Pi.
> Function table expanded to 512, variable table to 512, all P1 bugs cleared.
>
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## P1 Bugs

None — all clear.

---

## Current — v1.6 Keystone Ports

Port bhava (29K) + hisab (31K) — the two libraries that unlock 37+ downstream repos:

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Const generics | Medium | `Matrix<N,M>`, `[T; N]` |
| 2 | Derive macros | Medium | serde Serialize/Deserialize |

---

## v1.7 — Infrastructure + Security

Port kavach, sigil, phylax (security stack):

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Ownership / borrow checker | Very High | Memory safety |
| 2 | Sandbox borrow checker | Very High | AGNOS security model |

---

## v1.8 — Concurrency

Port daimon, hoosh, agnosai (AI + async stack):

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Concurrency primitives | High | Threads, atomics, channels |
| 2 | Async/await | High | tokio-style patterns |

---

## AGNOS Kernel — v0.9 (Boots Into Shell)

Current: 73KB, boots on QEMU, 15 subsystems, interactive shell.

### Done

| # | Feature | Status |
|---|---------|--------|
| 1 | Boot (multiboot1, 32→64 shim) | **Done** |
| 2 | Serial I/O, GDT, IDT, PIC, PIT timer | **Done** |
| 3 | Keyboard (full US QWERTY, shift/caps/ctrl) | **Done** |
| 4 | Page tables (2MB huge pages, identity map) | **Done** |
| 5 | PMM (bitmap), VMM, per-process page tables | **Done** |
| 6 | Kernel heap (slab allocator, 8 size classes) | **Done** |
| 7 | Context switch (full register save/restore) | **Done** |
| 8 | SYSCALL/SYSRET hardware interface | **Done** |
| 9 | Ring 3 user mode (TSS, iretq, sysretq) | **Done** |
| 10 | Process memory isolation (per-process CR3) | **Done** |
| 11 | ELF loader + userland exec | **Done** |
| 12 | VFS + device driver framework | **Done** |
| 13 | Initrd (RAM disk, flat format) | **Done** |
| 14 | Shell (help, echo, ps, free, cat, uptime, halt) | **Done** |
| 15 | kybernet init (PID 1) | **Done** |

### Next

| # | Feature | Effort | What it does |
|---|---------|--------|-------------|
| 1 | **VirtIO net** | Medium | Network device for QEMU |
| 2 | **TCP/IP stack** | Very High | ARP, IP, UDP, TCP |
| 3 | **SMP** | High | AP startup, per-CPU data, spinlocks |
| 4 | **Signals** | Medium | SIGTERM, SIGKILL, SIGCHLD |
| 5 | **Pipe/redirect** | Medium | `cmd1 \| cmd2`, stdin/stdout |
| 6 | **ATA/NVMe driver** | High | Read/write real disks |
| 7 | **FAT32 or ext2** | High | On-disk filesystem |

---

## Tooling Issues (from AGNOS kernel development)

| # | Issue | Tool | Impact | Detail |
|---|-------|------|--------|--------|
| 1 | ~~`cyrb build --aarch64` looks for cc2_aarch64 in ~/.cyrius/bin/ only~~ | cyrb | ~~Medium~~ | **Fixed** (v1.6.1). Now searches `_tools_dir` then falls back to `./build/cc2_aarch64`. |
| 2 | **`cyrb build --aarch64` fails silently on compile errors** | cyrb | Low | When the source has x86 inline asm that can't compile on aarch64, cyrb prints `FAIL` with no error detail. Should forward the compiler's stderr (e.g., "error: unknown instruction" with line number). |
| 3 | ~~No `include` support in `kernel;` mode~~ | cc2 | ~~High~~ | **Not a bug.** `include` and `#ifdef` both work in kernel mode. The real blocker was lack of `-D` flag for conditional includes. **Fixed** (v1.6.1): `cyrb build -D ARCH_X86_64 kernel/agnos.cyr build/agnos`. AGNOS kernel can now split into arch-specific includes. |
| 4 | **cc2 segfaults on source with >512 functions** | cc2 | Low | Was >256, now >512 after v1.6.0 table expansion. Programs exceeding 512 functions need splitting into separate compilation units. Proper fix: multi-file compilation (.o + link). |
| 5 | **Release tarball missing cc2_aarch64** | release | Medium | `cyrius-1.5.2-x86_64-linux.tar.gz` includes `bin/cc2` but not `bin/cc2_aarch64`. Cross-compilation requires building from source or downloading the aarch64 tarball separately. Should include cross-compiler in the x86_64 release for cross-dev workflows. |

---

## Systems Language Features

For cycc compatibility and general-purpose use:

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation |
| Struct padding/alignment (sizeof) | Medium | ABI compat, FFI |
| Unions, bitfields | Medium | Hardware, protocols |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32) | Medium | Memory efficiency |
| Optimization passes (-O1) | Very High | Performance |
| Preprocessor macros (with args) | Medium | Generic patterns |

---

## Architecture Backends

| # | Architecture | Target Hardware | Status |
|---|-------------|----------------|--------|
| 1 | x86_64 | Desktop, server | **Done** — self-hosting |
| 2 | aarch64 | RPi, phones, Apple Silicon | **Done** — byte-identical on Pi |
| 3 | RISC-V | ESP32-C3, open hardware | Planned — open ISA, sovereignty aligned |
| 4 | MIPS | Ingenic X1600E, routers | Planned |
| 5 | Xtensa | ESP32-S3, IoT | Planned |

---

## cycc — C Compiler Frontend (v2.0+)

| Phase | Scope |
|-------|-------|
| 1 | C89 subset |
| 2 | C99/C11 |
| 3 | GCC extensions |
| 4 | Full preprocessor |
| 5 | Object files + linker |
| 6 | Optimization |

---

## Crate Migration

107 repos, ~980K lines. See [migration-strategy.md](migration-strategy.md) for the full plan,
wave breakdown, porting patterns, and bridge strategies.

---

## Known Gotchas

| # | Behavior | Context | Explanation |
|---|----------|---------|-------------|
| 1 | Global var as loop bound changes mid-loop | AGNOS kernel PMM | **Expected behavior.** `for (var i = 0; i < GLOBAL; ...)` re-evaluates `GLOBAL` each iteration. If the loop body modifies the global (directly or via function call), the loop count changes. **Fix**: snapshot to local: `var limit = GLOBAL; for (var i = 0; i < limit; ...)` |
| 2 | Inline asm `[rbp-N]` overlaps function params | AGNOS ring 3 transition | In a function `fn foo(a, b)`, params are stored at `[rbp-0x08]` (a) and `[rbp-0x10]` (b). Locals declared with `var` start AFTER params: first local at `[rbp-0x18]`, etc. Inline asm writing to `[rbp-0x08]` will **clobber param a**. **Fix**: declare enough dummy locals before the asm block to push offsets past the params, or use globals for values the asm block needs. In general: `fn(p1, p2)` → p1 at -0x08, p2 at -0x10; `var v1` at -0x18, `var v2` at -0x20, etc. |
| 3 | ~~Nested for-loops with var declarations~~ | ~~AGNOS initrd, kernel patterns~~ | **Fixed** (v1.5.2). Block scoping (v0.9.5) resolved this. Nested for-loops with var declarations now compile and run correctly. |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- v1.0 ships when ready, not on a calendar
- 108 repos / ~1M lines is the real measure of success
- Subprocess bridge covers migration before FFI is ready
- Portable syscall constants for cross-architecture compilation
- Two-step bootstrap for any heap offset change
