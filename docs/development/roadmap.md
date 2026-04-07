# Cyrius Development Roadmap

> **v1.7.5.** 140KB self-hosting compiler, both architectures.
> 267 tests (216 compiler + 51 programs), 0 failures. Self-hosting byte-identical.
> Constant folding, tail call optimization, DCE, 512KB input buffer, 256 locals.
> Allocator regression fixed. aarch64 tail calls fixed. AGNOS aarch64 kernel compiles (44KB).
>
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## P1 Bugs

| # | Issue | Severity | Detail |
|---|-------|----------|--------|
| 1 | **assert+bench+12 modules fails** | P1 | Including assert.cyr + bench.cyr + all 12 agnostik modules produces `unexpected '+'` at ~line 2556. bench alone works, assert alone works, both together fail. ~693 functions, 347 vars pre-expansion. Might be token/VCNT overflow with combined libs. |
| 2 | **Bump allocator no arena** | P2 | alloc_reset() invalidates outstanding pointers. Need arena pattern for benchmarks. |
| 3 | ~~aarch64 large kernel fails~~ | ~~P1~~ | **Fixed** (v1.7.5). ETAILJMP missing from aarch64 backend. Also needed fixup type 4 (B not BL) for tail calls. AGNOS aarch64 kernel now compiles (44KB). |
| 4 | ~~1.7.4 allocator codegen regression~~ | ~~P2~~ | **Fixed** (v1.7.5). PMM back to 1,276 cycles (was 2,044 in v1.7.4, 1,304 in v1.7.1). Heap 32B back to 1,241 (was 2,065). Serial/VFS/memwrite improvements from constant folding retained. |

---

## Current — v1.7 Keystone Ports

Port bhava (29K) + hisab (31K) — the two libraries that unlock 37+ downstream repos:

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Const generics | Medium | `Matrix<N,M>`, `[T; N]` |
| 2 | Derive macros | Medium | serde Serialize/Deserialize |

---

## v1.8 — Infrastructure + Security

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Ownership / borrow checker | Very High | Memory safety |
| 2 | Sandbox borrow checker | Very High | AGNOS security model |

---

## v1.9 — Concurrency

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Concurrency primitives | High | Threads, atomics, channels |
| 2 | Async/await | High | tokio-style patterns |

---

## AGNOS Kernel — Next

Current: 97KB x86_64, boots on QEMU, 25 syscalls, interactive shell.

| # | Feature | Effort |
|---|---------|--------|
| 1 | **VirtIO net** | Medium |
| 2 | **TCP/IP stack** | Very High |
| 3 | **SMP** | High |
| 4 | **Signals** | Medium |
| 5 | **Pipe/redirect** | Medium |
| 6 | **ATA/NVMe** | High |
| 7 | **FAT32 or ext2** | High |

---

## Performance Optimizations

### Remaining

| # | Optimization | Target | Status |
|---|-------------|--------|--------|
| 1 | Branch optimization | `notify_parse`: 20ns vs Rust 2ns | Jump tables for dense switches |
| 2 | Inline small functions | `W* macros`: 7ns vs Rust 1ns | Needs token replay or IR |
| 3 | Stack-allocated small strings | `str_builder`: 371ns vs Rust 52ns | Avoid heap < 64 bytes |
| 4 | Arena allocator | `seccomp_build`: 2.4us vs Rust 69ns | Batch allocation |
| 5 | Return-by-value small structs | General | Structs <= 2 registers |
| 6 | Register allocation | General | High effort, reduce spills |
| 7 | Constant folding for + - & \| ^ | General | Same approach as * / << >>, needs paren-safety |

### Done

| Optimization | Version |
|-------------|---------|
| Dead code elimination (3-byte stubs) | v1.7.0 |
| Tail call optimization (epilogue + jmp) | v1.7.2 |
| EMOVI optimization (xor/mov eax) | v1.6.7 |
| Compare-and-branch fusion (cmp + jCC) | Always (if/while/for) |
| Constant folding (* / << >>) | v1.7.3 |

---

## Systems Language Features

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation |
| Struct padding/alignment (sizeof) | Medium | ABI compat, FFI |
| Unions, bitfields | Medium | Hardware, protocols |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32) | Medium | Memory efficiency |

---

## Open Limits

| Limit | Current | Detail |
|-------|---------|--------|
| Functions | 1024 | Error at limit |
| Variables (VCNT) | 2048 | Never resets between functions |
| Locals per function | 256 | Expanded from 64 in v1.7.4 |
| Input buffer | 512KB | Lex from preprocess buffer (v1.7.2) |
| Code buffer | 196608 bytes | Overflow detected |
| Identifier buffer | 65536 bytes | Error with count |
| Macros | 16 | |

---

## Architecture Backends

| # | Architecture | Status |
|---|-------------|--------|
| 1 | x86_64 | **Done** — self-hosting, 140KB |
| 2 | aarch64 | **Done** — kernel mode, arch-specific asm |
| 3 | RISC-V | Planned |
| 4 | MIPS | Planned |
| 5 | Xtensa | Planned |

---

## Crate Migration

108 repos, ~1M lines. See [migration-strategy.md](migration-strategy.md).

---

## cyrius-x — Portable Bytecode (v2.0+)

A Cyrius-native portable bytecode format. Not WASM — designed for AGNOS, systems-first, agent-native.

| Phase | Scope |
|-------|-------|
| 1 | Bytecode format specification |
| 2 | cyrius-x emitter backend |
| 3 | cyrius-x interpreter (~10-20KB) |
| 4 | kavach sandbox integration |
| 5 | Agent distribution |
| 6 | JIT (hot paths) |

---

## cyrius-ts — TypeScript/JavaScript Bridge Frontend (v2.0+)

Not a transpiler. Not a new language. A **compiler frontend** — same pattern as cycc for C. TS-like syntax parsed into Cyrius IR, same backend, same binary output. 20 million JS/TS developers write what they know, the compiler produces sovereign binaries.

```
.cyr  ──→ ┐
.cts  ──→ ├──→ Cyrius IR ──→ codegen ──→ x86_64 / aarch64 / cyrius-x
.c    ──→ ┘
         Three frontends. One compiler. One backend.
```

### What TS Developers Get

```
// hello.cts — looks like TypeScript, compiles to 15KB binary
import { serve, json } from "std/http"

serve(8080, (req) => {
  if (req.path == "/api/hello") {
    return json({ message: "Welcome to the Future" })
  }
  return { status: 404, body: "not found" }
})
```

### Syntax Mapping

| TypeScript | Cyrius equivalent | Notes |
|-----------|-------------------|-------|
| `let x = 5` | `var x = 5` | Direct mapping |
| `const` | `var` | Const enforcement planned |
| `function f()` | `fn f()` | |
| `(x) => x * 2` | `\|x\| x * 2` | Closures already exist |
| `{ name: "Mac" }` | `struct + init` | Object literal → struct construction |
| `[1, 2, 3]` | `vec_new + vec_push` | Array literal → vec |
| `for (x of items)` | `for x in items` | |
| `async/await` | `async fn` / `await` | Planned v1.9 |
| `import/export` | `mod/use/pub` | Module system exists |
| `console.log()` | `println()` | |
| `` `hello ${name}` `` | template strings | Backtick interpolation |
| `JSON.parse()` | `json_parse()` | json.cyr exists |
| `match` | `match` | Pattern matching exists |

### Existing Cyrius Coverage

| TS/Node.js need | Cyrius status |
|----------------|--------------|
| JSON | json.cyr — parse, get, build (done) |
| TCP/UDP sockets | net.cyr — raw sockets (done) |
| Filesystem | fs.cyr — read, write, dir, walk (done) |
| Process | process.cyr — spawn, capture (done) |
| Regex | regex.cyr — glob, find, replace (done) |
| Strings | str.cyr — 16+ methods (done) |
| HashMap | hashmap.cyr — FNV-1a, open addressing (done) |
| HTTP | needs: request/response parser, router |
| Template strings | needs: backtick interpolation in compiler |
| async/await | needs: v1.9 concurrency |

### Phases

| Phase | Scope | Prerequisite |
|-------|-------|-------------|
| 1 | **TS parser frontend** — lex .cts files, map to Cyrius IR | v1.7 (current compiler mature enough) |
| 2 | **Template strings** — backtick interpolation in compiler | Compiler change (lex + codegen) |
| 3 | **HTTP library** — request/response, router, middleware | net.cyr (done), json.cyr (done) |
| 4 | **Web stdlib** — console, fetch, URL, FormData equivalents | HTTP library |
| 5 | **`cyrb port-ts`** — automated Node.js project migration | Parser + stdlib |
| 6 | **npm sandbox** — run npm packages in kavach container via cyrius-x | cyrius-x interpreter |
| 7 | **DOM-equivalent** — UI via aethersafha compositor, not browser | aethersafha integration |

### The Numbers

| Metric | Node.js/Express | cyrius-ts |
|--------|----------------|-----------|
| Runtime | V8 ~30MB | cyrius-x ~10-20KB |
| Startup | 30-50ms | <1ms |
| Hello world binary | ~30MB (node + deps) | ~15KB |
| Dependencies for web server | express + 57 transitive | 0 |
| Runs on ESP32 ($4 MCU) | No (V8 too large) | Yes |
| `npm install` arbitrary code | Yes | No (sigil-verified, no install scripts) |
| Supply chain attack surface | npm (2M+ packages, any can inject) | Zero deps default, kavach-sandboxed imports |

### Adoption Path

The developer doesn't learn Cyrius. They write TypeScript-like code in `.cts` files. The compiler handles the translation. The output is a sovereign binary — same 168-byte `true`, same 15KB web server, same architecture as everything else in AGNOS.

Over time, developers who want more control drop into `.cyr` syntax for performance-critical paths — same way C developers drop into assembly. The bridge becomes a gateway.

---

## Known Gotchas

| # | Behavior | Fix |
|---|----------|-----|
| 1 | Global var as loop bound re-evaluates each iteration | Snapshot to local |
| 2 | Inline asm `[rbp-N]` clobbers function params | Use globals or dummy locals |
| 3 | `var buf[N]` is N bytes, not N elements | `var buf[120]` for 120-byte struct |
| 4 | ~~`&&`/`\|\|` only in conditions~~ | **Fixed** (v1.7.4). `return a > 0 && b > 0;` and `var r = a == b;` now work. PARSE_CMP_EXPR handles `&&`/`\|\|` as AND/OR on 0/1 values. Both `var =` and `x =` assignments use PARSE_CMP_EXPR. |

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- 108 repos / ~1M lines is the real measure of success
- Subprocess bridge covers migration before FFI is ready
- Two-step bootstrap for any heap offset change
