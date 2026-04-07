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
| 1 | **>1024 functions segfaults** | cc2 | Low | Function tables expanded from 512→1024 in v1.6.7. Error message at limit. Proper fix: multi-file compilation (.o + link). |
| 2 | ~~Release tarball missing cc2_aarch64~~ | release | ~~Medium~~ | **Fixed** (v1.6.7). x86_64 tarball now includes cc2_aarch64, cyrb binary, all cyrb-*.sh scripts, and ci.sh. |
| 3 | ~~Preprocessor macros with args~~ | cc2 | ~~Medium~~ | **Fixed** (v1.6.7). `#define NAME(p1, p2) body` with parameter substitution. Macro storage inlined in PP_PASS, expansion in separate PP_MACRO_PASS. Up to 16 macros. |

---

## Performance Optimizations (from crate benchmarks)

Findings from agnosys + kybernet head-to-head benchmarks against Rust. Syscalls are at parity. Pure compute and allocation are the gaps.

### Tier 1 — Pure Compute (2-10x gap, found in kybernet)

Small integer operations, branch chains, enum dispatch. The gap is codegen quality, not architecture.

| # | Optimization | Target | Expected Impact |
|---|-------------|--------|-----------------|
| 1 | Constant folding | `classify_signal`: 2ns vs Rust 1ns | Eliminate runtime computation of compile-time-known values |
| 2 | Branch optimization | `notify_parse`: 20ns vs Rust 2ns | if/elif chains → jump tables for dense integer switches |
| 3 | Inline small functions | `W* macros`: 7ns vs Rust 1ns | Eliminate call/ret overhead for trivial functions |
| 4 | Compare-and-branch fusion | General | `cmp + jne` in one pass instead of `cmp → setCC → test → jne` |

### Tier 2 — Allocation (7-36x gap, found in kybernet cold paths)

String building and BPF program generation. The gap is heap allocation overhead vs Rust's stack allocation + LLVM optimization.

| # | Optimization | Target | Expected Impact |
|---|-------------|--------|-----------------|
| 5 | Stack-allocated small strings | `str_builder`: 371ns vs Rust 52ns | Avoid heap for strings < 64 bytes |
| 6 | Arena allocator for BPF | `seccomp_build`: 2.4μs vs Rust 69ns | Batch-allocate BPF instructions instead of per-insn alloc |
| 7 | Path buffer reuse | `cgroup_path`: 466ns vs Rust 24ns | Pre-allocated path buffer instead of heap concat |
| 8 | Return-by-value for small structs | General | Eliminate heap copy for structs ≤ 2 registers |

### Tier 3 — Codegen Quality (general)

| # | Optimization | Effort | Impact |
|---|-------------|--------|--------|
| 9 | Dead code elimination | Medium | Remove unused function bodies |
| 10 | Register allocation | High | Reduce spills to stack, fewer mov instructions |
| 11 | Peephole optimization | Medium | `mov rax, 0` → `xor eax, eax`, redundant load elimination |
| 12 | Tail call optimization | Low | Recursive functions don't grow the stack |

### Context

These optimizations are informed by real benchmark data, not speculation. Each one was discovered by porting an actual Rust crate and measuring head-to-head. The pattern: syscall-bound code is at parity (kernel does the work), pure compute needs better codegen, allocation needs smarter placement.

For PID 1 (kybernet), the hot path is epoll_wait + syscalls — already at parity. The cold path (seccomp_build, cgroup_path) runs once at boot. The 36x gap on seccomp_build is 2.4 microseconds, once. The optimization priority is real programs, not benchmarks.

---

## Systems Language Features

For cycc compatibility and general-purpose use:

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation, fixes >512 function limit |
| Struct padding/alignment (sizeof) | Medium | ABI compat, FFI |
| Unions, bitfields | Medium | Hardware, protocols |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32) | Medium | Memory efficiency |
| Optimization passes (-O1) | Very High | Performance (see Tier 1-3 above) |
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
