# Cyrius Development Roadmap

> **v1.6.5 shipped.** 136KB self-hosting compiler, both architectures.
> 216 compiler + 51 program tests, 0 failures. Self-hosting byte-identical.
> All P1/P2 bugs cleared. All tooling issues resolved except known limits.
> aarch64 kernel mode working (ELF64, SP setup, arch-specific asm).
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

## Open Tooling Issues

| # | Issue | Tool | Impact | Detail |
|---|-------|------|--------|--------|
| 1 | **>512 functions segfaults** | cc2 | Low | Function tables expanded from 256→512 in v1.6.0. Programs exceeding 512 need splitting. Proper fix: multi-file compilation (.o + link). |
| 2 | **Release tarball missing cc2_aarch64** | release | Medium | x86_64 release should include cc2_aarch64 for cross-dev workflows. |
| 3 | **Preprocessor macros with args** | cc2 | Medium | `#define NAME(params) body` — storage/detection works but parameter substitution has a memory corruption bug in the `0x91000` region. Deferred. |

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
| 1 | Global var as loop bound changes mid-loop | AGNOS kernel PMM | **Expected behavior.** `for (var i = 0; i < GLOBAL; ...)` re-evaluates `GLOBAL` each iteration. If the loop body modifies the global, the loop count changes. **Fix**: snapshot to local: `var limit = GLOBAL; for (var i = 0; i < limit; ...)` |
| 2 | Inline asm `[rbp-N]` overlaps function params | AGNOS ring 3 transition | `fn foo(a, b)`: params at `[rbp-0x08]` (a), `[rbp-0x10]` (b). Locals start after: `var v1` at `[rbp-0x18]`. Inline asm writing to `[rbp-0x08]` clobbers param a. **Fix**: use globals or dummy locals to push offsets. |
| 3 | `var buf[N]` is N bytes, not N elements | agnosys port | `var buf[8]` = 8 bytes (1 i64). For a 120-byte struct: `var buf[120]`. Writing past the allocation silently corrupts adjacent data. |

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
