# Cyrius Development Roadmap

> **v3.10.0.** 299KB self-hosting compiler, x86_64 + aarch64.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc3 (299KB).
> 36 test suites, 5 fuzz harnesses, 10 benchmarks. 41 stdlib modules + 5 deps.
> `cyrius deps` auto-resolves from cyrius.toml. Auto-include on build.
> `#derive(accessors)`, multi-return, switch blocks, defer (all exit paths).

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| Layout-dependent codegen Heisenbug | Libro PatraStore tests | Specific function combinations shift binary layout past a threshold causing jump misfire (SIGSEGV). Not size-dependent — adding/removing code changes layout and crash disappears. Workaround: isolated test binary. Needs debugger or basic-block analysis (v3.10.0). |

---

## Shipped (v3.7.0 — v3.9.7)

<details>
<summary>Click to expand shipped items</summary>

### v3.7.x — Language Features

- **v3.7.0**: Float literal lexer fix (unblocked avatara), fixup table 8192→16384
- **v3.7.1**: `#derive(accessors)` — auto-generate field getters/setters for heap-allocated structs
- **v3.7.2**: Native multi-return (`return (a, b)` → rax:rdx), destructuring bind (`var x, y = fn()`)
- **v3.7.4**: Switch case block bodies (`case N: { ... }`)

### v3.8.x — Safety & Tooling

- **v3.8.0**: Defer on all exit paths (per-defer runtime flags), `-v` verbose flag, `#skip-lint`, bare block statement, aarch64 arch-agnostic codegen (5 CI failures fixed)
- **v3.8.1**: Linter brace tracking skips string literals and comments

### v3.9.x — Refactor, Harden & Tooling

- **v3.9.0**: DSE pass extracted, derive struct parser dedup (-147 lines, -5.4KB binary)
- **v3.9.1**: aarch64 heap map synced with x86 (all limits aligned)
- **v3.9.2**: `cyrius deps` command — reads cyrius.toml, resolves deps into lib/
- **v3.9.3**: Auto-include from cyrius.toml — zero manual stdlib/dep includes needed
- **v3.9.4**: Release pipeline builds `cyrius` tool from source (not shell script)
- **v3.9.5**: Bootstrap compiler renamed: stage1f → **cyrc**
- **v3.9.6**: CYRIUS_HOME env var, git clone fallback for deps in CI
- **v3.9.7**: Release tarball stdlib packaging fix, `--dry-run` on build/run/test/init/port/deps/clean
- **v3.9.8**: `cyrius init` generates `.cyrius-toolchain` + CI/release workflows, `cyrius deps` works without cc3

</details>

---

## v3.10.x — Ergonomics & Diagnostics

**Goal:** Remove the daily friction that costs every agent and every port time. Low-effort items with universal downstream benefit, shipped before the 4.0 cleanup.

### P0 — Ship before 4.0

| Version | Feature | Effort | Details |
|---------|---------|--------|---------|
| v3.10.0 | **Undefined symbol diagnostic** | Medium | **Highest-impact fix in the roadmap.** Calling a non-existent function silently compiles and crashes at runtime (SIGILL/SIGSEGV). No error, no warning — just a jump to address 0. Root cause: forward-reference resolution never validates the target exists. Discovered during ai-hwaccel port (`assert_report()` vs `assert_summary()` — hours of debugging a 3-character typo). Every downstream project is exposed to this. Fixup-table validation pass at link time. |
| v3.10.0 | **`+=` / `-=` / `*=` operators** | Low | 101 instances of `i = i + 1` in ai-hwaccel alone. Every loop, every counter, every accumulator. Most requested syntactic sugar across all downstream projects. Desugars to `i = i + 1` in the parser — zero codegen change. Also fixes Known Gotcha #6 (`for` step must be `i = i + 1`). |
| v3.10.0 | **Negative integer literals** | Low | `0 - 1` workaround used everywhere. Lexer currently rejects `-1` — needs unary minus in expression position. Parser change only. Also fixes Known Gotcha #7. |
| v3.10.0 | **Dep resolution ordering** | Low | `cyrius build` prepends stdlib after dep modules, causing `strstr` (and potentially other stdlib functions) to be undefined when dep modules reference them. Fix: ensure stdlib is always prepended before all dep modules. |
| v3.10.0 | **`--dry-run` for deps** | Low | `cyrius deps --dry-run` shows what would be resolved without writing files. Debugging aid for CI and new projects. |

### P1 — Ship during 3.10.x

| Version | Feature | Effort | Details |
|---------|---------|--------|---------|
| v3.10.1 | **File:line error messages** | Medium | cc3 errors report token indices (e.g. `error:10169`) not file:line. Hard to locate issues in multi-file builds with 10K+ combined lines. Kybernet + deps = ~10K lines; tracking down `unexpected '{'` required manual bisection. Track source file + line through preprocessing. |
| v3.10.1 | **`rep movsb`/`rep stosb` for memcpy/memset** | Medium | stdlib memcpy(128) = 369 ns, memset(128) = 261 ns — byte-loop implementation. `rep movsb`/`rep stosb` or SIMD would bring these under 10 ns. Every program that copies buffers pays this tax. Universal perf improvement. |
| v3.10.1 | **Optimized strlen** | Low | stdlib strlen(52 chars) = 94 ns — byte-loop scan. SSE4.2 `pcmpistri` or word-at-a-time would be 5-10x faster. Impacts all string-heavy code. |
| v3.10.1 | **Bump allocator soft reset** | Low | `alloc_reset()` + `alloc_init()` = 1175 ns due to brk syscall. Soft reset (move bump pointer back) eliminates the syscall → under 10 ns. |
| v3.10.2 | **`cyrius init <name>`** | Low | Project scaffolding: creates `src/lib.cyr`, `tests/`, `cyrius.toml` (name pre-filled), `VERSION` (0.1.0), `README.md`, `CHANGELOG.md`, `CLAUDE.md` template, `docs/development/roadmap.md` template. Enforces consistency across the 100+ repo ecosystem. |
| v3.10.2 | **`cyrius check`** | Low | Unified validation: fmt + lint + test + build in one command. Standardizes the P(-1) workflow across all downstream projects. |
| v3.10.2 | **`cyrius bench --baseline`** | Low | Save a benchmark run as baseline CSV. `cyrius bench --compare baseline.csv` diffs against saved baseline. Automates the "rerun after optimizer ships" workflow. |

### P2 — Ship if time before cleanup

| Version | Feature | Effort | Details |
|---------|---------|--------|---------|
| v3.10.3 | **Per-function register alloc** | Medium | Opt-in `#regalloc` directive. Per-function analysis only. Needs basic-block analysis for safe LASE. Key benchmark: avatara single profile 249ns → target sub-50ns. |
| v3.10.3 | **Dead function warning** | Low | Functions included but never called still emit code. Pre-linker warning for uncalled functions. ai-hwaccel: 26 stdlib modules included, many functions unused. Helps binary-size-conscious work. |
| v3.10.4 | **Deferred formatting (defmt)** | High | String interning + decode ring. Format strings stay as interned IDs at runtime. |
| v3.10.4 | **u128** | High | 128-bit integers via register pairs. Unblocks native bigint and closes number-theory benchmark gap (mod_mul with 64 additions per multiply → native 128-bit multiply). |

---

## Cleanup — Pre-4.0 Audit

Internal cleanup pass before the major version bump. Same discipline as v3.9.0 but at the 3.x→4.0 boundary.

| Item | Effort | Details |
|------|--------|---------|
| **Layout-dependent Heisenbug** | High | Close the libro PatraStore codegen bug. Needs basic-block analysis or binary-level debugging. If register alloc landed in 3.10.3, the analysis infrastructure may already exist. |
| **Stale shipped sections** | Low | Collapse all shipped v3.7–v3.9 roadmap entries into completed-phases.md. |
| **Known Gotchas audit** | Low | Review gotchas #1–#8. Some are fixed by 3.10.x items (`+=` fixes #6, negative literals fixes #7). Update or remove resolved entries. |
| **Bootstrap closure** | Low | Full three-step bootstrap verify. seed → cyrc → bridge → cc3 → cc3_check byte-identical. |
| **Benchmark baseline** | Low | Save benchmark baselines for all downstream crates before 4.0 ships. The "before" picture for the optimizer story. |

---

## v4.0.0 — Platform & Scale

Major release. Multi-file compilation, new platforms, dead-code elimination. The version where "young language, no optimizer" stops being a caveat.

### Core

| Feature | Effort | Details |
|---------|--------|---------|
| **Multi-file linker** | High | .o emission done (v2.6.4). Need: read .o, resolve symbols, patch relocations, emit executable. Unblocks dead-code elimination — currently every included function lands in the binary whether called or not. kybernet went from 93KB to 486KB when argonaut deps were included. |
| **Dead-code elimination** | High | Depends on multi-file linker. Only emit functions that are actually called. Transforms binary sizes across the ecosystem. kybernet 486KB → estimated back toward 100KB range. |
| **PIC codegen (Phase 2)** | High | `.so` output (ET_DYN), GOT/PLT. Partial in v3.4.12. |

### Platforms

| Feature | Effort | Details |
|---------|--------|---------|
| **macOS x86_64** | High | Mach-O emitter. Stubs scaffolded in v3.1. |
| **macOS aarch64** | High | Mach-O emitter. Apple Silicon native. |
| **Windows x86_64** | High | PE/COFF emitter. Stub scaffolded in v3.1. |

### Diagnostics & Ergonomics

| Feature | Effort | Details |
|---------|--------|---------|
| **LSP** | High | Language Server Protocol for IDE integration. Transforms the editing experience for agents and humans. |
| **Stack slices** | High | `var buf[512]: slice` — stack buffer with companion length. Safer bounded buffers. |

---

## Post-4.0 — Ergonomics & Codegen

Language improvements driven by real porting pain across the AGNOS ecosystem. Quality-of-life and performance features that don't gate platform work but reduce boilerplate and close the codegen gap with LLVM.

| Feature | Effort | Details |
|---------|--------|---------|
| **Jump tables for enum dispatch** | High | types.cyr has 79 if-chains for enum→value mapping. LLVM compiles to jump tables (O(1)). Cyrius emits linear if-chains (O(n)). Accounts for 10-35x gap on enum-heavy micro-benchmarks. Requires computed goto or indexed branch. |
| **`#derive(accessors)` adoption tooling** | Low | Feature exists (v3.7.1) but zero downstream adoption. Need: migration guide, `cyrius refactor --derive` tool, or documented before/after examples. ai-hwaccel has 274 manual accessor calls. |
| **Struct initializer syntax** | Medium | `var p = Point { x: a, y: b, z: c }` instead of alloc + 3× store64. Eliminates 3-4 lines per struct creation across ~50 locations in ai-hwaccel. |

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
| Linux x86_64 | ELF | **Done** — primary, 299KB self-hosting |
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
| **Done** | sakshi, majra, bsp, cyrius-doom, mabda, hadara (native) |
| **Done** | sigil, patra, libro, shravan, tarang, yukti |
| **Done** | avatara, ai-hwaccel, hoosh, itihas |
| **In progress** | bhava, hisab |
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

| # | Behavior | Workaround | Fix Target |
|---|----------|------------|------------|
| 1 | `var buf[N]` is N **bytes** | `var buf[640]` for 80 i64 values | — |
| 2 | Global var loop bound re-evaluates | Snapshot to local | — |
| 3 | Inline asm `[rbp-N]` clobbers params | Use globals or dummy locals | — |
| 4 | Large `var buf[N]` exhausts output buffer | Use `alloc(N)` for >4KB | — |
| 5 | Mixed `&&`/`||` requires explicit parens | Write `a && (b \|\| c)` | — |
| 6 | `for` step must be `i = i + 1` | No `+=` syntax | **v3.10.0** |
| 7 | No negative literals | Use `(0 - N)` | **v3.10.0** |
| 8 | No closures capturing variables | Use named functions + globals | — |

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
- **Never use raw `cat | cc3` for projects** — always `cyrius build`
- **v3.9.8 recommended minimum** — auto-include, `cyrius deps`, `.cyrius-toolchain`
