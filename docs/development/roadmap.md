# Cyrius Development Roadmap

> **v3.9.5.** 299KB self-hosting compiler, x86_64 + aarch64.
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
| v3.8.1 | **Linter: string/comment brace fix** | Low | **Shipped.** Brace tracking skips string literals and comments. |

---

## v3.9.0 — Refactor & Harden

Internal cleanup. No new features — same semantics, cleaner codebase.

| Item | Effort | Details |
|------|--------|---------|
| **Extract DSE pass** | Low | Move dead-store elimination from PARSE_FN_DEF into its own function. |
| **Extract shared struct parser** | Medium | PP_DERIVE_SERIALIZE (332 lines) and PP_DERIVE_ACCESSORS (147 lines) share struct parsing. Extract common struct field parser. |
| **Split PARSE_FACTOR** | Medium | 412-line builtin dispatch. Split into sub-handlers (store/load, SIMD, f64). |
| **Sync aarch64 heap map** | Medium | main_aarch64.cyr limits stale: input 256KB→512KB, tokens 65536→262144, str_data 8KB→256KB, fixups 8192→16384. |
| **Stale comment cleanup** | Low | Remove version-tagged comments (v3.0–v3.6) that describe now-obvious behavior. |
| **`cyrius deps` command** (v3.9.2) | Medium | **Shipped.** Symlinks dep modules into `lib/` from cyrius.toml `[deps]`. Uses `path` locally, `git` for CI. |
| **`cyrius deps` namespace collision** (v3.9.3) | High | `cyrius deps` flattens all dep modules into `lib/` without namespacing. When two deps have the same filename (e.g. agnostik `src/error.cyr` and argonaut/libro `lib/error.cyr`), the last writer wins — silently overwrites the first. Same collision for `types.cyr` (agnostik vs argonaut). Discovered in kybernet CI: `cyrius deps` resolves correctly but `error.cyr` and `types.cyr` get overwritten, causing `SECCOMP_ALLOW` undefined (agnostik's security.cyr depends on agnostik's error.cyr which was overwritten by libro's). Fix: namespace output as `lib/<dep>/module.cyr` (e.g. `lib/agnostik/error.cyr`, `lib/argonaut/error.cyr`) or detect and error on collision. Blocks all downstream projects with overlapping dep filenames. |

---

## v3.10.0 — Optimization & Types

| Version | Feature | Effort | Details |
|---------|---------|--------|---------|
| v3.10.0 | **Per-function register alloc** | Medium | Opt-in `#regalloc` directive. Per-function analysis only. Needs basic-block analysis for safe LASE. Key benchmark: 249ns vs 63ns. |
| v3.10.1 | **Deferred formatting (defmt)** | High | String interning + decode ring. Format strings stay as interned IDs at runtime. |
| v3.10.2 | **u128** | High | 128-bit integers via register pairs. Unblocks native bigint. |

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
| **`rep movsb`/`rep stosb` for memcpy/memset** | Medium | stdlib memcpy(128) = 369 ns, memset(128) = 261 ns — byte-loop implementation. `rep movsb`/`rep stosb` or SIMD would bring these under 10 ns. Discovered via kybernet benchmarks. Every program that copies buffers pays this tax. |
| **Optimized strlen** | Low | stdlib strlen(52 chars) = 94 ns — byte-loop scan. SSE4.2 `pcmpistri` or word-at-a-time would be 5-10x faster. Impacts all string-heavy code (cgroup paths, logging, notify parsing). |
| **Bump allocator reset without brk** | Low | `alloc_reset()` + `alloc_init()` cycle = 1175 ns due to brk syscall. A soft reset (just move the bump pointer back) would eliminate the syscall and bring this under 10 ns. Kybernet benchmarks reset between groups to avoid OOM. |
| **File:line error messages** | Medium | cc3 errors report token indices (e.g. `error:10169`) not file:line. Hard to locate issues in multi-file builds with 10K+ combined lines. Kybernet + deps = ~10K lines; tracking down `unexpected '{'` required manual bisection. |

---

## Post-4.0 — Ergonomics & Codegen

Language improvements driven by real porting pain across the AGNOS ecosystem. These are quality-of-life and performance features that don't gate any platform work but reduce boilerplate and close the codegen gap with LLVM.

| Feature | Effort | Details |
|---------|--------|---------|
| **`+=` / `-=` / `*=` operators** | Low | 101 instances of `i = i + 1` in ai-hwaccel alone. Every loop, every counter, every accumulator. Most requested syntactic sugar across all downstream projects. Desugars to `i = i + 1` in the parser — zero codegen change. |
| **Negative integer literals** | Low | `0 - 1` workaround used 6 times in ai-hwaccel, more in every project. Lexer currently rejects `-1` — needs unary minus in expression position. |
| **Jump tables for enum dispatch** | High | types.cyr has 79 if-chains for enum→value mapping. LLVM compiles these to jump tables (O(1) dispatch). Cyrius emits linear if-chains (O(n)). Accounts for 10-35x gap on enum-heavy micro-benchmarks. Requires: computed goto or indexed branch in x86/aarch64 backends. |
| **`#derive(accessors)` adoption tooling** | Low | `#derive(accessors)` exists (v3.7.1) but zero downstream adoption. ai-hwaccel has 274 manual load64/store64 struct accessor calls. Need: migration guide, `cyrius refactor --derive` tool, or at minimum document the pattern with before/after examples. |
| **Struct initializer syntax** | Medium | Currently: `var p = alloc(SIZE); store64(p, a); store64(p+8, b); store64(p+16, c);`. Want: `var p = Point { x: a, y: b, z: c }`. Eliminates 3-4 lines per struct creation. ai-hwaccel creates structs in ~50 locations. |
| **Dead function warning** | Low | Functions included but never called still emit code. With single-file compilation this inflates binaries. ai-hwaccel: 26 stdlib modules included, many functions unused. Pre-linker: emit warnings for uncalled functions. |

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
