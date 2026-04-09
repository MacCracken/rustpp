# Cyrius — Claude Code Instructions

## Project Identity

**Cyrius** — Sovereign, self-hosting systems language. Assembly up.

- **Type**: Self-hosting compiler toolchain
- **License**: GPL-3.0-only
- **Version**: 2.7.2

## Goal

Own the language. Own the toolchain. No crates.io. No external governance. Assembly is the cornerstone. Cyrius writes the AGNOS kernel.

## Current State

- **Compiler**: 215KB (x86_64), self-hosting, multi-width types, sizeof, unions, bitfields
- **Tests**: 23 .tcyr files (287 assertions), 4 .fcyr fuzz harnesses, heap audit, self-hosting (two-step)
- **Libraries**: 31 modules, 200+ functions
- **Ecosystem**: 5 crate rewrites (agnostik, agnosys, kybernet, nous, ark), argonaut (424 tests)

## Consumers

AGNOS kernel, agnostik (58 tests), agnosys (20 modules), argonaut (424 tests), sakshi, cyrius-doom, bsp. All AGNOS ecosystem projects depend on the compiler and stdlib.

## Bootstrap Chain

```
bootstrap/asm (29KB committed binary — root of trust)
  → stage1f (12KB compiler)
    → bridge.cyr (bridge compiler)
      → cc2 (modular compiler, 215KB, 8 modules)
        → cc2_aarch64 (cross-compiler)

No Rust. No LLVM. No Python. Just sh + Linux x86_64.
Build: sh bootstrap/bootstrap.sh
```

## Quick Start

```bash
sh bootstrap/bootstrap.sh          # bootstrap from seed
cat src/main.cyr | build/cc2 > /tmp/cc3 && chmod +x /tmp/cc3  # build compiler
cat src/main.cyr | /tmp/cc3 > /tmp/cc4 && cmp /tmp/cc3 /tmp/cc4  # self-hosting verify
sh scripts/check.sh                # full audit
cyrius test                        # run .tcyr suite
cyrius fuzz                        # run .fcyr harnesses
cyrius bench                       # run .bcyr benchmarks
```

## Key Principles

- **Self-hosting is non-negotiable** — cc2==cc3 byte-identical after every compiler change
- **Two-step bootstrap for heap changes** — cc3 compiles cc4, cc3==cc4
- **Assembly is the cornerstone** — understand every instruction the compiler emits
- **Test after EVERY change** — not after the feature is "done"
- **ONE change at a time** — never bundle unrelated changes
- **Research before implementation** — vidya entry before code
- **3 failed attempts = defer and document** — don't burn time
- **Bootstrap chain integrity** — never break seed → stage1f → bridge → cc2

## P(-1): Scaffold Hardening

Before starting new work on a release, run this audit phase:

1. **Cleanliness** — `cyrius fmt --check`, `cyrius lint`, `cyrius vet`
2. **Test sweep** — all .tcyr pass, heap audit clean, self-hosting verified
3. **Benchmark baseline** — `cyrius bench` before changes
4. **Audit** — identify stale code, dead paths, optimization opportunities
5. **Refactor** — address findings from audit
6. **Post-audit benchmarks** — compare against baseline
7. **Document** — update CHANGELOG, roadmap, vidya

## Development Loop

```
1. RESEARCH    — Check vidya for existing patterns
2. BUILD       — ONE change at a time
3. TEST        — After EACH change:
                 ☐ Basic: 'var x = 42;' → 42
                 ☐ Self-hosting: cc2==cc3 byte-identical
                 ☐ Full suite: sh scripts/check.sh
4. IF BROKEN   — Revert, apply ONE change, test, repeat
                 3 failed attempts = defer and document
5. AUDIT       — Full chain: bootstrap, all suites, self-hosting
6. DOCUMENT    — Update: CHANGELOG, roadmap, benchmarks, vidya
```

## Project Structure

```
bootstrap/           29KB seed binary + stage1f.cyr + asm.cyr
src/
  main.cyr           Compiler entry point (includes modules)
  main_aarch64.cyr   Cross-compiler (swaps arch includes)
  bridge.cyr         Bridge compiler (stage1f feature set)
  frontend/          lex.cyr, parse.cyr
  backend/x86/       emit.cyr, jump.cyr, fixup.cyr
  backend/aarch64/   emit.cyr, jump.cyr, fixup.cyr
  backend/cx/        emit.cyr (cyrius-x bytecode)
  common/            util.cyr
lib/                 Standard library (31 modules)
programs/            57 programs (tools, tests, demos, algorithms)
tests/               Test suites (tcyr/*.tcyr, bcyr/*.bcyr, heapmap.sh)
fuzz/                Fuzz harnesses (*.fcyr)
build/               Generated binaries (gitignored except cc2)
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
- Do not remove build/cc2-native-aarch64 — ARM binary needed for self-hosting on ARM hardware
