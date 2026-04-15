# Cyrius Development Roadmap

> **v5.0.0.** 368KB self-hosting compiler, x86_64 + aarch64 cross.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc3 (368KB). Closure verified.
> **58 test suites**, 14 benchmarks, 5 fuzz harnesses. **59 stdlib modules** (includes 6 deps).
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

## v4.9.3 — Live TLS Bridge (shipped) ✅

Hardened `lib/dynlib.cyr` ELF loader (9 bounds checks, strtab_sz field,
struct 56→64 bytes). Wired `lib/tls.cyr` through `dynlib_open` →
libssl.so.3 with libcrypto preload, `SSL_ctrl` for SNI (macro
workaround), system-CA peer verification by default. 22-assertion test
suite (`tests/tcyr/tls.tcyr`).

---

## v4.10.0 — Cleanup & Consolidation (shipped) ✅

**No new features.** Full codebase audit so 5.0 starts clean.

- **Security fixes**: `fmt_sprintf` buffer overflow (added `bufsz` param),
  temp file TOCTOU race (`O_EXCL`), `_dynlib_find_path` stack buffer
  overflow (`var paths[4]` → `var paths[32]`).
- **Test coverage**: 4 new test suites (string 38, fmt 28, vec 21,
  hashmap 22). Total: 53 → 57 test files.
- **Stale comment sweep**: removed alpha version refs from u128, math,
  string, http, http_server, ws_server, fmt headers.
- **Tooling**: `cyrius init` now reads `VERSION` for `.cyrius-toolchain`
  instead of hardcoded `4.2.1`. `*.core` added to `.gitignore`.
- **Documentation freeze**: CLAUDE.md, roadmap, changelog all verified.

---

## v5.0.0 — cc5 Uplift + Tooling (major)

**Core compiler generation bump + aarch64 + tooling.** Everything else
in 5.x depends on the CFG foundation landing here.

| Feature | Effort | Details |
|---------|--------|---------|
| **cc3 → cc5 uplift** | High | Generation bump. Basic-block CFG is the foundation — enables LASE (load-after-store elimination), sound multi-register allocation, and the backend-table dispatch that multi-platform requires. Two-step bootstrap doctrine stays: cc5 compiles cc5 byte-identical. |
| **aarch64 native self-hosting** | Medium | Separate host-syscall constants from target-ISA emission via cc5 backend-table dispatch. Fix `#ref` preprocessor string/comment blindness. Produce a working `cc3-native-aarch64` that self-hosts on ARM. |
| **Libro PatraStore Heisenbug** | Medium | CFG-based diagnosis of the layout-dependent memory corruption. Gets own version bump within the 5.0 alpha cycle. Does not block 5.0 GA if it proves deeper than expected. |
| **cyrius.cyml manifest** | Medium | Replace `cyrius.toml` with `cyrius.cyml` (CYML parser shipped in 4.9.2). `cyrius update` auto-migrates existing `cyrius.toml` → `cyrius.cyml` so downstream projects upgrade in place. TOML parser stays as fallback for one minor cycle, then removed. |
| **Shell script maintenance** | Low | Updated `release-lib.sh` for sankoch dep. Shell→Cyrius rewrites deferred — scripts depend on `grep`/`sed`/`awk`/`find`/`timeout` which Cyrius can't replace yet. Revisit when Cyrius has regex or subprocess piping. |
| **CLI tool integrations** | Low | `cyrius init --cmtools[=starship]` installs prompt/editor configs. Starship: detect `cyrius.cyml`/`cyrius.toml`, show toolchain version. Future: shell completions, editor syntax highlighting, git hooks. Interactive prompt or `--cmtools=X` to bypass. |

---

## v5.0.1 — Security Hardening (patch)

**Stdlib security fixes from downstream audits (shravan 2026-04-15).**

| Issue | Severity | Details |
|-------|----------|---------|
| **alloc() heap pointer overflow** | P0 | `_heap_ptr + size` has no overflow check. Wraps to negative if sum exceeds INT64_MAX, corrupting allocator state. Fix: `if (_heap_ptr + size < _heap_ptr) { return 0; }` |
| **vec capacity doubling overflow** | P1 | `new_cap = cap * 2` overflows at cap >= 2^62. Subsequent `alloc(new_cap * 8)` allocates tiny buffer. Fix: cap max at 2^30 or check `cap > MAX_CAP / 2` before doubling. |
| **No allocation size cap** | P1 | `alloc(0x7FFFFFFFFFFFFFFF)` is accepted — attempts 8 EB allocation. All downstream codecs processing untrusted input are vulnerable to DoS. Fix: configurable max (default 256MB), return 0 on exceed. |

---

### Alpha → Beta → GA release phases

**Alpha** (current): Feature development. IR, CFG, LASE, edge analysis,
aarch64 native, cyrius.cyml, tooling. Self-host + check.sh at every commit.

**Beta** (feature-complete → release candidate): No new features. Focus on:
- **Test coverage**: every new IR opcode, BB construction edge case, LASE
  pattern, and cyrius.cyml migration path gets a dedicated .tcyr test.
- **Benchmarks**: compile-time benchmarks with CYRIUS_IR=1 vs off. Track
  node count, BB count, edge count, LASE hits across releases.
- **Fuzz harnesses**: .fcyr files that feed random/adversarial source to
  the compiler with IR enabled. Verify no crashes, no buffer overflows
  in the IR node/BB/edge tables.
- **Soak tests**: compile all downstream projects (agnostik, argonaut,
  kybernet, sigil, sankoch, etc.) with CYRIUS_IR=1 and verify
  byte-identical output. Any divergence is a bug.
- **Security re-scan**: IR heap region bounds, edge table overflow,
  CP tracking array bounds.

**GA**: Tag v5.0.0 only after beta passes all of the above with zero
failures across the full downstream portfolio.

---

## v5.1.0 — macOS x86_64

Mach-O emitter on cc5. Stubs scaffolded in v3.1. First non-Linux
platform. Proves the backend-table dispatch architecture.

---

## v5.2.0 — macOS aarch64

Mach-O emitter for Apple Silicon. Builds on 5.1.0 Mach-O work +
5.0.0 aarch64 backend. Native compilation on M-series Macs.

---

## v5.3.0 — Windows x86_64

PE/COFF emitter on cc5. Stub scaffolded in v3.1. Windows syscall
layer (ntdll). Brings Cyrius to the largest desktop platform.

---

## v5.4.0 — RISC-V rv64 (ELF)

rv64gc backend on cc5. First-class RISC-V target. ELF output
(same linker infrastructure as Linux x86_64/aarch64).

---

## v5.5.0 — Bare-metal / Freestanding

No-libc, no-syscalls target for AGNOS kernel. Linker flag + crt0
shape, documented as first-class. The target that makes Cyrius a
true systems language — kernel code compiled without any OS.

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
| Compression (dep) | sankoch |

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
