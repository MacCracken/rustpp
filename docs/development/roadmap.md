# Cyrius Development Roadmap

> **v1.7.0.** 131KB self-hosting compiler, both architectures.
> 267 tests (216 compiler + 51 programs), 0 failures. Self-hosting byte-identical.
> Preprocessor macros, EMOVI optimization, aarch64 kernel mode, human-readable errors.
>
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## P1 Bugs

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 1 | **Parse error on 14+ module include chains** | High | agnosys full stack (14 modules) produces `unexpected ')'` at deep line numbers. Two-pass ifdef works but specific source patterns trigger errors. |

---

## Current — v1.7 Keystone Ports

Port bhava (29K) + hisab (31K) — the two libraries that unlock 37+ downstream repos:

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Const generics | Medium | `Matrix<N,M>`, `[T; N]` |
| 2 | Derive macros | Medium | serde Serialize/Deserialize |

---

## v1.8 — Infrastructure + Security

Port kavach, sigil, phylax (security stack):

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Ownership / borrow checker | Very High | Memory safety |
| 2 | Sandbox borrow checker | Very High | AGNOS security model |

---

## v1.9 — Concurrency

Port daimon, hoosh, agnosai (AI + async stack):

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Concurrency primitives | High | Threads, atomics, channels |
| 2 | Async/await | High | tokio-style patterns |

---

## AGNOS Kernel — Next

Current: 73KB x86_64, boots on QEMU, 15 subsystems, interactive shell.
aarch64 kernel mode added in v1.6: ELF64, SP preamble, arch-specific asm.

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

## Performance Optimizations

Findings from agnosys + kybernet benchmarks. Syscalls at parity. Gaps in compute and allocation.

### Tier 1 — Pure Compute

| # | Optimization | Target | Status |
|---|-------------|--------|--------|
| 1 | Constant folding | `classify_signal`: 2ns vs Rust 1ns | Deferred — codebuf rewind approach crashed. Needs token-level pre-scan. |
| 2 | Branch optimization | `notify_parse`: 20ns vs Rust 2ns | if/elif chains → jump tables for dense integer switches |
| 3 | Inline small functions | `W* macros`: 7ns vs Rust 1ns | Eliminate call/ret overhead for trivial functions |

### Tier 2 — Allocation

| # | Optimization | Target | Status |
|---|-------------|--------|--------|
| 4 | Stack-allocated small strings | `str_builder`: 371ns vs Rust 52ns | Avoid heap for strings < 64 bytes |
| 5 | Arena allocator for BPF | `seccomp_build`: 2.4us vs Rust 69ns | Batch-allocate BPF instructions |
| 6 | Path buffer reuse | `cgroup_path`: 466ns vs Rust 24ns | Pre-allocated path buffer |
| 7 | Return-by-value for small structs | General | Eliminate heap copy for structs <= 2 registers |

### Tier 3 — Codegen Quality

| # | Optimization | Effort | Status |
|---|-------------|--------|--------|
| 8 | ~~Dead code elimination~~ | ~~Medium~~ | **Done** (v1.7.0). Unreachable functions get 3-byte stub (xor eax,eax; ret). Token scan with STREQ comparison, skips module-scoped and mangled names. ~1.5KB saved on hello-world with stdlib. |
| 9 | Register allocation | High | Reduce spills to stack |
| 10 | Tail call optimization | Low | `return f()` → `jmp f` instead of `call f; ret` |

---

## Systems Language Features

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation, >1024 functions |
| Struct padding/alignment (sizeof) | Medium | ABI compat, FFI |
| Unions, bitfields | Medium | Hardware, protocols |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32) | Medium | Memory efficiency |
| Optimization passes (-O1) | Very High | Performance (see Tier 1-3 above) |

---

## Open Limits

| Limit | Current | Detail |
|-------|---------|--------|
| Functions | 1024 | Error at limit. Fix: multi-file compilation. |
| Variables (VCNT) | 512 | **Primary blocker.** Never resets between functions. Enum variants, params, and locals all accumulate. agnostik (12 modules + stdlib) needs ~590 slots. Fix: scope-aware reset or separate enum table. |
| Input buffer | 256KB (v1.7) | Fixed in v1.7.0. Was 131KB. |
| Code buffer | 196608 bytes | Overflow now detected (v1.7.0). |
| Identifier buffer | 65536 bytes | Error with count at limit. |
| Preprocessor macros | 16 | Sufficient for current use. |
| Preprocessor passes | 16 | Handles deep include nesting. |

---

## Architecture Backends

| # | Architecture | Status |
|---|-------------|--------|
| 1 | x86_64 | **Done** — self-hosting, 131KB |
| 2 | aarch64 | **Done** — kernel mode, arch-specific asm |
| 3 | RISC-V | Planned — open ISA |
| 4 | MIPS | Planned |
| 5 | Xtensa | Planned |

---

## Crate Migration

108 repos, ~1M lines. See [migration-strategy.md](migration-strategy.md) for the full plan.

---

## Known Gotchas

| # | Behavior | Fix |
|---|----------|-----|
| 1 | Global var as loop bound re-evaluates each iteration | Snapshot to local: `var limit = G; for (...)` |
| 2 | Inline asm `[rbp-N]` clobbers function params | Use globals or dummy locals to push offsets |
| 3 | `var buf[N]` is N bytes, not N elements | `var buf[120]` for 120-byte struct |
| 4 | `return a == b` fails | Fixed in v1.7.0 |
| 5 | Large projects hit VCNT limit (512 vars) | Minimize enum variants, use raw integers for large enums (LinuxCapability, SeccompArch). Use `syscalls_min.cyr` instead of full `syscalls.cyr` (saves 122 slots). |
| 6 | `include` directive segfaults on large chains | Use `command cat file1 file2 \| cc2` instead of `include` for 4+ large files |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- 108 repos / ~1M lines is the real measure of success
- Subprocess bridge covers migration before FFI is ready
- Two-step bootstrap for any heap offset change
