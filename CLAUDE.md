# Cyrius — Claude Code Instructions

## Project Identity

**Cyrius** — Sovereign, self-hosting systems language. Assembly up.

- **Type**: Self-hosting compiler toolchain
- **License**: GPL-3.0-only
- **Version**: 5.5.13

## Goal

Own the language. Own the toolchain. No crates.io. No external governance. Assembly is the cornerstone. Cyrius writes the AGNOS kernel.

## Current State

- **Compiler**: 485816 B (x86_64), aarch64 cross-compiler + native self-host byte-identical on real Pi (v5.3.15+), **`regression.tcyr` 102/102 PASS on aarch64 (v5.3.18)**, Apple Silicon Mach-O target **(self-hosts byte-identically on M-series as of v5.3.13 — 475320 B, Linux cross == Mac round 1 == Mac round 2; v5.5.11 libSystem probe, v5.5.12 compiler-driven `__DATA_CONST + __got + LC_DYLD_INFO_ONLY` bind emission, v5.5.13 first `__got` reroute — `syscall(60, code)` on `_TARGET_MACHO == 2` now tail-calls `libSystem._exit` via `adrp x16 / ldr x16 / br x16` instead of svc+ESYSXLAT, verified exit=42 on `ssh ecb` after codesign)**, **Windows PE32+ target (v5.4.2 structural, v5.4.3 `EEXIT` Win64 + IAT fixup, v5.4.4 `syscall(60)` rerouted, v5.4.5 on-hardware CI gate, v5.4.6 `#pe_import` directive, v5.4.7 `syscall(1)` → `GetStdHandle + WriteFile`, v5.4.8 PE data placement — `hello\n` runs end-to-end on Windows; v5.5.0 foundation: `build/cc5_win` cross-entry + `lib/syscalls_windows.cyr` + `lib/alloc_windows.cyr` + `CYRIUS_TARGET_WIN/LINUX` selectors; v5.5.1 bundles 5 more reroutes — `syscall(0)`→ReadFile, `syscall(2)`→CreateFileW, `syscall(3)`→CloseHandle, `syscall(8)`→SetFilePointerEx, `syscall(9)`→VirtualAlloc; v5.5.2 adds enum-constant sc_num folding so `syscall(SYS_WRITE, ...)` via the `lib/syscalls_windows.cyr` wrappers routes cleanly through the IAT instead of falling through to the 0F 05 Linux encoding; v5.5.3 flips EPOPARG + ESTOREREGPARM to Win64 arg registers (RCX/RDX/R8/R9) under `_TARGET_PE` for cyrius-to-cyrius fn calls with ≤4 args; v5.5.4 completes the call-site Win64 ABI — `ECALLPOPS` shuttles extras via r10/r11/r14/r15 for >4 args, `ECALLCLEAN` unwinds the stack-arg frame, `ESTOREPARM` dispatch boundary flips to pidx<4, `ESTORESTACKPARM` reads [rbp+16+(pidx-4)*8]; v5.5.5 fixes the `&fn` PE VA fixup in `src/backend/x86/fixup.cyr` ftype=3 (3-line PE branch); v5.5.6 adds `lib/fnptr.cyr` Win64 `fncallN` variants + env-var→predefine fix + ECALLPOPS nextra=5 extension; v5.5.7 lifts strict Win64 shadow-space compliance retroactively — every cyrius-to-cyrius call now allocates 32 B shadow, ESTORESTACKPARM shifts to [rbp+16+32+(pidx-4)*8], fnptr.cyr fncallN blocks add shadow + stack args at [rsp+32..]. Closes C-FFI-via-fnptr gap; v5.5.8 swaps main_win.cyr's heap init from SYS_BRK to SYS_MMAP (Windows has no brk); v5.5.9 gates three `/proc/self/*` Linux-ism readbacks behind `#ifdef CYRIUS_TARGET_LINUX` enabling cc5_win.exe to read stdin + compile + write PE on Windows; **v5.5.10 fixes `EWRITE_PE`: was returning WriteFile's BOOL success flag (1) instead of bytes-written. main_win.cyr's write loop did `written += w` where w=1, so olen=1536 loop iterated 1536× writing `olen + (olen-1) + ... + 1 = 1,180,416 B` = the observed output bloat. 5-byte fix (`mov rax, [rsp+0x28]` before frame unwind) mirroring EREAD_PE's existing handling. NATIVE WINDOWS SELF-HOST BYTE-IDENTICAL FIXPOINT achieved: cc5_win.exe's output matches Linux cross-build byte-for-byte (verified md5 match on exit42 and multi-fn add). Cyrius exit42 PE = 1536 B vs Rust -O stripped = 344856 B (225× smaller). check.sh 10/10.**)**, **v5.4.8 also fixes the cc5_aarch64 cross-compile `&local` x86-leak (parse.cyr now arch-dispatches the `&local` emit; yukti `core_smoke` + main CLI run exit-0 on real Pi 4)**, **v5.4.9 ships `_cyrius_init` STB_GLOBAL in `object;` mode (mabda C-launcher unblocked) + sigil 2.8.4**, **v5.4.10 fixes `lib/thread.cyr` post-`clone()` child trampoline + `thread_join` shared/private futex mismatch (majra `cbarrier_arrive_and_wait` unblocked; `tests/tcyr/threads.tcyr` regression coverage)**, self-hosting, IR (40 opcodes, CFG, LASE, DBE), per-arch asm via `#ifdef CYRIUS_ARCH_{X86,AARCH64}` (v5.3.16), multi-width types, sizeof, unions, bitfields, defer (all exit paths), expression-position comparisons, `#assert`, Str/cstr auto-coercion, string interning, syscall arity warnings, `#derive(accessors)`, native multi-return, switch case blocks, `+=`/`-=`/`*=`/`%=`, negative literals, undefined function diagnostic, short-circuit `&&`/`||`, struct initializer syntax, `#regalloc` (multi-register), single-CU DCE, CYML parser
- **Tests**: 65 .tcyr files, 5 .fcyr fuzz harnesses, 14 .bcyr benchmarks, heap audit, self-hosting (two-step)
- **Libraries**: 60 stdlib modules (includes 6 deps: sakshi, patra, sigil, yukti, mabda, sankoch via `cyrius deps`)
- **Build tool**: `cyrius deps` resolves from cyrius.cyml (falls back to cyrius.toml), auto-runs on build/run/test. Namespaced deps: `lib/{depname}_{basename}`. Auto-prepends includes.
- **Ecosystem**: agnostik, agnosys, argonaut, majra, libro (209 tests), sakshi, bsp, cyrius-doom, mabda, kybernet (140 tests), hadara (329 tests), ai-hwaccel (491 tests)

## Consumers

AGNOS kernel, agnostik (58 tests), agnosys (20 modules), argonaut (424 tests), sakshi, sigil (206 tests), libro (240 tests), shravan (audio), cyrius-doom, bsp. All AGNOS ecosystem projects depend on the compiler and stdlib.

## Bootstrap Chain

```
bootstrap/asm (29KB committed binary — root of trust)
  → cyrc (12KB compiler)
    → bridge.cyr (bridge compiler)
      → cc5 (modular compiler + IR, 9 modules)
        → cc5_aarch64 (cross-compiler)

No Rust. No LLVM. No Python. Just sh + Linux x86_64.
Build: sh bootstrap/bootstrap.sh
```

## Quick Start

```bash
sh bootstrap/bootstrap.sh          # bootstrap from seed
cat src/main.cyr | build/cc5 > /tmp/cc5 && chmod +x /tmp/cc5  # build compiler
cat src/main.cyr | /tmp/cc5 > /tmp/cc5b && cmp /tmp/cc5 /tmp/cc5b  # self-hosting verify
sh scripts/check.sh                # full audit
cyrius test                        # run .tcyr suite
cyrius fuzz                        # run .fcyr harnesses
cyrius bench                       # run .bcyr benchmarks
```

## Key Principles

- **Self-hosting is non-negotiable** — cc5==cc5 byte-identical after every compiler change
- **Two-step bootstrap for heap changes** — cc5 compiles cc5b, cc5==cc5b
- **Assembly is the cornerstone** — understand every instruction the compiler emits
- **Test after EVERY change** — not after the feature is "done"
- **ONE change at a time** — never bundle unrelated changes
- **Research before implementation** — vidya entry before code
- **3 failed attempts = defer and document** — don't burn time
- **Bootstrap chain integrity** — never break seed → cyrc → bridge → cc5
- **Version lives in `VERSION` + `--version`, never in binary names** — after the v6.0.0 `cc5` → `cyc` rename, the compiler binary is `cyc` *forever*. No `cc6` at v7.0.0, no `cc7` at v8.0.0, no funny business. The cc3 → cc5 rename at v5.0.0 was the last name-change penalty paid; v6.0.0 fixes the pattern. Anyone tempted to add a version digit to a binary name (compiler, linker, formatter, anything) is reintroducing the bug we explicitly removed. `VERSION` file + binary `--version` output are the only sources of truth.

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

Run a closeout pass before tagging x.Y.0 or x.0.0. Ship as the last patch of the current minor (e.g. 4.2.5 before 4.3.0). **Mechanical checks first, then the judgment-call passes (refactor / code review / cleanup), then the doc sync.**

### Mechanical (automated, fast-fail)
1. **Self-host verify** — cc5 compiles itself byte-identical
2. **Bootstrap closure** — seed → cyrc → asm → cyrc byte-identical
3. **Full check.sh** — all gates green (count grows per minor; record the number)

### Judgment-call passes (where bugs hide)
4. **Heap map audit** — beyond "verify the map matches usage", evaluate:
   - Newly-added regions (are they documented, sized correctly, at stable offsets)
   - Unused / stale regions (any region no code writes to → candidate for removal)
   - Regions that hit caps across the minor (grow before they bite)
   - Opportunity for consolidation (adjacent regions owned by the same subsystem)
5. **Dead code audit** — remove unreachable fns; record the remaining floor in CHANGELOG. The `note: N unreachable fns` output from cc5 is the baseline.
6. **Refactor pass** — review the minor's additions for consolidation. When a minor added multiple `_TARGET_X` branches / new enum variants / new heap regions / parallel codepaths, check whether the dispatch can collapse into a single switch, whether helpers can merge, whether repeated inline asm blocks want a common emitter. Not about rewriting — about spotting the 2-3 obvious consolidations the minor earned.
7. **Code review pass** — walk the minor's diffs end-to-end. Specifically look for: ABI leaks (unguarded x86 encodings on non-x86 paths, SysV leaks on Win64 paths), missed `_TARGET_PE` guards, byte-order typos in hand-rolled encoding hex literals, silently-ignored errors, off-by-one in fixup arithmetic. The places automated tests don't catch.
8. **Cleanup sweep** — stale comments (grep for old version refs, outdated TODOs, references to renamed fns), dead `#ifdef` branches, unused includes, orphaned files in `build/` / `tests/`.

### Compliance / external
9. **Security re-scan** — quick grep for new `sys_system`, `READFILE`, unchecked writes. Full audit every 2-3 minors (last: v5.0.1).
10. **Downstream check** — all `cyrius.cyml` `cyrius` fields across ecosystem repos point to the released tag.

### Docs (silent-rot prevention)
11. **CHANGELOG/roadmap/vidya sync** — all docs reflect current state. Vidya in particular needs explicit refresh per minor (it falls out of sync silently — no compile-time check):
   - **`vidya/content/cyrius/language.toml`** — language usage. Add `[[entries]]` blocks for any new syntax / builtins / directives shipped this minor (e.g. `#regalloc`, `secret var`, `#pe_import`, multi-return, struct initializer). Update existing entries when behavior changed (e.g. `&local` arch dispatch, `_cyrius_init` binding flip). Refresh the `overview` entry's compiler-size + cc-binary-name + version line at every minor.
   - **`vidya/content/cyrius/field_notes/compiler.toml`** — compiler internals + non-obvious gotchas. Add field notes for anything that surprised us this minor (e.g. RBP-after-`clone()` race, `FUTEX_PRIVATE_FLAG` mismatch with kernel `CLONE_CHILD_CLEARTID`, parse.cyr unguarded x86-emit paths that shipped silently, `mov rN, rax` byte-order typos that segfault on Windows). One entry per gotcha; future-claude searching vidya before reimplementing should hit them.
   - **`vidya/content/cyrius/field_notes/language.toml`** — user-facing language gotchas (e.g. no `var` redecl in same scope, no comparisons in fn-call args, parser's `#ifdef`-but-not-`#else`).
   - **`vidya/content/cyrius/implementation.toml`** / **`types.toml`** — bump version refs and any structural changes (heap map, fixup table, fn table caps, IR opcode count, backend modules).
   - **`vidya/content/cyrius/dependencies.toml`** / **`ecosystem.toml`** — refresh when deps bump (sigil 2.8.4 → next, etc.) and when downstream consumer counts / test counts change.
   - **Cross-check the version**: every vidya file mentioning a `cc?` version (`cc3 4.8.5`, `cc5 5.4.x`, etc.) should match the current `VERSION` file. `version-bump.sh` doesn't touch vidya — that's manual at closeout.

Order matters: mechanical checks fail-fast (if self-host breaks, stop). Judgment passes uncover scope for a follow-up patch if needed (landing the refactor during closeout is fine IF it stays byte-identical; otherwise defer to the next minor's first patch). Doc sync is last so it reflects whatever the judgment passes changed.

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
                 ☐ Self-hosting: cc5==cc5 byte-identical
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
  common/            util.cyr, ir.cyr
lib/                 Standard library (54 modules + 6 deps)
programs/            59 programs (tools, tests, demos, algorithms)
tests/               Test suites (tcyr/*.tcyr, heapmap.sh)
benches/             Benchmarks (*.bcyr)
fuzz/                Fuzz harnesses (*.fcyr)
build/               Generated binaries (gitignored except cc5)
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
- Do not remove build/cc5-native-aarch64 — ARM binary needed for self-hosting on ARM hardware (generated by `cyrius pulsar`)
- **v5.0.0 is the recommended minimum** — cc5 IR, cyrius.cyml manifest, patra 1.0.0, sankoch 1.2.0. v5.0.1+ adds security hardening (alloc/vec overflow guards). v5.1.0+ adds macOS Mach-O support.
