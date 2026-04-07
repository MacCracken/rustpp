# Cyrius — Claude Code Instructions

## Project Identity

**Cyrius** — Sovereign, self-hosting systems language. Assembly up.

- **Type**: Self-hosting compiler toolchain
- **License**: GPL-3.0-only
- **Version**: 1.6.7
- **Targets**: x86_64 + aarch64 (cross-compilation)

## Goal

Own the language. Own the toolchain. No crates.io. No external governance. Ark is the package manager. Assembly is the cornerstone. Cyrius writes the AGNOS kernel.

## Current State

- **Compiler**: 136KB (x86_64), 130KB (aarch64), self-hosting, ~11ms self-compile
- **Tests**: 263 total (212 compiler + 51 programs) + 26 aarch64, 0 failures
- **Libraries**: 21 modules, 200+ functions
- **Ecosystem**: 5 crate rewrites (agnostik, agnosys, kybernet, nous, ark)
- **Tools**: cyrb (58KB binary + shell fallback), cyrfmt, cyrlint, cyrdoc, cyrc, ark
- **Kernel**: AGNOS 31KB (in separate repo: github.com/MacCracken/agnos)

## Bootstrap Chain

```
bootstrap/asm (29KB committed binary — root of trust)
  → stage1f (12KB compiler)
    → cc_bridge.cyr (bridge compiler, 2009 lines)
      → cc2 (modular compiler, 136KB, 7 modules)
        → cc2_aarch64 (cross-compiler, 130KB)

No Rust. No LLVM. No Python. Just sh + Linux x86_64.
Build: sh bootstrap/bootstrap.sh
```

## Project Structure

```
bootstrap/           29KB seed binary + stage1f.cyr + asm.cyr
src/
  compiler.cyr       Compiler entry point (includes modules)
  compiler_aarch64.cyr Cross-compiler (swaps arch includes)
  cc_bridge.cyr      Bridge compiler (stage1f feature set)
  cc/                Compiler modules: util, emit, jump, lex, parse, fixup
  arch/aarch64/      aarch64 backend: emit, jump, fixup
lib/                 Standard library (21 modules)
programs/            57 programs (tools, tests, demos, algorithms)
tests/               Test scripts (compiler.sh, programs.sh, assembler.sh)
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
- `../vidya/content/compiler_bootstrapping/cyrius_*.toml` — 90+ vidya entries across 3 files

## Development Loop

```
1. RESEARCH    — Check vidya for existing patterns
2. BUILD       — ONE change at a time
3. TEST        — After EACH change:
                 ☐ Basic: 'var x = 42;' → 42
                 ☐ Self-hosting: cc2==cc3 byte-identical
                 ☐ Full suite: sh tests/compiler.sh
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
