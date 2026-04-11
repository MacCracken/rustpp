# Cyrius Development Roadmap

> **v3.4.6.** 243KB self-hosting compiler, x86_64 + aarch64. Multi-break (linked-list).
> 31 test suites (375 assertions), 4 fuzz harnesses, heap audit clean. 34 stdlib modules + 4 deps.
> 10+ downstream repos. 512KB codebuf, 64KB tok_names. Dependencies via `cyrius deps`.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).
For bug history, see CHANGELOG.md (bugs #14-#31, all resolved).

---

## Bugs

| # | Bug | Severity | Status |
|---|-----|----------|--------|
| 35 | **cc3 SIGSEGV at ~14.5K expanded lines** | **P0 — 3.4.4** | Open. cc3 segfaults (exit 139, 0-byte output) when compiling sigil (4,259) + patra (3,013) + libro (1,781 user + ~5,500 modules) = ~14,500 expanded lines. Minimal repro (85 lines user code, ~13K with libs) compiles fine on 3.4.2 — full test suite pushes it over. Likely fixup table or tok_names capacity. Repro: `libro/tests/fixup_limit_repro.cyr` compiles; `libro/src/main.cyr` with patra+sigil uncommented crashes. Blocks libro PatraStore (SQL-backed audit persistence). Bug #32 fix (3.3.17) raised limit from ~12K to ~13K; needs another bump to ~20K+ for multi-lib projects. |
| 34 | **`#derive(Serialize)` duplicate variable** | **P0 — 3.4.4** | Open. Single `#derive(Serialize)` emits `error: duplicate variable`. Regression between 3.3.13 and 3.3.17. Blocks argonaut, agnostik, any project using derive serialization. All 3.3.8–3.3.13 work; 3.3.17+ and all 3.4.x broken. Root cause: derive codegen likely reuses an internal variable name that collides with the new multi-break linked-list or tok_names changes. |
| 32 | ~~Parser overflow at ~12K expanded lines~~ | Blocking | **Resolved 3.3.17** | tok_names expanded 32KB→64KB (moved str_data out). LEXHEX buffer bug also fixed. |
| 33 | ~~LEXHEX wrong buffer~~ | Medium | **Resolved 3.3.17** | Hex parser read `S+p` instead of `S+0x44A000+p`. |

## Compiler

| # | Feature | Effort | Status |
|---|---------|--------|--------|
| 1 | **Multi-file linker** (Phase 2) | High | .o emission done (v2.6.4). Need: read .o files, resolve symbols, patch relocations, emit executable. Write in Cyrius. |
| 2 | **Deferred formatting** (defmt) | High | Not started. String interning + decode. Eliminates runtime fmt overhead for logging/tracing. |
| 3 | **u128** | High | Research. 128-bit integers via register pairs. Unblocks native bigint without 4-limb emulation. |
| 4 | **Small function inlining** | Medium | **Done (v3.3.5)**. 2-param, 16-token body limit. Param names packed in fn_inline slot. |
| 5 | **Register alloc for loop vars** | Medium | **Reverted (v3.3.12)**. push/pop r12 in every prologue caused 2x perf regression + broke 7+ arg stack offsets. Needs per-function opt-in. |
| 6 | **Variadic functions** | Medium | Deferred. Vec-based pattern sufficient for all current ports. |
| 7 | **`defer` statement** | Medium | **Done (v3.2.0)**. LIFO execution, return value preserved, max 8 per function. |
| 8 | **Dead store elimination** | Low | **Done (v3.3.2)**. Post-emit DSE pass, NOPs consecutive stores to same `[rbp-N]`. |
| 9 | **Expanded constant folding** | Low | **Done (v3.3.1)**. Removed 16-bit limit, added `x-0`/`x*1`/`x*0` identities. |
| 10 | **`cc3 --version`** | Low | **Done (v3.3.0)**. Reads /proc/self/cmdline for argv[1]. |
| 11 | **PIC codegen** | High | Not started. Position-independent code for .so output. RIP-relative data refs, GOT/PLT emission. Enables Cyrius .so loadable by external consumers. |

## Standard Library — FFI & Interop (tarang-driven)

Needed for tarang media framework port and downstream ecosystem interop.
Pure Cyrius implementations — no libc, no dlopen.

| # | Module | Effort | Status | Details |
|---|--------|--------|--------|---------|
| 1 | **`fncall3`–`fncall6` in fnptr.cyr** | Low | Not started | Extend indirect calls to full System V ABI (rdi, rsi, rdx, rcx, r8, r9). Video codec APIs need 3-6 param indirect calls. Same inline asm pattern as fncall0/1/2. |
| 2 | **`lib/dynlib.cyr`** — ELF .so loader | High | Not started | Pure Cyrius dynamic library loader. `mmap` syscall to map .so, parse ELF headers (reuse compiler's ELF knowledge), resolve `.dynsym`+`.dynstr`, process RELA relocations (R_X86_64_64, GLOB_DAT, JUMP_SLOT). API: `dynlib_open(path) → handle`, `dynlib_sym(handle, name) → fnptr`, `dynlib_close(handle)`. No libc. |
| 3 | **`lib/cffi.cyr`** — C struct layout | Medium | Not started | C struct layout helpers for foreign struct interop. Compute field offsets with C alignment/padding rules. `cffi_struct(field_sizes) → layout`, `cffi_read_field(ptr, offset, size)`, `cffi_write_field(ptr, offset, size, val)`. Needed for vpx_codec_ctx_t, VAImage, etc. |
| 4 | **`lib/mmap.cyr`** — memory-mapped I/O | Low | Not started | Direct syscall wrappers: `mmap(addr, len, prot, flags, fd, offset)`, `munmap(addr, len)`. Needed by dynlib.cyr, zero-copy file access, shared memory with GPU drivers. SYS_MMAP=9, SYS_MUNMAP=11. |
| 5 | **`lib/bridge.cyr`** — process bridge protocol | Medium | Not started | Structured message passing over stdin/stdout pipes for Rust↔Cyrius interop during migration. Binary protocol: `[len:u32][tag:u8][payload]`. **Temporary** — remove once bote converts to Cyrius. Primary use: tarang MCP via Rust bote subprocess. |

## Video Codec Projects (pure Cyrius, post-tarang core)

Individual repos following the shravan model — focused, tested, benchmarked, then included by tarang.
Each replaces a C FFI dependency with a pure Cyrius implementation.

| # | Project | Replaces | Complexity | Status |
|---|---------|----------|------------|--------|
| 1 | **drishti-av1** | dav1d (AV1 decode) | Very high | Not started. Bitstream parser + transforms + motion comp + loop filters. |
| 2 | **drishti-h264** | openh264 (H.264 decode/encode) | Very high | Not started. NAL parsing + CABAC + transforms + deblocking. |
| 3 | **drishti-h265** | libde265 (H.265 decode) | Very high | Not started. Similar to H.264 with larger transform sizes. |
| 4 | **drishti-vpx** | libvpx (VP8/VP9 decode/encode) | High | Not started. Bitstream + boolean coder + transforms + loop filter. |
| 5 | **drishti-rav1e** | rav1e (AV1 encode) | High | Not started. Already pure Rust, port pattern like shravan. |

**Shared primitives** (built as needed by first codec project):
- `bitreader.cyr` — MSB/LSB bit extraction (generalize shravan's FLAC/ALAC pattern)
- `entropy.cyr` — arithmetic/range coding (extend shravan's Opus range encoder)
- `cabac.cyr` — context-adaptive binary arithmetic coding (H.264/H.265)
- `boolcoder.cyr` — boolean coder (VP8/VP9)

## Platform Targets

| # | Platform | Format | Status |
|---|----------|--------|--------|
| 1 | Linux x86_64 | ELF | **Done** — primary target, 243KB self-hosting |
| 2 | Linux aarch64 | ELF | **Done** — cc3_aarch64 cross + native |
| 3 | macOS x86_64 | Mach-O | **Stub** (v3.1) — `src/backend/macho/emit.cyr` scaffolded |
| 4 | macOS aarch64 | Mach-O | **Stub** — combines Mach-O emitter + existing aarch64 codegen |
| 5 | Windows x86_64 | PE/COFF | **Stub** (v3.1) — `src/backend/pe/emit.cyr` scaffolded |
| 6 | RISC-V | ELF | Planned |
| 7 | cyrius-x bytecode | .cyx | **Done** (v2.5) — VM with recursion + syscall strings |

## Standard Library (34 modules + 4 deps)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, csv, base64, regex, math, matrix, bigint |
| Network | net, http |
| Filesystem | fs |
| Tracing (dep) | sakshi, sakshi_full |
| Database (dep) | patra |
| Security (dep) | sigil |
| Time | chrono |
| Knowledge | vidya |

**Next modules:**
- `lib/tls.cyr` — TLS 1.3 (sigil provides crypto primitives)
- `lib/ws.cyr` — WebSocket protocol (depends on http.cyr)
- `lib/log.cyr` — thin logging wrapper over sakshi

## Tooling

| Command | Status |
|---------|--------|
| `cyrius build` | **Done** — compile with -D defines, aarch64 cross |
| `cyrius test` | **Done** — .tcyr auto-discovery (shell), single file (binary) |
| `cyrius bench` | **Done** — .bcyr auto-discovery, history tracking |
| `cyrius fuzz` | **Done** — .fcyr harnesses + --compiler mutation mode |
| `cyrius soak` | **Done** — overnight loop: self-host + tests + fuzz + repos |
| `cyrius watch` | **Done** — poll + recompile on .cyr change |
| `cyrius deps` | **Done** — git fetch + symlink into lib/, `lib.cyr` → `<depname>.cyr` rename |
| `cyrius audit` | **Done** — delegates to scripts/check.sh |
| `cyrius fmt/lint/doc` | **Done** — cyrfmt, cyrlint, cyrdoc |
| `cyrius init/port` | **Done** — project scaffold, Rust port scaffold |
| `cyriusup` | **Done** — version manager (install/use/list/update) |
| `cyrius doc --serve` | **Done** — generates HTML docs + python3 HTTP server |
| `cyrius lsp` | Planned — Language Server Protocol for IDE integration |

## Ports & Ecosystem

| Status | Repos |
|--------|-------|
| **Done** | agnostik (553), agnosys (20 modules), argonaut (395), kybernet, nous, ark |
| **Done** | sakshi v0.9.0 (12), majra (144), bsp (74), cyrius-doom (129KB) |
| **Done** | sigil v2.0.1 (Ed25519, 206 assertions, 11 benchmarks) |
| **Done** | patra v0.12.0 (SQL, crypto via sigil), libro v1.0.1 (240 tests) |
| **Done** | shravan (audio — FLAC/Opus/WAV/AIFF, 284KB) |
| **In progress** | tarang (33K, media framework — needs FFI/dynlib for video codecs) |
| **In progress** | argonaut (final updates), bhava (29K), hisab (31K) |
| **Blocked** | ai-hwaccel (needs majra+libro), vidya MCP (needs bote) |
| **Remaining** | ~100 repos (~940K lines) |

## Open Limits

| Limit | Current |
|-------|---------|
| Functions | 2048 |
| Variables (VCNT) | 8192 |
| Globals (initialized) | 1024 |
| Locals per function | 256 |
| Fixup entries | 8192 |
| Struct fields | 32 |
| Input buffer | 512KB |
| Code buffer | 524288 bytes |
| Output buffer | 524288 bytes |
| String data | 32KB |
| Identifier names | 64KB |
| Tokens | 131072 |
| Macros | 16 |

## Downstream Blockers — resolved in 3.2.x

| # | Issue | Affected | Status | Details |
|---|-------|----------|--------|---------|
| 1 | ~~1024 function limit~~ | agnostik | **Resolved 3.2.2** | Expanded to 2048. |
| 2 | ~~`#derive(Serialize)` Str fields~~ | agnostik | **Resolved 3.2.3** | `: Str` annotation emits quoted strings; integers emit bare numbers. |
| 3 | ~~Nested if/while/break codegen~~ | agnostik | **Resolved 3.2.2** | Replaced `load8`+`==` with `strchr` for separator detection. |
| 4 | ~~`break` in deeply nested while/if~~ | agnostik, json.cyr | **Resolved 3.3.15** | Linked-list through codebuf rel32 fields. Each break chains prev offset. Walk chain at loop exit. Zero heap, no save/restore corruption. |
| 5 | ~~`#derive(Serialize)` composable 2-arg form~~ | agnostik | **Resolved 3.2.3** | 2-arg `_to_json_sb(ptr, sb)` form generated by derive. Str field support added. |
| 6 | ~~`#derive(Deserialize)` single-pass parser~~ | agnostik | **Done (v3.4.1)** | `_from_json_str(json)` generated by derive — O(n) single-pass with inline field matching. Handles int/string/negative. Existing `_from_json(pairs)` kept for backward compat. |

## Known Gotchas

| # | Behavior | Workaround |
|---|----------|------------|
| 1 | `var buf[N]` is N **bytes**, not N elements | `var buf[640]` for 80 i64 values |
| 2 | Global var as loop bound re-evaluates each iteration | Snapshot to local |
| 3 | Inline asm `[rbp-N]` clobbers function params | Use globals or dummy locals |
| 4 | Large static `var buf[N]` exhausts output buffer | Use `alloc(N)` for buffers >4KB |
| 5 | `\r` in string literals works but multiline strings need explicit bytes | Build CRLF with store8 |
| 6 | `load8` comparisons fail in nested while loops (codegen bug) | Use `memeq()` or `strchr()` instead of manual byte loops |

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Two-step bootstrap for any heap offset change
- Research before implementation — vidya entry before code
- Test after EVERY change, not after the feature is done
- 108 repos / ~1M lines is the real measure of success
- **v3.4.0 is the recommended minimum** — all downstream repos should pin to >= 3.4.0 (hex fix, 64KB tok_names, multi-break, 512KB codebuf)
