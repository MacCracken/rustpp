# Cyrius — Claude Code Instructions

## Project Identity

**Cyrius** — Sovereign, self-hosting systems language. Assembly up.

- **Type**: Self-hosting compiler toolchain
- **License**: GPL-3.0-only
- **Version**: 5.0.0

## Goal

Own the language. Own the toolchain. No crates.io. No external governance. Assembly is the cornerstone. Cyrius writes the AGNOS kernel.

## Current State

- **Compiler**: 368KB (x86_64), aarch64 cross-compiler (native non-functional until 5.0), self-hosting, multi-width types, sizeof, unions, bitfields, defer (all exit paths), expression-position comparisons, `#assert`, Str/cstr auto-coercion, string interning, syscall arity warnings, `#derive(accessors)`, native multi-return, switch case blocks, `+=`/`-=`/`*=`, negative literals, undefined function diagnostic, short-circuit `&&`/`||`, struct initializer syntax, `#regalloc` (multi-register), single-CU DCE, CYML parser
- **Tests**: 58 .tcyr files, 5 .fcyr fuzz harnesses, 14 .bcyr benchmarks, heap audit, self-hosting (two-step)
- **Libraries**: 59 stdlib modules (includes 6 deps: sakshi, patra, sigil, yukti, mabda, sankoch via `cyrius deps`)
- **Build tool**: `cyrius deps` resolves from cyrius.toml, auto-runs on build/run/test. Namespaced deps: `lib/{depname}_{basename}`. Auto-prepends includes.
- **Ecosystem**: agnostik, agnosys, argonaut, majra, libro (209 tests), sakshi, bsp, cyrius-doom, mabda, kybernet (140 tests), hadara (329 tests), ai-hwaccel (491 tests)

## Consumers

AGNOS kernel, agnostik (58 tests), agnosys (20 modules), argonaut (424 tests), sakshi, sigil (206 tests), libro (240 tests), shravan (audio), cyrius-doom, bsp. All AGNOS ecosystem projects depend on the compiler and stdlib.

## Bootstrap Chain

```
bootstrap/asm (29KB committed binary — root of trust)
  → cyrc (12KB compiler)
    → bridge.cyr (bridge compiler)
      → cc3 (modular compiler, 303KB, 8 modules)
        → cc3_aarch64 (cross-compiler)

No Rust. No LLVM. No Python. Just sh + Linux x86_64.
Build: sh bootstrap/bootstrap.sh
```

## Quick Start

```bash
sh bootstrap/bootstrap.sh          # bootstrap from seed
cat src/main.cyr | build/cc3 > /tmp/cc3 && chmod +x /tmp/cc3  # build compiler
cat src/main.cyr | /tmp/cc3 > /tmp/cc4 && cmp /tmp/cc3 /tmp/cc4  # self-hosting verify
sh scripts/check.sh                # full audit
cyrius test                        # run .tcyr suite
cyrius fuzz                        # run .fcyr harnesses
cyrius bench                       # run .bcyr benchmarks
```

## Key Principles

- **Self-hosting is non-negotiable** — cc3==cc3 byte-identical after every compiler change
- **Two-step bootstrap for heap changes** — cc3 compiles cc4, cc3==cc4
- **Assembly is the cornerstone** — understand every instruction the compiler emits
- **Test after EVERY change** — not after the feature is "done"
- **ONE change at a time** — never bundle unrelated changes
- **Research before implementation** — vidya entry before code
- **3 failed attempts = defer and document** — don't burn time
- **Bootstrap chain integrity** — never break seed → cyrc → bridge → cc3

## P(-1): Scaffold Hardening

Before starting new work on a release, run this audit phase:

1. **Cleanliness** — `cyrius fmt --check`, `cyrius lint`, `cyrius vet`
2. **Test sweep** — all .tcyr pass, heap audit clean, self-hosting verified
3. **Benchmark baseline** — `cyrius bench` before changes
4. **Audit** — identify stale code, dead paths, optimization opportunities
5. **Refactor** — address findings from audit
6. **Post-audit benchmarks** — compare against baseline
7. **Document** — update CHANGELOG, roadmap, vidya

## Closeout Pass (before every minor/major bump)

Run a closeout pass before tagging x.Y.0 or x.0.0. Ship as the last patch of the current minor (e.g. 4.2.5 before 4.3.0):

1. **Self-host verify** — cc3 compiles itself byte-identical
2. **Bootstrap closure** — seed → cyrc → asm → cyrc byte-identical
3. **Dead code audit** — check dead function count, remove dead source code
4. **Stale comment sweep** — grep for old version refs, outdated TODOs
5. **Heap map verify** — main.cyr heap map matches actual usage
6. **Downstream check** — all .cyrius-toolchain files point to current release
7. **Security re-scan** — quick grep for new `sys_system`, `READFILE`, unchecked writes
8. **CHANGELOG/roadmap/vidya sync** — all docs reflect current state
9. **Full check.sh** — 5/5 pass

## Security Audit Process

Periodically (before major releases, after significant changes), run a security audit:

1. **Research** — review known vulnerability classes for compilers and build tools:
   - Buffer overflows (fixed-size heap regions, unchecked writes)
   - Command injection (shell commands from user-controlled input)
   - Path traversal (include directives, dep resolution, file writes)
   - Integer overflow (limit checks, table sizes)
   - Race conditions (temp files, concurrent access)
   - Trust chain (seed binary, release signing, dep integrity)
2. **Scan** — static analysis of source for vulnerable patterns:
   - `sys_system()` / `sys_execve()` with user-controlled args
   - `READFILE` / `sys_open` with unvalidated paths
   - `store8`/`store64` without bounds checking near region boundaries
   - Silent overflow on table limits (return instead of error)
   - Predictable temp file paths
3. **Report** — file findings in `docs/audit/{date}-security-audit.md`:
   - Each finding gets a CVE-XX identifier, severity (P0-P3), affected file, vector, impact, fix
   - Action items organized into current and upcoming minor versions
   - Don't move existing roadmap items — add security items alongside
4. **Fix** — prioritize by severity:
   - P0 (Critical): fix in immediate patch release
   - P1 (High): fix in current minor version
   - P2 (Medium): fix in next minor version
   - P3 (Low): track for future
5. **Verify** — regression test each fix, re-audit affected area

## Development Loop

```
1. RESEARCH    — Check vidya for existing patterns
2. BUILD       — ONE change at a time
3. TEST        — After EACH change:
                 ☐ Basic: 'var x = 42;' → 42
                 ☐ Self-hosting: cc3==cc3 byte-identical
                 ☐ Full suite: sh scripts/check.sh
4. IF BROKEN   — Revert, apply ONE change, test, repeat
                 3 failed attempts = defer and document
5. AUDIT       — Full chain: bootstrap, all suites, self-hosting
6. DOCUMENT    — Update: CHANGELOG, roadmap, benchmarks, vidya
```

## Project Structure

```
bootstrap/           29KB seed binary + cyrc.cyr + asm.cyr
src/
  main.cyr           Compiler entry point (includes modules)
  main_aarch64.cyr   Cross-compiler (swaps arch includes)
  bridge.cyr         Bridge compiler (cyrc feature set)
  frontend/          lex.cyr, parse.cyr
  backend/x86/       emit.cyr, jump.cyr, fixup.cyr
  backend/aarch64/   emit.cyr, jump.cyr, fixup.cyr
  backend/cx/        emit.cyr (cyrius-x bytecode)
  common/            util.cyr
lib/                 Standard library (41 modules + 5 deps)
programs/            59 programs (tools, tests, demos, algorithms)
tests/               Test suites (tcyr/*.tcyr, bcyr/*.bcyr, heapmap.sh)
fuzz/                Fuzz harnesses (*.fcyr)
build/               Generated binaries (gitignored except cc3)
docs/                Architecture, roadmap, benchmarks, language guide
```

## Key References

- `docs/cyrius-guide.md` — Complete language reference
- `docs/development/roadmap.md` — Development plan + bug tracker
- `CHANGELOG.md` — Source of truth for all changes
- `../vidya/content/compiler_bootstrapping/cyrius_*.toml` — 90+ vidya entries

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not add language features without updating vidya
- Do not skip self-hosting verification after compiler changes
- Do not modify parse.cyr arch-specific functions — they live in emit files
- Do not remove build/cc3-native-aarch64 — ARM binary needed for self-hosting on ARM hardware (generated by `cyrius pulsar`, non-functional until 5.0 host/target syscall separation)
- **v4.8.4 is the recommended minimum** — PP_IFDEF_PASS 256 KB scan-blindness fix (post-GA retag) is critical for any consumer whose transitive include graph expands past 512 KB. Below that floor large units can fail with a misleading `lib/assert.cyr:3: expected '=', got string` parse error. (v4.8.5 adds math stdlib + CRLF hardening in `lib/http.cyr` on top.)
