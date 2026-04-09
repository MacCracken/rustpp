# Cyrius Development Roadmap

> **v3.2.2.** 231KB self-hosting compiler, x86_64 + aarch64. Zero open bugs.
> 29 test suites (362 assertions), 4 fuzz harnesses, soak test clean. 35 stdlib modules.
> 8 downstream repos pass. 207 vidya entries. Format/lint/doc 100% clean.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).
For bug history, see CHANGELOG.md (bugs #14-#31, all resolved).

---

## Compiler

| # | Feature | Effort | Status |
|---|---------|--------|--------|
| 1 | **Multi-file linker** (Phase 2) | High | .o emission done (v2.6.4). Need: read .o files, resolve symbols, patch relocations, emit executable. Write in Cyrius. |
| 2 | **Deferred formatting** (defmt) | High | Not started. String interning + decode. Eliminates runtime fmt overhead for logging/tracing. |
| 3 | **u128** | High | Research. 128-bit integers via register pairs. |
| 4 | **Cross-function inlining** | High | Research. Beyond token replay. |
| 5 | **Variadic functions** | Medium | Deferred. Vec-based pattern sufficient for all current ports. |
| 6 | **`defer` statement** | Medium | Not started. Reuse break/continue patch infrastructure. Zig/Odin parity. |

## Platform Targets

| # | Platform | Format | Status |
|---|----------|--------|--------|
| 1 | Linux x86_64 | ELF | **Done** — primary target, 231KB self-hosting |
| 2 | Linux aarch64 | ELF | **Done** — cc2_aarch64 cross + native |
| 3 | macOS x86_64 | Mach-O | **Stub** (v3.1) — `src/backend/macho/emit.cyr` scaffolded |
| 4 | macOS aarch64 | Mach-O | **Stub** — combines Mach-O emitter + existing aarch64 codegen |
| 5 | Windows x86_64 | PE/COFF | **Stub** (v3.1) — `src/backend/pe/emit.cyr` scaffolded |
| 6 | RISC-V | ELF | Planned |
| 7 | cyrius-x bytecode | .cyx | **Done** (v2.5) — VM with recursion + syscall strings |

## Standard Library (35 modules)

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, csv, base64, regex, math, matrix |
| Network | net, http |
| Filesystem | fs |
| Tracing | sakshi, sakshi_full |
| Time | chrono |
| Knowledge | vidya |

**Next modules:**
- `lib/tls.cyr` — TLS 1.3 (needs C FFI or raw crypto)
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
| `cyrius lsp` | Planned — Language Server Protocol for IDE integration |
| `cyrius doc --serve` | Planned — local HTTP server for generated docs |

## Ports & Ecosystem

| Status | Repos |
|--------|-------|
| **Done** | agnostik (553), agnosys (20 modules), argonaut (395), kybernet, nous, ark |
| **Done** | sakshi (12), majra (144), libro (202), bsp (74), cyrius-doom (129KB) |
| **In progress** | bhava (29K), hisab (31K) — keystone ports, unlock 37 downstream |
| **Blocked** | ai-hwaccel (needs majra+libro), vidya MCP (needs bote) |
| **Remaining** | 103 repos (~980K lines) |

## Open Limits

| Limit | Current |
|-------|---------|
| Functions | 1024 |
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

## Downstream Blockers — requesting 3.2.x fix

| # | Issue | Affected | Status | Details |
|---|-------|----------|--------|---------|
| 1 | ~~1024 function limit~~ | agnostik | **Resolved 3.2.2** | Expanded to 2048. Agnostik can now add `_from_json` deserialization. |
| 2 | **`#derive(Serialize)` formats all values as strings** | agnostik | Open | Auto-generated `_to_json` renders integers as `"42"` not `42`. Consumers need manual overrides for correct numeric JSON. Request: detect integer/bool fields and emit `str_builder_add_int` instead of string quoting. |
| 3 | **Nested if/while/break codegen** | agnostik | Open | `version_from_str` correctly stores prerelease inside `if (sep == 45) { while (...) { break; } ... store64(v+24, pre); }` but value is NULL at runtime when both prerelease+build present. Simple prerelease (no build) works. Suspect break inside while inside if clobbers a register or skips the store. |

## Known Gotchas

| # | Behavior | Workaround |
|---|----------|------------|
| 1 | `var buf[N]` is N **bytes**, not N elements | `var buf[640]` for 80 i64 values |
| 2 | Global var as loop bound re-evaluates each iteration | Snapshot to local |
| 3 | Inline asm `[rbp-N]` clobbers function params | Use globals or dummy locals |
| 4 | Large static `var buf[N]` exhausts output buffer | Use `alloc(N)` for buffers >4KB |
| 5 | `\r` in string literals works but multiline strings need explicit bytes | Build CRLF with store8 |

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- Two-step bootstrap for any heap offset change
- Research before implementation — vidya entry before code
- Test after EVERY change, not after the feature is done
- 108 repos / ~1M lines is the real measure of success
