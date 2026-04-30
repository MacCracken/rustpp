# Cyrius

**Sovereign, self-hosting systems language. Assembly up.**

A self-hosting compiler toolchain that bootstraps from a 29KB binary with zero external dependencies. No Rust, no LLVM, no Python, no libc. Writes the [AGNOS](https://github.com/MacCracken/agnos) kernel, its own package manager, and its own build tool.

~720KB compiler. Self-hosting on x86_64 + aarch64 (cross + native), Windows PE cross, macOS aarch64 cross, cyrius-x bytecode. 67 stdlib modules + 7 deps. 93 test suites + 1 soak + 1 smoke harness, 5 fuzz harnesses, 15 benchmarks.

## Install

```sh
curl -sSf https://raw.githubusercontent.com/MacCracken/cyrius/main/scripts/install.sh | sh
```

Or build from source:

```sh
sh bootstrap/bootstrap.sh
```

## Quick Start

```sh
# Compile and run
cyrius run hello.cyr

# Create a project
cyrius init myproject
cd myproject
cyrius build src/main.cyr build/myproject

# Port a Rust project
cyrius port /path/to/rust-project

# Full audit (format, lint, vet, deny, test, bench, doc)
cyrius audit
```

## Language

```cyrius
include "lib/alloc.cyr"
include "lib/str.cyr"
include "lib/vec.cyr"

struct Point { x; y; }

impl Math for Point {
    fn sum(self) { return load64(self) + load64(self + 8); }
}

fn Point_add(a, b) {
    store64(a, load64(a) + load64(b));
    store64(a + 8, load64(a + 8) + load64(b + 8));
    return a;
}

enum Result { Ok(val) = 0; Err(code) = 1; }

fn main() {
    alloc_init();
    var a = Point { 1, 2 };
    var b = Point { 3, 4 };
    Point_add(&a, &b);
    return Point_sum(&a);
}

var r = main();
syscall(60, r);
```

### Features

- Structs, enums (`Enum.VARIANT` namespacing), match, for-in, closures, impl blocks
- 20+ f64 builtins (add/sub/mul/div + sin/cos/exp/ln/log2/exp2/sqrt/abs/floor/ceil + atan)
- Phase O1–O6 optimizer: FNV-1a fn lookup, strength reduction, flag-result reuse, push/pop cancel, combine-shuttle elim, IR const-fold, DCE, DSE, linear-scan regalloc (default-on), NOP-harvest codebuf compaction
- Explicit overflow operators: `+%`/`-%`/`*%` (wrap), `+|`/`-|`/`*|` (saturate), `+?`/`-?`/`*?` (checked-panic)
- `#derive(Serialize)` for JSON serialization, `#derive(accessors)` for field getters/setters
- `#ref "file.cyml"` directive for CYML config loading
- `#must_use`, `#deprecated("msg")`, `@unsafe` attributes
- `#else` / `#elif` / `#ifndef` / `#ifplat` preprocessor
- Native multi-return: `return (a, b)` + `var x, y = fn()` destructuring
- Switch case blocks: `case N: { ... }` with scoped variables
- Defer on all exit paths (per-defer runtime flags, unreached defers skipped)
- Str/cstr auto-coercion, compile-time string interning, `#assert`, `secret var`
- Expression-position comparisons: `var r = (a == b)` works everywhere
- Inline small functions (token replay), relaxed fn ordering
- Include-once semantics, inline assembly (`asm { }`)

### Metrics

| Metric | Value |
|--------|-------|
| Compiler | **~720KB** x86_64, **~412KB** aarch64 cross |
| Seed binary | **29KB** |
| External dependencies | **0** |
| Tests | 93 .tcyr (TS suite consolidated 24→4 at v5.7.37), 5 .fcyr fuzz, 15 .bcyr bench, 1 .scyr soak, 1 .smcyr smoke |
| Architectures | x86_64 + aarch64 (cross + native), Windows PE cross, macOS aarch64 cross, cyrius-x bytecode |
| Caps | ident buffer 128KB, fn table 4096, fixup table 1M (v5.7.7), input_buf 1MB (v5.7.10), distlib per-module 256KB (v5.7.36), aarch64 codebuf 3MB (v5.7.34) |

## Build Tool (cyrius)

```
Build:     build [-v] [--aarch64] [-D NAME], run, test, bench, check, self, clean
Deps:      deps — resolve [deps] from cyrius.cyml into lib/ (auto-runs on build)
Project:   init, package, publish, install, update, port
Quality:   audit, fmt, lint, doc, vet, deny, distlib, capacity
Testing:   coverage, doctest, soak [N], smoke
LSP:       lsp — build/install cyrius-lsp (also auto-installed via cyriusly setup)
Info:      version, which, help
```

Dependencies declared in `cyrius.cyml` are auto-resolved on `build`/`run`/`test`:

```toml
[deps.agnostik]
git = "https://github.com/MacCracken/agnostik.git"
tag = "1.0.0"
modules = ["dist/agnostik.cyr"]
```

Named deps are namespaced: `lib/{depname}_{basename}` (e.g. `lib/agnostik_types.cyr`).
Includes are auto-prepended — source files only need project-specific includes.

## Standard Library (67 modules + 7 deps)

`sandhi` (HTTP/2 + JSON-RPC + service discovery + TLS policy, ~9,650 lines / 469 fns) was folded into stdlib at v5.7.0 from a sibling crate — `lib/http_server.cyr` retired in the same release. Same precedent as sakshi / mabda / sankoch (started as sibling crates, folded once stable). v5.7.35 added `lib/random.cyr` (getrandom + GrndFlag enum + random_bytes loop) and `lib/security.cyr` (LandlockAccessFs + LandlockRuleType enums) as new first-party modules, agnosys-surfaced.

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr, flags |
| Types | tagged (Option/Result), hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread (clone+mmap, mutex, MPSC), thread_local, atomic, async, freelist |
| Data | json, toml, cyml, csv, base64, regex, math, matrix, linalg, bigint, u128 |
| Crypto | sha1, keccak, ct (constant-time primitives), overflow, **random** (kernel entropy via getrandom) |
| Sandboxing | **security** (Landlock policy enums; v5.7.35) |
| Network | net, http, ws, tls, **sandhi** (HTTP/2 + RPC + service discovery; folded v5.7.0) |
| Filesystem | fs |
| Audio | audio (ALSA PCM) |
| Logging | log (structured, over sakshi) |
| Time | chrono |
| Knowledge | vidya |
| Interop | mmap, dynlib, fdlopen (foreign-dlopen), cffi |
| Identity | pwd, grp, shadow, pam |
| Tracing (dep) | sakshi |
| Database (dep) | patra |
| Security (dep) | sigil |
| Hardware (dep) | yukti |
| GPU (dep) | mabda |
| Compression (dep) | sankoch |

## Compiler Architecture

```
src/
  main.cyr              Entry point (orchestration, passes)
  main_aarch64.cyr      aarch64 cross-compiler entry
  main_aarch64_native.cyr   Native aarch64 (Pi) entry
  main_aarch64_macho.cyr    macOS aarch64 Mach-O entry
  main_win.cyr          Windows PE entry
  main_cx.cyr           cyrius-x bytecode entry
  bridge.cyr            Bridge compiler (cyrc feature set)
  version_str.cyr       Auto-generated version string

  frontend/
    lex.cyr             Lexer + preprocessor (include-once, #derive, #ifdef/#elif/#else/#ifndef/#ifplat)
    parse.cyr           Parser + codegen dispatch (split into parse_decl, parse_expr, parse_fn, parse_ctrl, ...)
    ts/                 TypeScript frontend (lex + parse, .ts/.tsx → cyrius IR)

  backend/x86/          x86_64 instruction emission, jump, fixup, ELF/PE/Mach-O
  backend/aarch64/      aarch64 emission (same structure)
  backend/cx/           cyrius-x bytecode emission

  common/
    util.cyr            State accessors, error functions
    ir.cyr              IR + control-flow graph (LASE, const-fold, DCE, DSE, regalloc, NOP-harvest)
```

### Bootstrap Chain

```
bootstrap/asm (29KB committed binary -- root of trust)
  -> cyrc (12KB compiler)
    -> bridge.cyr (bridge compiler)
      -> cc5 (modular compiler + IR, ~720KB)
        -> cc5_aarch64, cc5_win_cross, cc5_macho_cross, cc5_cx (cross-compilers)
```

## Migration

`cyrius port` scaffolds Cyrius projects from Rust repos. See the [roadmap](docs/development/roadmap.md) for the full ecosystem state and [migration strategy](docs/development/migration-strategy.md) for the porting playbook.

## License

GPL-3.0-only
