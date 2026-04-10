# Cyrius Development Roadmap

> **v3.3.5-dev.** 246KB self-hosting compiler, x86_64 + aarch64. Bug #4 workaround in stdlib.
> 31 test suites (375 assertions), 4 fuzz harnesses, soak test clean. 34 stdlib modules + 3 deps.
> 8 downstream repos pass. Format/lint/doc clean (excl patra).

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).
For bug history, see CHANGELOG.md (bugs #14-#31, all resolved).

---

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

## Platform Targets

| # | Platform | Format | Status |
|---|----------|--------|--------|
| 1 | Linux x86_64 | ELF | **Done** — primary target, 233KB self-hosting |
| 2 | Linux aarch64 | ELF | **Done** — cc3_aarch64 cross + native |
| 3 | macOS x86_64 | Mach-O | **Stub** (v3.1) — `src/backend/macho/emit.cyr` scaffolded |
| 4 | macOS aarch64 | Mach-O | **Stub** — combines Mach-O emitter + existing aarch64 codegen |
| 5 | Windows x86_64 | PE/COFF | **Stub** (v3.1) — `src/backend/pe/emit.cyr` scaffolded |
| 6 | RISC-V | ELF | Planned |
| 7 | cyrius-x bytecode | .cyx | **Done** (v2.5) — VM with recursion + syscall strings |

## Standard Library (38 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, csv, base64, regex, math, matrix, bigint |
| Network | net, http |
| Filesystem | fs |
| Database | patra |
| Security | sigil |
| Tracing | sakshi, sakshi_full |
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
| `cyrius deps` | **Scaffold** — reads [deps] from cyrius.toml, shows map |
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
| **Done** | sakshi (12), majra (144), libro (202), bsp (74), cyrius-doom (129KB) |
| **Done** | sigil v2.0.0 (Ed25519, 206 assertions, 11 benchmarks) |
| **In progress** | patra (SQL), libro |
| **In progress** | bhava (29K), hisab (31K) — keystone ports, unlock 37 downstream |
| **Blocked** | ai-hwaccel (needs majra+libro), vidya MCP (needs bote) |
| **Remaining** | 103 repos (~980K lines) |

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
| Code buffer | 262144 bytes |
| Output buffer | 262144 bytes |
| String data | 32KB |
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
| 6 | **`#derive(Deserialize)` single-pass parser** | agnostik | Request | Current manual `_from_json` does per-field string scan: O(fields × json_length). 3 fields = 2us, 9 fields = 25us. A derive-generated single-pass parser would be O(json_length), estimated ~2-3us regardless of field count. Would also fix json.cyr multi-key parsing (blocker #4). |

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
- **v3.2.5 is the true minimum version** — all downstream repos pin to >= 3.2.5
