# Cyrius Development Roadmap

> **v4.9.2.** 368KB self-hosting compiler, x86_64 + aarch64 cross.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc3 (368KB). Closure verified.
> **52 test suites**, 14 benchmarks, 5 fuzz harnesses. **57 stdlib modules** (includes 5 deps).
> Caps: ident buffer 128KB (4.6.2), fn table 4096 (4.7.1).
> 10+ downstream projects shipping.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| Layout-dependent memory corruption | Libro PatraStore tests | v4.3.1: localized with `CYRIUS_SYMS`. Crash is `memeq` called with NUL data ptr from `str_eq(entry_hash(a), entry_hash(b))` in large libro binary. Each `println` shifts the site — classic memory corruption signature. Root cause needs CFG to diagnose. Workaround: isolated test binary. Fix deferred to 5.0 (gets own version bump within alpha cycle). |
| `#ref` preprocessor matches inside strings/comments | `PP_REF_PASS` scans every byte position for `#ref ` without skipping string literals or comments. Source containing `"#ref "` silently corrupts the preprocessor state, producing a 136-byte stub. | x86 self-hosting unaffected (pass ordering protects it). Exposed when feeding pre-expanded source to cross-compiler. Deferred to 5.0 (cc5 preprocessor redesign). |
| aarch64 native binary non-functional | `cc3-native-aarch64` hangs on any input on ARM hardware | `main_aarch64.cyr` uses x86 syscall numbers for the compiler's own I/O — correct for the cross-compiler but wrong for native. Deferred to 5.0 (aarch64 native self-hosting item). `_read_env` added to aarch64 fixup.cyr in 4.8.5-1. |

---

## Shipped

<details>
<summary>Click to expand shipped items (v3.7.0 → v4.8.5)</summary>

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

### v4.2.x–v4.4.x — Compiler & Stdlib (shipped out of sequence)
Items originally roadmapped for these versions shipped across multiple releases:
- **Dead function warning** (aggregate count) — fixup.cyr, `note: N unreachable fns`
- **Single-CU DCE** — `CYRIUS_DCE=1` NOP-fill for unreachable functions
- **Short-circuit `&&`/`||`** — full `je`/`jne` codegen in parse.cyr
- **`rep movsb`/`rep stosb`** — hardware memcpy/memset in lib/string.cyr
- **Bump allocator soft reset** — `alloc_reset()` in lib/alloc.cyr
- **Struct initializer syntax** — `Name { field: expr }` (named + positional) in parse.cyr
- **LSP** — programs/cyrius-lsp.cyr (didOpen, didSave, didChange, diagnostics)

### v4.5.0 — HTTP Server
- `lib/http_server.cyr`: parse/build request+response, Content-Length read, URL-decode, chunked/SSE, `http_server_run` accept-loop

### v4.6.0 — Multi-File Linker & Cross-Unit DCE
- `programs/cyrld.cyr` linker: read .o, resolve symbols, patch relocations, emit executable
- Cross-unit DCE across object files

### v4.7.0 — PIC Codegen & Shared Objects
- `.so` output (ET_DYN), GOT/PLT, PT_DYNAMIC, PT_GNU_STACK, DT_INIT, PIC LEA

### v4.8.0–v4.8.5 — Types, Codegen, Capacity & Math
- **4.8.0**: u128 stdlib (96 assertions)
- **4.8.1**: base64url (RFC 4648 §5)
- **4.8.2**: Switch jump-table tuning (density 50%→33%, range 256→1024)
- **4.8.3**: `CYRIUS_STATS=1` capacity report, `cyrius audit --capacity`, 85% utilization warning
- **4.8.4**: `#regalloc` (single rbx), PP_IFDEF_PASS 256KB scan-blindness fix
- **4.8.5**: Math stdlib pack (u128_divmod fast-path, u64_mulmod/powmod, f64 constants, inverse trig/hyperbolic, ASCII case), CVE-2019-9741 CRLF hardening in http.cyr, TLS interface scaffold

</details>

---

## v4.9.0 — Stdlib Completions + Diagnostics (shipped) ✅

| Feature | Details |
|---------|---------|
| **`f64_parse(cstr)` + `f64_parse_ok`** | String-to-f64 parser. Optional sign, integer/fraction, `e[+-]?digits` scientific notation, `NaN`/`Inf`/`-Inf`. `f64_parse_ok` writes result via pointer and returns 1/0. Closes the symmetric gap with `fmt_float`. |
| **Per-function dead fn names** | Dead function reporting now lists each unreachable function by name (`dead: FUNCNAME`), not just the aggregate count. |
| **Word-at-a-time strlen** | `lib/string.cyr` strlen upgraded from byte-at-a-time to 8-byte aligned word reads with magic-constant zero detection. Portable (no SIMD). |
| **Internal doc audit** | Roadmap restructured (stale 4.1.x–4.7.0 archived, stats corrected). CLAUDE.md updated. CHANGELOG cleaned. `_read_env` added to aarch64 fixup.cyr. `.gitignore` updated for `cc3-native-aarch64`. |

---

## v4.9.1 — Multi-Register `#regalloc` (shipped) ✅

Extended `#regalloc` from single-register (rbx) to five callee-saved
registers (rbx, r12–r15). Peephole patcher picks up to 5 hottest
non-param locals per function with independent safety scans.
Displacement generalized to N*8, prologue/epilogue saves/restores
all allocated registers.

---

## v4.9.2 — CYML + Tooling (shipped) ✅

- **`lib/cyml.cyr`** — CYML parser (TOML above `---`, markdown below).
  Zero-copy, single-entry and multi-entry (`[[entries]]`), 22-assertion
  test suite. Replaces triple-quoted TOML strings for structured
  content with prose.
- **`cyrius init --agent[=preset]`** — opt-in CLAUDE.md generation.
  No agent file by default. Presets: generic, agnos, claude.

---

## v4.9.3 — Live TLS Bridge

Single focused deliverable. Isolates security-sensitive work.

| Feature | Effort | Details |
|---------|--------|---------|
| **`lib/dynlib.cyr` hardening** | Medium | ELF loader segfaults on `libssl.so.3` parse. Harden the section/symbol table walk. |
| **Live libssl bridge** | Medium | Wire `lib/tls.cyr`'s 4.8.5 interface through `dynlib_open` → libssl.so.3 → SSL_CTX_new / SSL_connect / SSL_read / SSL_write. SNI + system-CA peer verification on by default. `tls_available()` returns 1 when libssl found. bote is the concrete consumer. |

---

## v4.10.0 — Cleanup & Consolidation (last 4.x)

**No new features.** Full codebase audit so 5.0 starts clean.

| Item | Details |
|------|---------|
| **Heap map consolidation** | Audit every allocation in src/main.cyr, reclaim dead regions, document the map for cc5 migration. cc3 heap is near 14.8MB capacity — map every byte for the generation bump. |
| **Code audit + refactor** | Dead code removal, naming consistency, comment hygiene across parse.cyr, lex.cyr, emit.cyr, fixup.cyr. Remove stale TODO/FIXME markers. |
| **Test coverage gaps** | Every stdlib module without a dedicated test file gets one. Benchmark baselines captured for 5.0 regression testing. |
| **Documentation freeze** | cyrius-guide.md, CLAUDE.md, known-limits, gotchas table — all accurate as of this release. Version refs, feature claims, and capacity numbers verified. |
| **Security re-scan** | Grep for `sys_system` / `READFILE` with unvalidated paths, unchecked writes near region boundaries, stale fixed-size caps. |
| **P(-1) scaffold hardening** | Full checklist: `cyrius fmt --check`, `cyrius lint`, `cyrius vet`, all .tcyr pass, heap audit clean, self-hosting verified, benchmark baseline. |

---

## v5.0.0 — Multi-Platform (major)

**Scope: platforms only.** This is the release where Cyrius leaves single-platform ELF and lands on every OS and ISA that matters. Language refinements ship in 5.x minors after the cut. A narrow 5.0 scope keeps the release auditable and the platform story clear.

| Feature | Effort | Details |
|---------|--------|---------|
| **cc3 → cc5 uplift** | High | Generation bump. Basic-block CFG is the foundation — enables LASE (load-after-store elimination), sound multi-register allocation, and the backend-table dispatch that multi-platform requires. Two-step bootstrap doctrine stays: cc5 compiles cc5 byte-identical. |
| **aarch64 native self-hosting** | Medium | Separate host-syscall constants from target-ISA emission via cc5 backend-table dispatch. Fix `#ref` preprocessor string/comment blindness. Produce a working `cc3-native-aarch64` that self-hosts on ARM. |
| **Libro PatraStore Heisenbug** | Medium | CFG-based diagnosis of the layout-dependent memory corruption. Gets own version bump within the 5.0 alpha cycle. Does not block 5.0 GA if it proves deeper than expected. |
| **macOS x86_64** | High | Mach-O emitter on cc5. Stubs scaffolded in v3.1. |
| **macOS aarch64** | High | Mach-O emitter on cc5. Apple Silicon native. |
| **Windows x86_64** | High | PE/COFF emitter on cc5. Stub scaffolded in v3.1. |
| **RISC-V (ELF)** | High | rv64 backend on cc5. First-class 5.0 target alongside Mach-O/PE. |
| **Bare-metal / freestanding** | Medium | No-libc, no-syscalls target for AGNOS kernel. Linker flag + crt0 shape, documented as first-class. |

---

## v5.x — Language Refinements (post-platform minors)

Collected from 4.x lessons and downstream port feedback. None block platform landing. Prioritized by port-feedback tallies.

| Feature | Effort | Details |
|---------|--------|---------|
| **cc5 per-block scoping** | Medium | Proper lexical scope for `var` in nested blocks. Currently flat. |
| **Incremental compilation** | High | Per-module recompile. Depends on cc5's separated frontend. |
| **Stack slices** | High | `var buf[512]: slice` — stack buffer with companion length. |
| **defmt** | High | Compile-time format-string interning + runtime decode ring. Binary-size win for embedded/kernel targets. No concrete consumer blocker yet — revisit when demanded. |
| **Generics / traits** | High | Collapse N near-identical functions to one. **Port-feedback votes: 1 (kavach).** |
| **Pattern-match destructuring** | Medium | One-line field extraction. **Port-feedback votes: 1 (kavach).** |
| **Enum exhaustiveness checking** | Low | Match-must-cover-all-variants compile-time rule. **Port-feedback votes: 1 (kavach).** |
| **Closures capturing variables** | High | Currently gotcha #8. Demand-gated. |
| **Hardware 128-bit div-mod codegen** | Medium | Emit `divq`/`idivq` (x86_64) and `udiv` sequence (aarch64). Closes ~40× software gap. |
| **Math stdlib polish** | Low | `asin`/`acos`/`atan` range-extreme accuracy. `dBFS` log-scale handling. |
| **SIMD strlen** | Low | SSE4.2 `pcmpistri` path. Word-at-a-time in 4.9.0 closes the practical gap; SIMD is a nice-to-have. |

---

## Stdlib (57 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, cyml, csv, base64, regex, math, matrix, bigint, u128 |
| Network | net, http, http_server, ws, tls |
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
| Linux x86_64 | ELF | **Done** — primary, 364KB self-hosting |
| Linux aarch64 | ELF | **Partial** — cross-compiler works, native hangs (5.0) |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | Stub (v3.1) — **v5.0.0** |
| macOS aarch64 | Mach-O | Stub — **v5.0.0** |
| Windows x86_64 | PE/COFF | Stub (v3.1) — **v5.0.0** |
| RISC-V (rv64) | ELF | **v5.0.0** |
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
| Functions | 4096 | Raised from 2048 in v4.7.1 |
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
| Identifier names | 128KB | Raised from 64KB in v4.6.2 |
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
- **v4.8.4 recommended minimum** — PP_IFDEF_PASS 256 KB scan-blindness fix is critical for any consumer with ≥ 512 KB expanded compile units. v4.8.5 adds math stdlib + CRLF hardening in `lib/http.cyr`.
