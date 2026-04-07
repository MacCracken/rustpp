# Cyrius Development Roadmap

> **v1.7.1.** 134KB self-hosting compiler, both architectures.
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
| 1 | **SIGILL on large binaries with bench.cyr + all modules** | P1 | Compiling 12 agnostik modules + bench.cyr (~500 functions, ~600 VCNT) produces SIGILL (exit 132) or SIGSEGV (exit 139) when calling the second function after main(). Same code works with fewer modules (~3-4). The test suite (main.cyr with assert.cyr) compiles and runs fine at the same module count — the issue is specific to bench.cyr's additional functions/vars tipping the binary past a codegen threshold. Suspect: fixup table corruption or code buffer address miscalculation for function calls in large binaries. |
| 2 | **Bump allocator never frees — no arena/reset pattern** | P2 | `alloc_reset()` exists but is unsafe to use between benchmark iterations because previously allocated bench structs become invalid. Need either: (a) arena allocator with named arenas, or (b) alloc_reset that doesn't invalidate outstanding pointers. Current workaround: use enough heap (auto-grows via brk) and accept the leak. |
| 3 | ~~Many local vars → SIGILL~~ | ~~P1~~ | **Fixed** (v1.7.4). fn_local_names, local_depths, local_types had 64-slot limit. The 65th local overflowed into var_types causing parse errors and wrong codegen. Relocated all three to 0x91000+ with 256 entries each. |
| 4 | **Include preprocessor fails for bench+modules (v1.7.3)** | P1 | `include` of bench functions + 6+ agnostik modules produces `unexpected '=='` at ~line 2486. Same code works with 3 modules (error+types+telemetry). The test suite (12 modules + assert.cyr) works fine. The trigger appears to be total expanded source crossing a specific threshold when bench-style code (many small functions calling now_ns) is combined with the full module set. |

Fixed in v1.7.1:
- AGNOS 25-syscall kernel compiles (97KB, ifdef+include in PP_IFDEF_PASS)
- agnostik 12-module port compiles (84KB, 58 tests pass)
- Nested for-loops with complex expressions work

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
| 1 | Constant folding | `classify_signal`: 2ns vs Rust 1ns | Three approaches tried — all break self-hosting. (1) Token-level shift/NOP: corrupts DCE token indices. (2) Codegen-level SCP rewind: cc3 built from modified source produces 0-byte output even when no folding occurs. Adding ANY new globals or branches to parse.cyr changes the compiler binary structure enough to break it. Root cause: compiler source is at the edge of buffer limits (162KB expanded) and any structural change shifts codebuf layout. Needs input buffer expansion to be fully stable FIRST. |
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
| 10 | ~~Tail call optimization~~ | ~~Low~~ | **Done** (v1.7.2). `return fn(args);` → epilogue + `jmp fn`. Detects `) ;` after call to confirm tail position. 1M recursive calls without stack overflow. |

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
| Variables (VCNT) | 2048 | Never resets between functions. Expanded from 512 in v1.7.0. Overlap bug fixed. |
| Input buffer | 256KB (v1.7) | Fixed in v1.7.0. Was 131KB. |
| Code buffer | 196608 bytes | Overflow now detected (v1.7.0). |
| Identifier buffer | 65536 bytes | Error with count at limit. |
| Preprocessor macros | 16 | Sufficient for current use. |
| Preprocessor passes | 16 | Handles deep include nesting. |

---

## Architecture Backends

| # | Architecture | Status |
|---|-------------|--------|
| 1 | x86_64 | **Done** — self-hosting, 134KB |
| 2 | aarch64 | **Done** — kernel mode, arch-specific asm |
| 3 | RISC-V | Planned — open ISA |
| 4 | MIPS | Planned |
| 5 | Xtensa | Planned |

---

## Crate Migration

108 repos, ~1M lines. See [migration-strategy.md](migration-strategy.md) for the full plan.

---

## cyrius-x — Portable Bytecode (v2.0+)

A Cyrius-native portable bytecode format. Not WASM — designed for AGNOS, systems-first, agent-native.

**Why not WASM**: WASM was designed for browsers — no raw syscalls, 32-bit memory model (64-bit still drafting), no native threads, GC still in progress, JavaScript interop baggage. cyrius-x is designed for sovereign systems.

**What cyrius-x provides**:
- One bytecode, every architecture (x86, ARM, RISC-V, MIPS, Xtensa, satellites)
- kavach sandbox integration native — the bytecode IS sandboxed
- 64-bit native (i64), raw syscall support
- Tiny interpreter (~10-20KB, Cyrius-compiled)
- sigil-signed packages, libro-audited execution

**Compilation targets**:
```
cyrius source → cyrius-native (x86_64, aarch64, etc.) — direct, sovereign
cyrius source → cyrius-x (portable bytecode) — runs anywhere, sandboxed
```

| Phase | Scope |
|-------|-------|
| 1 | Bytecode format specification |
| 2 | cyrius-x emitter backend |
| 3 | cyrius-x interpreter (Cyrius-compiled, ~10-20KB) |
| 4 | kavach sandbox integration |
| 5 | Agent distribution (one binary, all architectures) |
| 6 | JIT (cyrius-x → native for hot paths) |

**Replaces**: WASM (server/edge/IoT), JVM (enterprise), .NET CLR (applications).

---

## cyrius-ts — TypeScript/JavaScript Replacement (v2.0+)

Not a transpiler to JavaScript. A replacement for the entire JS/TS runtime stack.

| Problem | JS/TS | cyrius-ts |
|---------|-------|-----------|
| Runtime | V8/Node (10MB+) | cyrius-x interpreter (~10-20KB) |
| Types | Erased at runtime | Enforced at compile + runtime |
| Packages | npm (node_modules, 300MB avg) | cyrb (zero deps default) |
| Security | `npm install` runs arbitrary code | No install scripts, sigil-verified |
| Null | 6 falsy values | `0` is false, everything else is true |
| Binary | V8 alone ~30MB | Complete runtime <50KB |
| Startup | Node.js 30-50ms | cyrius-x <1ms |
| Edge | V8 cannot run on ESP32 | cyrius-x runs on $4 microcontrollers |

| Phase | Scope |
|-------|-------|
| 1 | Web-pattern syntax sugar (async handlers, JSON native, template strings) |
| 2 | HTTP server library (native, no framework) |
| 3 | DOM-equivalent for aethersafha |
| 4 | JS/TS migration tool (`cyrb port-ts`) |
| 5 | npm compatibility layer (consume packages in cyrius-x sandbox) |

**The pitch**: Everything Node.js does in 30MB and 50ms, cyrius-ts does in 50KB and <1ms. On a $4 microcontroller. With zero `node_modules`.

---

## Known Gotchas

| # | Behavior | Fix |
|---|----------|-----|
| 1 | Global var as loop bound re-evaluates each iteration | Snapshot to local: `var limit = G; for (...)` |
| 2 | Inline asm `[rbp-N]` clobbers function params | Use globals or dummy locals to push offsets |
| 3 | `var buf[N]` is N bytes, not N elements | `var buf[120]` for 120-byte struct |
| 4 | ~~`return a == b` fails~~ | Fixed in v1.7.0 |
| 5 | ~~VCNT limit 512~~ | Fixed in v1.7.0 — expanded to 2048 |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- 108 repos / ~1M lines is the real measure of success
- Subprocess bridge covers migration before FFI is ready
- Two-step bootstrap for any heap offset change
