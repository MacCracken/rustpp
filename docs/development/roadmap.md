# Cyrius Development Roadmap

> **v1.0 ready.** All criteria met. 128KB self-hosting compiler, both architectures.
> 251 tests, 0 failures. Audit 10/10. aarch64 byte-identical on Raspberry Pi.
>
> 108 Rust repos (~1M lines) to convert. 5 done. 103 remaining.

For completed work, see [completed-phases.md](completed-phases.md).
For detailed changes, see [CHANGELOG.md](../../CHANGELOG.md).

---

## v1.0 — Ship

All criteria met:

- [x] Self-hosting compiler (x86_64 + aarch64 byte-identical)
- [x] 251 tests, 0 failures
- [x] `cyrb audit` → 10/10
- [x] AGNOS kernel (62KB)
- [x] Complete toolchain (20+ cyrb commands)
- [x] Pattern matching, closures, modules, traits, floats, methods, operators
- [x] Subprocess bridge for external tool integration
- [x] C FFI header generation
- [x] Installer + version manager + release pipeline
- [x] All documentation current (tutorial, reference, FAQ, 37 vidya entries)

---

## v1.1 — Quality of Life

Improve ergonomics for the 39 small-repo ports (<5K lines):

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 1 | Real generics (type checking) | Low | Catch bugs at compile time |
| 2 | Enum constructors (auto-generate) | Medium | `Option::Some(val)` from enum def |
| 3 | For-in over collections | Low | `for item in v.iter() { }` sugar |
| 4 | Block body closures | Medium | `\|x\| { stmts; return val; }` |
| 5 | Shared library output (.so) | Medium | FFI bridge without subprocess |
| 6 | C FFI calling convention | Medium | Call Cyrius from C/Rust directly |

## v1.2 — Crate Migration Wave 2

Port bhava (29K) + hisab (31K) — the keystone libraries (37 repos depend on hisab):

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 7 | Const generics | Medium | `Matrix<N,M>`, `[T; N]` |
| 8 | Derive macros | Medium | serde Serialize/Deserialize |
| 9 | Operator overloading (address-based) | Medium | `Vec3 + Vec3` for stack structs |

## v1.3 — Infrastructure + Security

Port kavach, sigil, phylax (security stack):

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 10 | Ownership / borrow checker | Very High | Memory safety |
| 11 | Sandbox borrow checker | Very High | AGNOS security model |

## v1.4 — Concurrency

Port daimon, hoosh, agnosai (AI + async stack):

| # | Feature | Effort | Unlocks |
|---|---------|--------|---------|
| 12 | Concurrency primitives | High | Threads, atomics, channels |
| 13 | Async/await | High | tokio-style patterns |

---

## Systems Language Features

For cycc compatibility and general-purpose use:

| Feature | Effort | Unlocks |
|---------|--------|---------|
| Multi-file compilation (.o + link) | High | True separate compilation |
| Struct padding/alignment (sizeof) | Medium | ABI compat, FFI |
| Unions, bitfields | Medium | Hardware, protocols |
| Variadic functions | Medium | printf-style APIs |
| Multi-width types (i8, i16, i32) | Medium | Memory efficiency |
| Optimization passes (-O1) | Very High | Performance |
| Preprocessor macros (with args) | Medium | Generic patterns |

---

## Architecture Backends

| # | Architecture | Target Hardware | Status |
|---|-------------|----------------|--------|
| 1 | x86_64 | Desktop, server | **Done** — self-hosting |
| 2 | aarch64 | RPi, phones, Apple Silicon | **Done** — byte-identical on Pi |
| 3 | RISC-V | ESP32-C3, open hardware | Planned — open ISA, sovereignty aligned |
| 4 | MIPS | Ingenic X1600E, routers | Planned |
| 5 | Xtensa | ESP32-S3, IoT | Planned |

---

## cycc — C Compiler Frontend (v2.0+)

| Phase | Scope |
|-------|-------|
| 1 | C89 subset |
| 2 | C99/C11 |
| 3 | GCC extensions |
| 4 | Full preprocessor |
| 5 | Object files + linker |
| 6 | Optimization |

---

## Crate Migration

107 repos, ~980K lines. See [migration-strategy.md](migration-strategy.md) for the full plan,
wave breakdown, porting patterns, and bridge strategies.

---

## Principles

- Assembly is the cornerstone
- Own the toolchain — compiler, stdlib, package manager, build system
- No external language dependencies
- Byte-exact testing is the gold standard
- v1.0 ships when ready, not on a calendar
- 108 repos / ~1M lines is the real measure of success
- Subprocess bridge covers migration before FFI is ready
- Portable syscall constants for cross-architecture compilation
- Two-step bootstrap for any heap offset change
