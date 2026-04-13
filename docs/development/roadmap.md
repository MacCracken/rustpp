# Cyrius Development Roadmap

> **v3.8.1.** 304KB self-hosting compiler, x86_64 + aarch64.
> 36 test suites, 5 fuzz harnesses, 10 benchmarks. Heap audit clean (43 regions, 0 overlaps).
> 41 stdlib modules + 5 deps (sakshi, patra, sigil, yukti, mabda).
> 512KB input, 1MB codebuf, 1MB preprocess, 256KB str_data, 64KB tok_names, 262K tokens.
> Expression-position comparisons, `#assert`, Str auto-coercion, string interning, `lib/cffi.cyr`, `#derive(accessors)`, multi-return, switch blocks.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| PatraStore stack corruption in large binaries | Libro 1.0.3 gated tests | str_builder + patra_exec in >300KB binaries — compiler/stdlib bug |

---

## v3.7.0 — Bug fixes + limit expansions (Shipped)

Float literal lexer fix (wrong buffer read in large programs), fixup table
8192→16384 (unblocked avatara). See CHANGELOG.

## v3.7.1 — `#derive(accessors)` (Shipped)

Auto-generate field accessors for heap-allocated structs. Same preprocessor
codegen pattern as `#derive(Serialize)`. Saves ~30 lines per struct across
every downstream project. Kybernet reviewed — needs stdlib includes added
(downstream fix, not a compiler issue).

```cyrius
#derive(accessors)
struct Point { x; y; }
# Generates: Point_x(p), Point_set_x(p, v), Point_y(p), Point_set_y(p, v)
```

## v3.7.2 — Native multi-return (Shipped)

`return (a, b)` → rax:rdx register pair. `var x, y = fn()` → destructure.
Eliminates the `alloc(16)` pair-struct workaround. `ret2`/`rethi` builtins
still work (backward compat).

## v3.7.4 — Switch case blocks (Shipped)

`case N: { ... }` block bodies in switch statements. Bare block
statement support in PARSE_STMT. Pre-scan brace depth tracking.

---

## v3.8.0 — Safety Without Cost

Compile-time guarantees that produce identical machine code. v3.8.0 shipped defer+verbose+`#skip-lint`. aarch64 backend partially fixed (5 CI failures resolved), remaining aarch64 issue blocks full release.

| Version | Feature | Effort | Details |
|---------|---------|--------|---------|
| v3.8.0 | **Defer on all exit paths** | Medium | **Shipped.** Per-defer runtime flags + backpatch trampoline. Unreached defers are skipped. |
| v3.8.0 | **`-v` verbose flag** | Low | **Shipped.** Displays compiler path, source/output paths, defines, binary size on stderr. |
| v3.8.0 | **`#skip-lint`** | Low | **Shipped.** Lines containing `#skip-lint` exempt from lint rules. For unavoidable long strings. |
| v3.8.0 | **aarch64 arch-agnostic codegen** | Medium | **Partial.** 5 CI failures fixed (ETESTAZ, EMOVRDXRAX, EMOVRA_RDX helpers). Remaining aarch64 issue blocks release. |
| v3.8.1 | **Per-function register alloc** | Medium | Opt-in `#regalloc` directive. Per-function analysis only — avoids the v3.3.12 global r12 regression. May also expose the PatraStore stack corruption root cause. Key benchmark: Cyrius `kabbalah_tiphareth()` = 249ns (40+ store64 instructions) vs Rust `Sephira::Tiphareth.profile()` = 63ns (LLVM-optimized field writes). |
| v3.8.2 | **Deferred formatting (defmt)** | High | String interning (v3.6.1) + decode ring. Format strings stay as interned IDs at runtime; decoding happens at the log reader. Eliminates `fmt_sprintf` overhead in hot paths. |
| v3.8.3 | **u128** | High | 128-bit integers via register pairs. Unblocks native bigint without 4-limb emulation. |

---

## v4.0.0 — Platform & Scale

Major release. Multi-file compilation, new platforms, dead-code elimination.

| Feature | Effort | Details |
|---------|--------|---------|
| **Multi-file linker** | High | .o emission done (v2.6.4). Need: read .o, resolve symbols, patch relocations, emit executable. Unblocks dead-code elimination — currently every included function lands in the binary whether called or not. ai-hwaccel: 26 stdlib modules included, binary carries unused code from all of them. |
| **Undefined symbol diagnostic** | Medium | Calling a non-existent function silently compiles and crashes at runtime (SIGILL/SIGSEGV). No error, no warning — just a jump to address 0. Root cause: forward-reference resolution never validates the target exists. Discovered during ai-hwaccel port (`assert_report()` vs `assert_summary()` — hours of debugging a 3-character typo). Every downstream project is exposed to this. |
| **PIC codegen (Phase 2)** | High | `.so` output (ET_DYN), GOT/PLT. Partial in v3.4.12. |
| **macOS targets** | High | Mach-O emitter. Stubs scaffolded in v3.1. |
| **Windows target** | High | PE/COFF emitter. Stub scaffolded in v3.1. |
| **Dep resolution ordering** | Low | `cyrius build` prepends stdlib after dep modules, causing `strstr` (and potentially other stdlib functions) to be undefined when dep modules reference them. Discovered in kybernet build: agnostik/types.cyr calls `strstr()` but string.cyr is prepended after agnostik. Warning-only — no runtime impact for unused code paths. Fix: ensure stdlib is always prepended before all dep modules. |
| **LSP** | High | Language Server Protocol for IDE integration. |
| **Stack slices** | High | `var buf[512]: slice` — stack buffer with companion length. |

---

## Stdlib (41 modules + 5 deps)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, csv, base64, regex, math, matrix, bigint |
| Network | net, http, ws, tls |
| Filesystem | fs |
| Audio | audio (ALSA PCM) |
| Logging | log |
| Time | chrono |
| Knowledge | vidya |
| Interop | mmap, dynlib, cffi |
| Tracing (dep) | sakshi, sakshi_full |
| Database (dep) | patra |
| Security (dep) | sigil |
| Hardware (dep) | yukti |
| GPU (dep) | mabda |

---

## Platform Targets

| Platform | Format | Status |
|----------|--------|--------|
| Linux x86_64 | ELF | **Done** — primary, 290KB self-hosting |
| Linux aarch64 | ELF | **Done** — cross + native |
| macOS x86_64 | Mach-O | Stub (v3.1) — v4.0.0 |
| macOS aarch64 | Mach-O | Stub — v4.0.0 |
| Windows x86_64 | PE/COFF | Stub (v3.1) — v4.0.0 |
| RISC-V | ELF | Planned |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |

---

## Ports & Ecosystem

| Status | Repos |
|--------|-------|
| **Done** | agnostik, agnosys, argonaut, kybernet, nous, ark |
| **Done** | sakshi, majra, bsp, cyrius-doom, mabda |
| **Done** | sigil, patra, libro, shravan, tarang, yukti |
| **In progress** | bhava, hisab, avatara |
| **In progress** | ai-hwaccel (ported, 18 modules, 491 tests, 6 fuzz — needs majra+libro for full parity) |
| **Blocked** | vidya MCP (needs bote) |

---

## Open Limits

| Limit | Current | Notes |
|-------|---------|-------|
| Functions | 2048 | |
| Variables | 8192 | |
| Globals (initialized) | 1024 | Use enums for constants |
| Locals per function | 256 | |
| Fixup entries | 16384 | Expanded from 8192 in v3.7.0 |
| Structs | 64 | Expanded from 32 in v3.6.6 |
| Struct fields | 32 | Per struct |
| Input buffer | 512KB | Hard error on overflow |
| Code buffer | 1MB | |
| Output buffer | 1MB | |
| String data | 256KB | |
| Identifier names | 64KB | |
| Tokens | 262144 | |

---

## Known Gotchas

| # | Behavior | Workaround |
|---|----------|------------|
| 1 | `var buf[N]` is N **bytes** | `var buf[640]` for 80 i64 values |
| 2 | Global var loop bound re-evaluates | Snapshot to local |
| 3 | Inline asm `[rbp-N]` clobbers params | Use globals or dummy locals |
| 4 | Large `var buf[N]` exhausts output buffer | Use `alloc(N)` for >4KB |
| 5 | Mixed `&&`/`||` requires explicit parens | Write `a && (b \|\| c)` |
| 6 | `for` step must be `i = i + 1` | No `+=` syntax |
| 7 | No negative literals | Use `(0 - N)` |
| 8 | No closures capturing variables | Use named functions + globals |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Two-step bootstrap for any heap offset change
- Research before implementation — vidya entry before code
- Test after EVERY change, not after the feature is done
- Compile-time guarantees, zero runtime cost
- **v3.6.0 recommended minimum** — auto-coercion, string interning, cffi, expanded limits
