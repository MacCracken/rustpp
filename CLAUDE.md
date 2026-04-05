# Cyrius — Claude Code Instructions

## Project Identity

**Cyrius** — Sovereign, self-hosting systems language. Assembly up.

- **Type**: Self-hosting compiler toolchain
- **License**: GPL-3.0-only
- **Version**: 0.9.0
- **Targets**: x86_64 + aarch64 (cross-compilation)

## Goal

Own the language. Own the toolchain. No crates.io. No external governance. Ark is the package manager. Assembly is the cornerstone. Cyrius writes the AGNOS kernel.

## Current State

- **Compiler**: 93KB, self-hosting, 11ms self-compile
- **Tests**: 168 x86_64 (111 compiler + 57 programs), 29 aarch64, 0 failures
- **Libraries**: 24 modules, 150+ functions
- **Ecosystem**: 5 crate rewrites (agnostik, agnosys, kybernet, nous, ark)
- **Tools**: cyrb (build tool), ark (package manager)
- **Kernel**: AGNOS 62KB (in separate repo: github.com/MacCracken/agnos)

## Bootstrap Chain

```
bootstrap/asm (29KB committed binary — root of trust)
  → stage1f (12KB compiler)
    → cc.cyr (bridge compiler, 2009 lines)
      → cc2 (modular compiler, 93KB, 7 modules)
        → cc2_aarch64 (cross-compiler, 91KB)

No Rust. No LLVM. No Python. Just sh + Linux x86_64.
Build: sh bootstrap/bootstrap.sh
```

## Project Structure

```
bootstrap/           29KB seed binary + bootstrap scripts
stage1/
  cc2.cyr            Compiler entry point (includes modules)
  cc2_aarch64.cyr    Cross-compiler entry (swaps arch includes)
  cc.cyr             Bridge compiler (stage1f feature set)
  cc/                Compiler modules: util, emit, jump, lex, parse, fixup
  arch/aarch64/      aarch64 backend: emit, jump, fixup
  lib/               Core stdlib (8 modules)
  lib/agnostik/      Shared AGNOS types (6 modules)
  lib/agnosys/       Syscall bindings (1 module)
  lib/kybernet/      PID 1 init system (7 modules)
  lib/nous/          Dependency resolver (1 module)
  lib/assert.cyr     Test framework
  programs/          52 programs (tools, tests, demos, algorithms)
  stage1f.cyr        Stage 1f compiler source (assembly)
  asm.cyr            Self-hosting assembler source
  test_cc.sh         Compiler test suite (111 tests)
build/               Generated binaries (gitignored except cc2)
kernel/              AGNOS kernel (compile test; source of truth at agnos repo)
docs/                Architecture, roadmap, benchmarks, language guide
```

## Key References

- `docs/cyrius-guide.md` — Complete language reference
- `docs/benchmarks.md` — Binary sizes, compile times, runtime performance
- `docs/development/roadmap.md` — Forward-looking development plan
- `docs/development/completed-phases.md` — Historical phase record
- `CHANGELOG.md` — Source of truth for all changes
- `../vidya/content/compiler_bootstrapping/cyrius_*.toml` — 33 vidya entries

## Development Loop

```
1. RESEARCH    — Check vidya for existing patterns
2. BUILD       — ONE change at a time
3. TEST        — After EACH change:
                 ☐ Basic: 'var x = 42;' → 42
                 ☐ Self-hosting: cc2==cc3 byte-identical
                 ☐ Full suite: sh stage1/test_cc.sh
4. IF BROKEN   — Revert, apply ONE change, test, repeat
                 3 failed attempts = defer and document
5. AUDIT       — Full chain: bootstrap, all suites, self-hosting
6. DOCUMENT    — Update: CHANGELOG, roadmap, benchmarks, vidya
```

## DO NOT

- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to GitHub API only
- Do not add language features without updating vidya
- Do not skip self-hosting verification after compiler changes
- Do not modify parse.cyr arch-specific functions — they live in emit files
- Test after EVERY change, not after the feature is "done"
