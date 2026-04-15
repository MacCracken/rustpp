# Cyrius Development Roadmap

> **v5.0.0.** cc5 compiler (408KB), x86_64 + aarch64 cross. IR + CFG.
> Bootstrap: seed (29KB) → cyrc (12KB) → bridge → cc5 (408KB). Closure verified.
> **59 test suites**, 14 benchmarks, 5 fuzz harnesses. **59 stdlib modules** (includes 6 deps).
> Caps: ident buffer 128KB (4.6.2), fn table 4096 (4.7.1).
> 10+ downstream projects shipping.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

| Bug | Impact | Status |
|-----|--------|--------|
| Layout-dependent memory corruption | Libro PatraStore tests | Localized with `CYRIUS_SYMS`. Classic memory corruption signature — each `println` shifts the crash site. Workaround: isolated test binary. CFG now available for diagnosis (5.0.0 IR). |
| `#ref` preprocessor matches inside strings/comments | `PP_REF_PASS` scans raw bytes without skipping string literals or comments | x86 self-hosting unaffected (pass ordering protects it). Exposed when feeding pre-expanded source to cross-compiler. |
| aarch64 native binary non-functional | `cc5-native-aarch64` hangs on any input on ARM hardware | Host syscall numbers are x86 (correct for cross-compiler, wrong for native). Needs SYS_OPEN→SYS_OPENAT migration + heap map sync. |

---

## Shipped

<details>
<summary>Click to expand shipped items (v3.7.0 → v4.10.3)</summary>

### v3.7.x–v3.10.x — Language & Tooling
- `#derive(accessors)`, multi-return, switch, defer (all exit paths)
- `+=`/`-=`/`*=` compound ops, negative literals, undefined fn diagnostic
- `cyrius deps`, auto-include, namespaced deps, `.cyrius-toolchain`
- `cyrius init`, CI/release workflows, aarch64 cross-compiler

### v4.0.0–v4.8.5 — Compiler & Stdlib
- File:line errors, DCE, short-circuit `&&`/`||`, struct init syntax
- LSP, HTTP server, linker, PIC/shared objects
- u128, base64, math pack, `#regalloc` (multi-register)

### v4.9.x — Stdlib & TLS
- f64_parse, word-at-a-time strlen, CYML parser
- `lib/dynlib.cyr` hardening (9 bounds checks), live TLS bridge (libssl.so.3)

### v4.10.x — Cleanup, Deps, Linalg
- Security: fmt_sprintf bounds, temp file O_EXCL, dynlib stack overflow
- 4 new test suites (string, fmt, vec, hashmap)
- sankoch 1.0.0 dep (compression), linalg (LU/QR/Cholesky/SVD/eigen)
- Math utilities from abaco (lerp, hypot, sign, gcd, lcm, fibonacci, binomial)
- CI `set -e` fix, `cyrius update` toolchain pin

</details>

---

## v5.0.0 — cc5 Generation Bump (shipped) ✅

**cc3→cc5. IR, CFG, tooling overhaul.**

- **cc5 IR** (`src/common/ir.cyr`, 812 lines) — 40 opcodes, BB construction,
  CFG edge builder (patch-offset matching), LASE analysis, dead block
  detection. Self-compile: 119K nodes, 8.7K BBs, 11K edges, 675 LASE.
  43 instrumented emit/jump functions. Analysis-only (transparent).
- **cyrius.cyml manifest** — replaces cyrius.toml. `cyrius update`
  auto-migrates. `cyrius init` generates cyrius.cyml by default.
- **`cyrius version`** — toolchain version. `--project` for project version.
- **CLI tool integrations** — `--cmtools=starship`.
- **cc3→cc5 rename** — binary, scripts, docs all updated.
- **Deps**: patra 1.0.0, sankoch 1.2.0.

---

## v5.0.1 — Security Hardening (patch)

| Issue | Severity | Details |
|-------|----------|---------|
| **alloc() heap pointer overflow** | P0 | `_heap_ptr + size` wraps past INT64_MAX. Fix: overflow check before advance. |
| **vec capacity doubling overflow** | P1 | `cap * 2` overflows at cap >= 2^62. Fix: cap max check. |
| **No allocation size cap** | P1 | `alloc(0x7FFFFFFFFFFFFFFF)` accepted. Fix: configurable max (default 256MB). |

---

## v5.x — Platform Targets

Each platform is one minor release. cc5 backend-table dispatch
enables adding new targets without touching the frontend.

| Release | Platform | Format | Status |
|---------|----------|--------|--------|
| **v5.1.0** | macOS x86_64 | Mach-O | Stubs scaffolded (v3.1) |
| **v5.2.0** | macOS aarch64 | Mach-O | Apple Silicon native |
| **v5.3.0** | Windows x86_64 | PE/COFF | Stubs scaffolded (v3.1) |
| **v5.4.0** | RISC-V rv64 | ELF | First-class RISC-V target |
| **v5.5.0** | Bare-metal | ELF (no-libc) | AGNOS kernel target |

---

## v5.x — IR-Driven Optimization (when complete emit coverage)

LASE and DBE analysis is proven but codebuf patching is unsafe until
all emit paths go through IR. The path:

1. Instrument remaining ~50 emit calls (direct EB/E2/E3 from parse.cyr)
2. LASE codebuf patching becomes safe → redundant load elimination
3. DBE becomes safe → dead block NOP-fill
4. Sound multi-register allocation on IR (replaces peephole #regalloc)
5. Constant folding, strength reduction

---

## v5.x — Language Refinements

| Feature | Effort | Votes |
|---------|--------|-------|
| cc5 per-block scoping | Medium | — |
| Incremental compilation | High | — |
| Stack slices | High | — |
| Generics / traits | High | 1 (kavach) |
| Pattern-match destructuring | Medium | 1 (kavach) |
| Enum exhaustiveness checking | Low | 1 (kavach) |
| Closures capturing variables | High | gotcha #8 |
| Hardware 128-bit div-mod | Medium | — |

---

## Stdlib (59 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, cyml, csv, base64, regex, math, matrix, linalg, bigint, u128 |
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

## Platform Status

| Platform | Format | Status |
|----------|--------|--------|
| Linux x86_64 | ELF | **Done** — primary, cc5 408KB self-hosting |
| Linux aarch64 | ELF | **Partial** — cross-compiler works, native needs host syscall fix |
| cyrius-x bytecode | .cyx | **Done** (v2.5) |
| macOS x86_64 | Mach-O | Stub — **v5.1.0** |
| macOS aarch64 | Mach-O | Stub — **v5.2.0** |
| Windows x86_64 | PE/COFF | Stub — **v5.3.0** |
| RISC-V (rv64) | ELF | **v5.4.0** |
| Bare-metal | ELF (no-libc) | **v5.5.0** |

---

## Ecosystem

| Status | Repos |
|--------|-------|
| **Done** | agnostik, agnosys, argonaut, kybernet, nous, ark |
| **Done** | sakshi, majra, bsp, cyrius-doom, mabda, hadara |
| **Done** | sigil, patra, libro, shravan, tarang, yukti |
| **Done** | avatara, ai-hwaccel, hoosh, itihas, sankoch |
| **In progress** | bhava, hisab |
| **Blocked** | vidya MCP (needs bote) |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Two-step bootstrap for any heap offset change
- Test after EVERY change, not after the feature is done
- **Never use raw `cat | cc5` for projects** — always `cyrius build`
- **v5.0.0 recommended minimum** — cc5 IR, cyrius.cyml, patra 1.0.0, sankoch 1.2.0
