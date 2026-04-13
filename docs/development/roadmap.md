# Cyrius Development Roadmap

> **v4.1.2.** 309KB self-hosting compiler, x86_64 + aarch64.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc3 (309KB). Closure verified.
> 36 test suites, 102 regression assertions, 5 fuzz harnesses. 41 stdlib modules + 5 deps.
> `cyrius build` auto-resolves deps + auto-includes. File:line error messages.
> `+=`, `-=`, negative literals, `#derive(accessors)`, multi-return, switch blocks, defer.
> Undefined function diagnostic. 10+ downstream projects shipping.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| Layout-dependent codegen Heisenbug | Libro PatraStore tests | Workaround: isolated test binary. Needs basic-block analysis to diagnose. Not blocking releases. |

---

## Shipped

<details>
<summary>Click to expand shipped items (v3.7.0 → v4.1.0)</summary>

### v3.7.x — Language Features
- `#derive(accessors)`, native multi-return, switch case blocks, float literal fix, fixup table 8192→16384

### v3.8.x — Safety & Tooling
- Defer on all exit paths, `-v` verbose, `#skip-lint`, aarch64 arch-agnostic codegen, linter fixes

### v3.9.x — Refactor, Harden & Tooling
- DSE extraction, derive dedup (-147 lines), aarch64 heap map sync
- `cyrius deps`, auto-include, namespaced deps, `.cyrius-toolchain`
- Release pipeline fixes, CYRIUS_HOME, git clone fallback, `--dry-run`
- `cyrius init` with CI/release workflows, bootstrap rename (stage1f → cyrc)

### v3.10.x — Diagnostics & Ergonomics
- Undefined function diagnostic (fixup-time)
- `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`
- Negative integer literals (`-1`, `-x`, `-(expr)`)
- aarch64 width-aware encodings, auto-mkdir on build

### v4.0.0 — Major Release
- Toolchain complete: compiler + build tool + dep system + CI scaffolding
- Pre-4.0 audit: bootstrap verified, gotchas audited, baselines captured
- 6 downstream projects shipping: kybernet, argonaut, hadara, ai-hwaccel, hoosh, avatara

### v4.1.0 — File:Line Errors
- `#@file` markers in preprocessor, `FM_BUILD` + `FM_LOOKUP`
- `error:lib/alloc.cyr:42:` instead of `error:10169:`
- All 12 error/warning call sites updated

</details>

---

## v4.1.x — Compiler Optimization

Performance and binary size. The compiler understands its output better.

| Feature | Effort | Details |
|---------|--------|---------|
| **Dead function warning** | Low | Functions included but never called still emit code. Warn at fixup time. Helps binary-size-conscious work. |
| **`rep movsb`/`rep stosb`** | Low | Fast memcpy/memset in stdlib. 369ns → sub-10ns for 128-byte copies. |
| **Optimized strlen** | Low | SSE4.2 `pcmpistri` or word-at-a-time. 94ns → sub-20ns for 52 chars. |
| **Bump allocator soft reset** | Low | `alloc_reset()` without brk syscall. 1175ns → sub-10ns. |

---

## v4.2.0 — Basic-Block Analysis & Register Allocation

The compiler learns control flow. Foundation for all advanced optimizations.

| Feature | Effort | Details |
|---------|--------|---------|
| **Basic-block analysis** | Medium | Build CFG per function. Foundation for LASE, register alloc, Heisenbug diagnosis. |
| **Per-function register alloc** | Medium | Opt-in `#regalloc`. Keep hot locals in callee-saved registers. Key benchmark: 249ns → target sub-100ns. |
| **LASE (load-after-store elimination)** | Medium | With CFG, safely eliminate redundant stack loads. The v3.8.1 attempt failed without CFG. |
| **Layout Heisenbug diagnosis** | Medium | With CFG, audit the libro PatraStore codegen. Jump target analysis should expose the misfire. |

---

## v4.3.0 — LSP & Developer Experience

| Feature | Effort | Details |
|---------|--------|---------|
| **LSP** | High | Language Server Protocol. Go-to-definition, diagnostics, hover, completions. Written in Cyrius, built on cc4's file map and symbol tables. |
| **Stack slices** | High | `var buf[512]: slice` — stack buffer with companion length. |
| **Struct initializer syntax** | Medium | `var p = Point { x: a, y: b }` instead of alloc + store64. |

---

## v4.4.0 — Multi-File & Dead-Code Elimination

| Feature | Effort | Details |
|---------|--------|---------|
| **Multi-file linker** | High | .o emission done (v2.6.4). Read .o, resolve symbols, patch relocations, emit executable. Unblocks true DCE across compilation units. |
| **Dead-code elimination** | High | With linker + CFG, only emit functions actually called. kybernet 486KB → estimated 150-200KB. |
| **PIC codegen** | High | `.so` output (ET_DYN), GOT/PLT. Partial in v3.4.12. |

---

## v4.5.0 — Types & Codegen

| Feature | Effort | Details |
|---------|--------|---------|
| **u128** | High | 128-bit integers via register pairs. Unblocks native bigint. |
| **Deferred formatting (defmt)** | High | String interning + decode ring. Format strings as interned IDs at runtime. |
| **Jump tables for enum dispatch** | High | 79 if-chains → O(1) indexed branch. 10-35x on enum-heavy code. |

---

## v4.6.0 — macOS

| Feature | Effort | Details |
|---------|--------|---------|
| **macOS x86_64** | High | Mach-O emitter. Stubs scaffolded in v3.1. |
| **macOS aarch64** | High | Mach-O emitter. Apple Silicon native. |

---

## v4.7.0 — Windows

| Feature | Effort | Details |
|---------|--------|---------|
| **Windows x86_64** | High | PE/COFF emitter. Stub scaffolded in v3.1. |

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
| Linux x86_64 | ELF | **Done** — primary, 309KB self-hosting |
| Linux aarch64 | ELF | **Done** — cross + native |
| macOS x86_64 | Mach-O | Stub (v3.1) — v4.6.0 |
| macOS aarch64 | Mach-O | Stub — v4.6.0 |
| Windows x86_64 | PE/COFF | Stub (v3.1) — v4.7.0 |
| RISC-V | ELF | Planned |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |

---

## Ports & Ecosystem

| Status | Repos |
|--------|-------|
| **Done** | agnostik, agnosys, argonaut, kybernet, nous, ark |
| **Done** | sakshi, majra, bsp, cyrius-doom, mabda, hadara |
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
| Fixup entries | 16384 | |
| Structs | 64 | |
| Struct fields | 32 | Per struct |
| Input buffer | 512KB | |
| Code buffer | 1MB | |
| Output buffer | 1MB | |
| String data | 256KB | |
| Identifier names | 64KB | |
| Tokens | 262144 | |

---

## Known Gotchas

| # | Behavior | Workaround | Status |
|---|----------|------------|--------|
| 1 | `var buf[N]` is N **bytes** | `var buf[640]` for 80 i64 values | By design |
| 2 | Global var loop bound re-evaluates | Snapshot to local | By design |
| 3 | Inline asm `[rbp-N]` clobbers params | Use globals or dummy locals | By design |
| 4 | Large `var buf[N]` exhausts output buffer | Use `alloc(N)` for >4KB | By design |
| 5 | Mixed `&&`/`||` requires explicit parens | Write `a && (b || c)` | By design |
| 6 | ~~`for` step must be `i = i + 1`~~ | | **Fixed v3.10.3** |
| 7 | ~~No negative literals~~ | | **Fixed v3.10.3** |
| 8 | No closures capturing variables | Use named functions + globals | By design |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Two-step bootstrap for any heap offset change
- Test after EVERY change, not after the feature is done
- **Never use raw `cat | cc3` for projects** — always `cyrius build`
- **v4.0.0 recommended minimum** — auto-include, deps, file:line, undefined function diagnostic
