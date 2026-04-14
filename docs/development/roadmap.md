# Cyrius Development Roadmap

> **v4.8.0-alpha1.** 353KB self-hosting compiler, x86_64 + aarch64.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc3 (353KB). Closure verified.
> 41 test suites, 11 benchmarks, 5 fuzz harnesses. **42 stdlib modules** + 5 deps.
> New in 4.5.0: `lib/http_server.cyr` — HTTP/1.1 primitives, Content-Length-aware reads, URL decode, chunked/SSE.
> `cyrius build` auto-resolves deps + auto-includes. File:line error messages.
> Short-circuit `&&`/`||`, named-field struct init, x86-64 length decoder, `CYRIUS_SYMS`, `CYRIUS_DCE` (41% gzip cut).
> 10 downstream projects shipping.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| Layout-dependent memory corruption | Libro PatraStore tests | v4.3.1: localized with `CYRIUS_SYMS`. Crash is `memeq` called with NUL data ptr from `str_eq(entry_hash(a), entry_hash(b))` in large libro binary. Each `println` shifts the site — classic memory corruption signature. Root cause fix deferred to post-4.4.0 when byte-walking CFG lands. Workaround still in place (isolated test binary). |
| `&&` / `||` do not short-circuit | Silent miscompile; any guarded null check (`if (p != 0 && vec_len(p) > 0)`) crashes because the right side evaluates unconditionally | Confirmed active on 4.4.0 via bote feedback doc (item 2). Documented as short-circuit in `docs/cyrius-guide.md`. Workaround: nest `if` blocks. Real fix: short-circuit codegen emits `je`/`jne` over the right operand evaluation. |

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

## v4.4.0 — CFG & Single-CU Dead-Code Elimination

| Feature | Effort | Details |
|---------|--------|---------|
| **Basic-block / CFG pass** | Medium | Build per-function control flow graph from emitted bytes + jump target table (v4.2.0 infra). Foundation for DCE, LASE soundness, register alloc, Heisenbug diagnosis. |
| **Single-CU DCE** | Medium | With CFG, drop functions unreachable from `main` + referenced globals. Binary-size win without the multi-file linker prerequisite. |
| **libro PatraStore Heisenbug** | Medium | Use CFG to find the memory-corruption source flagged by CYRIUS_SYMS in 4.3.1. Unblocks libro's full test suite. |

---

## v4.5.0 — `lib/http_server.cyr` (shipped)

| Feature | Effort | Details |
|---------|--------|---------|
| **HTTP/1.1 server primitives** | Medium | Parse/build request+response, Content-Length-aware read, URL-decode, path segments, chunked/SSE support, accept-loop `http_server_run`. Unblocks bote, vidya, and any future service port — removes ~750 LOC of hand-rolled HTTP across consumers. Reference impl from bote team's proposal. |

Reordered from the original "multi-file linker" scope — porting pressure from bote/vidya shifted the priority to concrete stdlib infra. Linker work moves to v4.6.0.

---

## v4.6.0 — Multi-File Linker & Cross-Unit DCE

| Feature | Effort | Details |
|---------|--------|---------|
| **Multi-file linker** | High | .o emission done (v2.6.4). Read .o, resolve symbols, patch relocations, emit executable. |
| **Cross-unit DCE** | High | Extend 4.4.0 single-CU DCE across object files once the linker lands. kybernet 486KB → est. 150-200KB. |
| **HTTP keep-alive** | Low | Non-blocking accept + keep-alive replies for `lib/http_server.cyr`. Deferred from 4.5.0 per proposal § open questions. |

---

## v4.7.0 — PIC Codegen

| Feature | Effort | Details |
|---------|--------|---------|
| **PIC codegen** | High | `.so` output (ET_DYN), GOT/PLT. Partial in v3.4.12. Last piece before multi-platform work, since Mach-O/PE need position-independent references. |

---

## v4.8.0 — Types & Codegen (final 4.x minor)

| Feature | Effort | Details |
|---------|--------|---------|
| **u128** | High | 128-bit integers via register pairs. Unblocks native bigint. |
| **Deferred formatting (defmt)** | High | String interning + decode ring. Format strings as interned IDs at runtime. |
| **Jump tables for enum dispatch** | High | 79 if-chains → O(1) indexed branch. 10-35x on enum-heavy code. |
| **Register allocation** | High | Per-function `#regalloc`. Keep hot locals in callee-saved registers. Independent of cc5; ships on cc3. Key benchmark: 249 ns → sub-100 ns. |

---

## v5.0.0 — Multi-Platform (major)

**Scope: platforms only.** This is the release where Cyrius leaves single-platform ELF and lands on every OS and ISA that matters. Language refinements and DX improvements do not belong here — they ship in 4.x minors before the cut and 5.x minors after. A narrow 5.0 scope keeps the release auditable and the platform story clear.

The cc5 uplift is included **only as the platform enabler** — the mechanism by which a single compiler binary selects Mach-O / PE / ELF backends at runtime. Language-level cc5 benefits (per-block scoping, incremental compilation) are split out to 5.x; if they can ship earlier as 4.x incremental work, they will.

| Feature | Effort | Details |
|---------|--------|---------|
| **cc3 → cc5 uplift (platform-scoped)** | High | Generation bump focused on multi-arch backend selection from one binary. cc3 has carried self-hosting from v2.2 through 4.x — heap map near 14.8MB capacity, single-pass codegen. cc5 re-lands the compiler on top of the full 4.x infrastructure (CFG, length decoder, linker, PIC) for the backend-table dispatch that Mach-O/PE/ELF/RISC-V require. Two-step bootstrap doctrine stays: cc5 compiles cc5 byte-identical. |
| **macOS x86_64** | High | Mach-O emitter on cc5. Stubs scaffolded in v3.1. |
| **macOS aarch64** | High | Mach-O emitter on cc5. Apple Silicon native. |
| **Windows x86_64** | High | PE/COFF emitter on cc5. Stub scaffolded in v3.1. |
| **RISC-V (ELF)** | High | rv64 backend on cc5. Promoted from "planned" — RISC-V is now a first-class 5.0 target alongside Mach-O/PE. |
| **Bare-metal / freestanding** | Medium | No-libc, no-syscalls target for AGNOS kernel and other embedded consumers. Linker flag + crt0 shape, documented as a first-class target. |

---

## v5.x — Language Refinements (post-platform minors)

Collected from 4.x lessons and downstream port feedback. None of these block platform landing. All ship as 5.x minors after 5.0 cuts, prioritized by port-feedback tallies.

| Feature | Effort | Details |
|---------|--------|---------|
| **cc5 per-block scoping** | Medium | Proper lexical scope for `var` in nested blocks. Currently flat. Ships post-platform because the uplift groundwork lives in 5.0 already. |
| **Incremental compilation** | High | Per-module recompile. Depends on cc5's separated frontend. |
| **Generics / traits** | High | Collapse N near-identical functions to one. **Port-feedback votes: 1 (kavach).** Jumps priority on third cite. |
| **Pattern-match destructuring** | Medium | One-line field extraction where current code walks struct offsets manually. **Port-feedback votes: 1 (kavach).** |
| **Enum exhaustiveness checking** | Low | Match-must-cover-all-variants compile-time rule. **Port-feedback votes: 1 (kavach).** |
| **Closures capturing variables** | High | Currently a known gotcha (#8). Demand-gated. |

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
| Linux x86_64 | ELF | **Done** — primary, 353KB self-hosting |
| Linux aarch64 | ELF | **Done** — cross + native |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | Stub (v3.1) — **v5.0.0** |
| macOS aarch64 | Mach-O | Stub — **v5.0.0** |
| Windows x86_64 | PE/COFF | Stub (v3.1) — **v5.0.0** |
| RISC-V (rv64) | ELF | **v5.0.0** (promoted from "planned") |
| Bare-metal / freestanding | ELF (no-libc) | **v5.0.0** — AGNOS kernel target |

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
| 9 | Destructure requires fresh vars — `i, s = fn()` fails if `i` exists | `var ni, s = fn(); i = ni;` | By design |
| 10 | Multi-return max 2 values (rax:rdx pair) | 3+ returns need a heap record / struct | By design |
| 11 | `var x;` without init is invalid | Always `var x = 0;` | By design |

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
