# Cyrius Development Roadmap

> **v4.8.2.** 353KB self-hosting compiler, x86_64 + aarch64.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc3 (353KB). Closure verified.
> **44 test suites**, 12 benchmarks, 5 fuzz harnesses. **43 stdlib modules** + 5 deps.
> New in 4.6.0: multi-file linker (`programs/cyrld.cyr`) + cross-unit DCE.
> New in 4.7.0: real dlopen-able `.so` from `shared;` (PT_DYNAMIC, PT_GNU_STACK, DT_INIT, PIC LEA).
> New in 4.8.0: `u128` stdlib (96 assertions). 4.8.1: `base64url`. 4.8.2: switch jump-table tuning.
> Caps: ident buffer 128KB (4.6.2), fn table 4096 (4.7.1).
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

## v4.8.x — Types, Codegen & Capacity (final 4.x minor series)

The 4.8 series breaks the single-feature "u128 everything" plan into
independent shippable minors. Each can be picked up / deferred without
blocking the rest.

### v4.8.0 — `u128` (shipped, with performance caveat) ✅
Pointer-based stdlib (`lib/u128.cyr`): `set` / `from_u64` / `copy` /
`lo` / `hi` / `eq` / `is_zero` / `add` / `sub` / `mul` / `divmod` /
`div` / `mod` / `shl` / `shr` / `and` / `or` / `xor` / `not` / `ugt` /
`uge` / `ult` / `ule` + `*eq` in-place variants. 96-assertion
regression test.

**Known gaps:** u128 as fn param / struct field / local — stack slot
is 8 bytes. Follow-up patches needed.

**Performance caveat (downstream evidence):** `u128_mod` via software
long-division is ~**40× slower** than binary double-and-add on
`is_prime`-style benchmarks (reported by abaco/hisab during port). For
hot-path modular arithmetic, consumers should prefer algorithm
substitution (Montgomery, binary exponentiation) over the generic
`u128_mod` until Cyrius codegen emits hardware 128-bit div-mod
(`divq`/`idivq` on x86_64, `udiv`+`mul`-sub on aarch64). Revisit as a
codegen task post-5.0 — see [v5.x — Language Refinements](#v5x--language-refinements-post-platform-minors).

### v4.8.1 — `base64url` + bote-reported fixes (shipped) ✅
- `base64url_encode` / `base64url_decode` in `lib/base64.cyr` (RFC
  4648 §5; JWT, OAuth 2.1, capability URLs).
- CI-discovered `method_dispatch` / `u128` test exit-code fix (needed
  explicit `syscall(60, assert_summary())`).
- 18 undocumented `lib/u128.cyr` helpers documented.

### v4.8.2 — Switch jump-table tuning (shipped) ✅
- Gap-to-default fix — values in `[min, max]` with no case now route
  to `default:` (previously fell through end-of-switch; invisible at
  the old 50% density threshold because dense cases have no gaps).
- Density threshold lowered 50% → 33%.
- Range cap raised 256 → 1024 — wider enum switches (40+ variants
  over a few hundred values) now hit O(1) dispatch.
- Dispatch benchmark (`benches/bench_switch.bcyr`): jump table ~7%
  faster on 8-way, ~11% on 16-way.

### v4.8.3 — Capacity visibility (planned)

| Feature | Effort | Details |
|---------|--------|---------|
| **`CYRIUS_STATS=1` compile-time usage report** | Low | Print fn-table (X/4096), identifier buffer (Y/131072), var table (Z/8192), fixup table, string data when set. Consumer projects (bote, kybernet, libro) hit silent capacity walls — bote reverted claims-propagation twice from ceiling pressure. Visibility lets refactors size themselves. |
| **`cyrius audit --capacity`** | Low | Standalone subcommand that compiles the unit and prints the same table. Wraps the env-flag path for scripted use. |
| **Warn at 85% utilization** | Low | Soft warning on build when any cap crosses 85% — catches "close to wall" before a real refactor trips it. |

### v4.8.4 — Register allocation (planned)

| Feature | Effort | Details |
|---------|--------|---------|
| **Per-function `#regalloc`** | High | Opt-in attribute. Use the CFG + lifetime analysis from 4.4.0 to assign hot locals to callee-saved regs (`rbx` / `r12..r15`). Benchmark target: 249 ns → sub-100 ns on the key dispatch path. Independent of cc5; ships on cc3. |

### v4.8.5 — Deferred formatting (planned)

| Feature | Effort | Details |
|---------|--------|---------|
| **`defmt`** | High | Compile-time format-string interning + runtime decode ring. Format strings become IDs at the call site; stdlib expands at drain time. Binary-size win for embedded / kernel / AGNOS targets. |

### v4.8.6 — Math stdlib pack (planned)

Closes the abaco-surfaced math gaps in one coherent landing. See
`docs/issues/stdlib-math-recommendations-from-abaco.md` for the
full triage and the per-item acceptance rationale.

| Feature | Effort | Details |
|---------|--------|---------|
| **`u128_mod` hardware fast-path** | Medium | Detect `divisor_hi == 0` and emit a single hardware `div` instead of the software long-division loop. No new API — every existing `u128_mul + u128_mod` caller picks up the ~40× win automatically. Unblocks abaco's Miller-Rabin perf parity with the Rust `u128` semantics. |
| **`u64_powmod`** (`lib/u128.cyr`) | Low | 12-line companion to the `mulmod` fast-path; pairs naturally in primality, RSA, and hashing. |
| **Inverse trig** (`lib/math.cyr`) | Medium | `f64_asin`, `f64_acos`, `f64_atan`, `f64_atan2`. Polynomial + range reduction, ~40 lines. Headline fix is `atan2` quadrant correctness — abaco's current identity-based stopgap gets Q2/Q3 wrong. |
| **Inverse hyperbolic** (`lib/math.cyr`) | Low | `f64_asinh`, `f64_acosh`, `f64_atanh`. Three 6-line fns, ships alongside the inverse trig alpha. |
| **f64 math constants** (`lib/math.cyr`) | Low | `F64_HALF`, `F64_PI`, `F64_PI_2`, `F64_PI_4`, `F64_TAU`, `F64_E`, `F64_LN2`, `F64_LN10`, `F64_FRAC_1_SQRT2`, `F64_SQRT2`. Bit-pattern form avoids init-time parse cost. |
| **Cstring case helpers** (`lib/string.cyr`) | Low | `str_lower_cstr` / `str_upper_cstr`. ASCII-only, matches existing conventions; de-duplicates abaco + vidya. |

**Validation target:** a Miller-Rabin microbench showing the
`mulmod` fast-path win, plus `atan2` quadrant tests covering all
four quadrants and the signed-zero edge cases.

### v4.8.7 — f64 parsing (planned)

| Feature | Effort | Details |
|---------|--------|---------|
| **`f64_parse(cstr)` + `f64_parse_prefix(cstr, out_end)`** | Medium | Ok/Err cstring-to-f64 parser. Handles optional sign, integer/fraction, `e[+-]?digits` scientific notation, `NaN` / `Inf` text. Closes the symmetric gap with existing `fmt_float`. Shipped as its own minor so the grammar can absorb feedback from additional math consumers that land between 4.8.6 and this cut. |

### v4.8.x — Cleanup ramp to 5.0

4.8.x is the cleanup ramp. New stdlib surface lands here when —
and only when — it unblocks a concrete downstream caller. No
speculative additions; everything traces back to a live consumer
request with a stopgap in their tree today.

### v4.9 — TBD (own focus + fix patches)

Reserved for its own minor theme (scope set when we cut) plus
regression/fix patches for 4.8.x features. Not a catch-all for
deferred work from 4.8.x.

Candidate themes being weighed (none committed):
- Multi-register `#regalloc` (`r12..r15` extension, inherits
  4.8.4's frame layout and safety-scan infrastructure).
- IR-based codegen pass to replace the current post-emit peephole
  (eliminates the NOP padding by allowing real code-size changes).

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
| **Hardware 128-bit div-mod codegen** | Medium | Emit `divq`/`idivq` (x86_64) and multi-instruction `udiv` sequence (aarch64) for `u128_divmod` / `u128_mod`. Closes the ~40× software-long-division gap reported by abaco/hisab. Consumers currently bypass `u128_mod` on hot paths. Unblocks generic bigint arithmetic without algorithm substitution. |
| **Math stdlib polish** | Low | `asin` / `acos` / `atan` currently stopgap formulas (usable, accuracy-limited at range extremes). `dBFS` deferred — log-scale unit needs special handling for ±∞ and zero-silence conventions. Both are marked in `lib/math.cyr` with `# STOPGAP:` comments so consumers know the ceiling. |

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
