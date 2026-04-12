# Cyrius Development Roadmap

> **v3.5.1.** 250KB self-hosting compiler, x86_64 + aarch64.
> 32 test suites (442 assertions), 4 fuzz harnesses, heap audit clean.
> 40 stdlib modules + 5 deps (sakshi, patra, sigil, yukti, mabda — GPU now active).
> 256KB input_buf, 512KB codebuf, 64KB tok_names. Dependencies via `cyrius deps`.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## Active Bugs

None. All known bugs resolved (see CHANGELOG #14-#36).

---

## v3.5.0 — Expression Power

Low-risk codegen improvements. No new syntax complexity,
no heap changes, no bootstrap risk. Unblocks cleaner ports.

| # | Feature | Effort | Details |
|---|---------|--------|---------|
| 1 | **Expression-position comparisons** | Low | `==`/`!=`/`<`/`>` return 0/1 as values anywhere, not just in `if()`. Emit `cmp`+`sete`+`movzx`. Eliminates expand-to-if pattern every port hits. |
| 2 | **`#assert` compile-time check** | Low | `#assert EXPR, "msg"` — evaluate constant expression at parse time, abort on failure. Catches struct layout drift, enum value mismatches. |
| 3 | **`sizeof(StructName)`** | Low | Compile-time `field_count * 8` from struct definition. Eliminates magic numbers in `alloc()` calls. |
| 4 | **Syscall arity warnings** | Low | Lookup table of syscall number → expected arg count. Warning on mismatch. The table is fixed — free information. |

## v3.6.0 — String Unification

Address the #1 pain point across all ports: Str vs cstr boundary.

| # | Feature | Effort | Details |
|---|---------|--------|---------|
| 5 | **Str/cstr auto-coercion** | Medium | When function parameter type is known, auto-wrap string literals as `str_from()` or auto-extract via `str_cstr()`. Eliminates `str_contains` vs `str_contains_cstr` split. |
| 6 | **Compile-time string interning** | Medium | Deduplicate string literals at compile time, assign stable addresses. `@"literal"` syntax for pointer-identity comparison (1 cycle vs memcmp). 10x faster classification chains. Synergy with deferred formatting (#8). |
| 7 | **`lib/cffi.cyr`** — C struct layout | Medium | C struct layout helpers for foreign struct interop. Compute field offsets with C alignment/padding rules. Needed for tarang codec ports. |

## v3.7.0 — Struct Evolution

Make structs do more work at compile time. Zero runtime cost.

| # | Feature | Effort | Details |
|---|---------|--------|---------|
| 8 | **`#derive(accessors)`** | Medium | Auto-generate `Name_field(p)` and `Name_set_field(p, v)` for each struct field. Same codegen pattern as `#derive(Serialize)`. Saves ~30 lines per struct. |
| 9 | **Native multi-return** | Medium | `return (a, b)` → rax:rdx. `var x, y = fn()` → destructure. Eliminates alloc(16) pair structs. ret2/rethi exist internally — expose as first-class syntax. |
| 10 | **Deferred formatting** (defmt) | High | String interning + decode ring. Eliminates runtime fmt overhead for logging/tracing. Builds on string interning from v3.6.0. |

## v3.8.0 — Safety Without Cost

Compile-time guarantees that produce identical machine code.

| # | Feature | Effort | Details |
|---|---------|--------|---------|
| 11 | **Defer on all exit paths** | Medium | Emit defer cleanup before every `return`, not just function end. Eliminates resource leak bugs. `defer close(fd)` covers all error returns. |
| 12 | **Register alloc (per-function)** | Medium | Opt-in `#regalloc` directive. Avoids the v3.3.12 regression (global push/pop r12 broke 7+ arg offsets). Per-function analysis only. |
| 13 | **u128** | High | 128-bit integers via register pairs. Unblocks native bigint without 4-limb emulation. |

## v4.0.0 — Platform & Scale

Major release. Multi-file compilation, new platforms, scale limits removed.

| # | Feature | Effort | Details |
|---|---------|--------|---------|
| 14 | **Multi-file linker** (Phase 2) | High | .o emission done (v2.6.4). Need: read .o, resolve symbols, patch relocations, emit executable. Write in Cyrius. |
| 15 | **PIC codegen** (Phase 2) | High | `.so` output (ET_DYN), GOT/PLT emission, `shared;` directive. `object;` init code needs `_cyrius_init`. Partial in v3.4.12. |
| 16 | **macOS targets** | High | Mach-O emitter (x86_64 + aarch64). Stubs scaffolded in v3.1. |
| 17 | **Windows target** | High | PE/COFF emitter. Stub scaffolded in v3.1. |
| 18 | **LSP** | High | Language Server Protocol for IDE integration. |
| 19 | **Stack slices** | High | `var buf[512]: slice` — stack buffer with companion length. Eliminates `(buf, len)` parameter pairs. New type category. |

---

## Stdlib

### Current (40 modules + 5 deps)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, csv, base64, regex, math, matrix, bigint |
| Network | net, http, ws, tls |
| Filesystem | fs |
| Tracing (dep) | sakshi, sakshi_full |
| Database (dep) | patra |
| Security (dep) | sigil |
| Hardware (dep) | yukti |
| GPU (dep) | mabda (v2.1.2, activated v3.4.19 — backend is a transitional wgpu-native C shim, public API is the stability contract, native backend is future work) |
| Time | chrono |
| Logging | log |
| Knowledge | vidya |
| Interop | mmap, dynlib |

### Pending inclusion

None currently. Mabda (the last pending dep) was activated in v3.4.19.

### Planned

| Module | Depends on | Details |
|--------|-----------|---------|
| `cffi.cyr` | dynlib | C struct layout helpers (v3.6.0) |
| `bridge.cyr` | process | Rust↔Cyrius pipe protocol. Temporary — remove after bote port. |

## FFI & Interop

| # | Module | Status |
|---|--------|--------|
| 1 | ~~`fncall3`–`fncall6`~~ | **Done (v3.4.3)** |
| 2 | ~~`dynlib.cyr`~~ — ELF .so loader | **Done (v3.4.11)** |
| 3 | `cffi.cyr` — C struct layout | v3.6.0 |
| 4 | ~~`mmap.cyr`~~ | **Done (v3.4.3)** |
| 5 | `bridge.cyr` — pipe protocol | When needed |

---

## Video Codec Projects (post-tarang core)

Pure Cyrius implementations. Each replaces a C FFI dependency.

| # | Project | Replaces | Status |
|---|---------|----------|--------|
| 1 | **drishti-av1** | dav1d | Not started |
| 2 | **drishti-h264** | openh264 | Not started |
| 3 | **drishti-h265** | libde265 | Not started |
| 4 | **drishti-vpx** | libvpx | Not started |
| 5 | **drishti-rav1e** | rav1e | Not started |

**Shared primitives** (built as needed):
- `bitreader.cyr` — MSB/LSB bit extraction
- `entropy.cyr` — arithmetic/range coding
- `cabac.cyr` — context-adaptive binary arithmetic coding
- `boolcoder.cyr` — boolean coder (VP8/VP9)

---

## Platform Targets

| Platform | Format | Status |
|----------|--------|--------|
| Linux x86_64 | ELF | **Done** — primary, 250KB self-hosting |
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
| **Done** | sakshi, majra, bsp, cyrius-doom |
| **Done** | sigil, patra, libro, shravan, tarang |
| **Done** | yukti v1.2.0 (device abstraction, 470 tests) |
| **In progress** | bhava (29K), hisab (31K) |
| **Blocked** | ai-hwaccel (needs majra+libro), vidya MCP (needs bote) |
| **Remaining** | ~99 repos (~907K lines) |

---

## Tooling

All core tooling complete:
`build`, `test`, `bench`, `fuzz`, `soak`, `watch`, `deps`,
`audit`, `fmt`, `lint`, `doc`, `init`, `port`, `cyriusly` (version manager — "Language Yare").

| Planned | Status |
|---------|--------|
| `cyrius lsp` | v4.0.0 — Language Server Protocol |

---

## Open Limits

| Limit | Current | Notes |
|-------|---------|-------|
| Functions | 2048 | Expanded from 1024 in v3.2.2 |
| Variables | 8192 | |
| Globals (initialized) | 1024 | Use enums for constants |
| Locals per function | 256 | |
| Fixup entries | 8192 | |
| Struct fields | 32 | |
| Input buffer | 256KB | Expanded from 128KB in v3.4.19 — hard error on overflow, not silent truncation |
| Code buffer | 512KB | Expanded in v3.4.0 |
| Output buffer | 512KB | |
| String data | 32KB | |
| Identifier names | 64KB | Expanded in v3.3.17 |
| Tokens | 131072 | |

---

## Known Gotchas

| # | Behavior | Workaround |
|---|----------|------------|
| 1 | `var buf[N]` is N **bytes** | `var buf[640]` for 80 i64 values |
| 2 | Global var loop bound re-evaluates | Snapshot to local |
| 3 | Inline asm `[rbp-N]` clobbers params | Use globals or dummy locals |
| 4 | Large `var buf[N]` exhausts output buffer | Use `alloc(N)` for >4KB |
| 5 | Mixed `&&`/`||` requires explicit parens | Write `a && (b \|\| c)` — no precedence-based disambiguation |
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
- 108 repos / ~1M lines is the real measure of success
- **v3.4.0 minimum** — all repos should pin >= 3.4.0
