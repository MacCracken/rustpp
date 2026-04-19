# v5.3.13 Handoff — Apple Silicon cc5 Self-Host Debug

**Written at the close of the v5.3.13 debugging session, 2026-04-18. For
the agent / engineer who picks up the Mac self-host work.**

Assumes no knowledge of the prior session. Everything needed to resume
is here or linked.

## Where we are

**v5.3.12 is tagged and released.** v5.3.13 work is staged on `main` but
NOT yet tagged — the scaffold is in the tree and compiles cleanly on
Linux, but the produced `cc5_macho` binary does not yet self-host on
Apple Silicon. Every "was a compiler bug" has been fixed across the
session; the remaining obstacle is a runtime loop inside the compiler's
pass 1 scan phase that manifests only when running on macOS.

### What v5.3.13 already ships (staged)

- **`src/main_aarch64_macho.cyr`** — new compiler entry point for
  Apple Silicon self-host. Differs from `main_aarch64.cyr` only in
  the heap-init syscall (`mmap` with `MAP_PRIVATE | MAP_ANON = 0x1002`
  instead of `brk`) and a forced `_TARGET_MACHO = 2` at startup.
- **`scripts/mac-selfhost.sh`** — validation script for the Mac side.
  Strips `com.apple.provenance` xattrs, ad-hoc signs, runs
  `cc5_macho < main_aarch64_macho.cyr > cc5_macho_b` under a 30s
  watchdog, then cmps for byte-identity.
- **`scripts/mac-diagnose.sh`** — SIGILL / crash triage script. Dumps
  `file`, `otool -h`, `codesign`, direct run exit code, and reads any
  `~/Library/Logs/DiagnosticReports/cc5_macho-*.ips`. Does NOT use
  `lldb` (lldb hangs the terminal on M-series first launch — avoid).
- **`docs/development/issues/2026-04-18-cc5-macho-sigill.md`** —
  initial triage output from when cc5_macho was SIGILL'ing on entry
  (before the x86-backend gate fix). Preserved for the record.
- **`EMITMACHO_OBJ` removed** — dead stub function deleted from
  `src/backend/macho/emit.cyr`.
- **x86 backend Mach-O ARM gate** in `src/backend/x86/fixup.cyr`:
  compiling with `CYRIUS_MACHO_ARM=1 ./build/cc5` (x86 backend) now
  errors at emit time with a clear message ("use `./build/cc5_aarch64`,
  not `./build/cc5`"). Prevents the first bug we hit.
- **BSD carry-flag error handling** in
  `src/backend/aarch64/emit.cyr:ESYSCALL` — every `svc #0x80` is now
  followed by `csneg x0, x0, x0, cc` (encoding `0xDA803400`). On BSD
  syscall error the kernel sets the carry flag and returns `errno` as
  a small positive in `x0`; the `csneg` negates x0 when carry is set,
  producing `-errno` to match Linux convention. Higher-level code
  checking `if (result < 0) { ... }` now works identically on both
  platforms.
- **Cross-platform mmap flag fallback** in
  `src/frontend/lex.cyr:PP_IFDEF_PASS` — was hardcoded to Linux
  `MAP_PRIVATE | MAP_ANONYMOUS = 0x22`. Now attempts 0x22 first,
  falls back to macOS `MAP_PRIVATE | MAP_ANON = 0x1002` if the first
  returns negative. Single code path works on both platforms.

### What's NOT yet working

**cc5_macho hangs in pass 1 scan loop on Apple Silicon.**

Progress markers instrumented into `src/main_aarch64_macho.cyr` tell us:

| Marker | Meaning | Status |
|--------|---------|--------|
| `a` | mmap heap init | ✅ |
| `b` | stdin read complete | ✅ |
| `1` | SBL | ✅ |
| `2` | `_init_cyrius_lib` | ✅ |
| `p`→`t` | PREPROCESS sub-passes | ✅ |
| `3` | PREPROCESS done | ✅ |
| `4` | LEX done | ✅ |
| `5` | EJMP0 done | ✅ |
| `c` | Pass 1 done | ❌ **never printed** |
| `d` | Pass 2 done | ❌ |
| `e` | FIXUP done | ❌ |
| `f` | EMITMACHO_ARM64 done | ❌ |

Last run (watchdog-killed at 30s) stderr: `ab12pqrst345c` — we reached
the `c` marker text buffer but the watchdog fired mid-write, or pass 1
emitted `c` as part of an error message. Actually re-reading: the `c`
in that output is the START of `cwarning:...` — it's the compile
WARNING that says "syscall arity mismatch" at source line 95 of the
preprocessed buffer. Pass 1 itself may actually have completed. The
hang is somewhere later or the error handler itself loops.

**Open question**: does pass 1 really hang, or does the warn/error path
hang? Needs one more marker cycle or an lldb backtrace to tell.

## Reproduction recipe

### On Linux (to rebuild cc5_macho)
```
cd /home/macro/Repos/cyrius
cat src/main_aarch64_macho.cyr | CYRIUS_MACHO_ARM=1 build/cc5_aarch64 > /tmp/cc5_macho_vN
```
Result: ~459 KB arm64 Mach-O executable with `NOUNDEFS|DYLDLINK|TWOLEVEL|PIE`.

### On Mac (`macro@archaemenid.local`)
```
# Pull binary from Linux
scp macro@archaemenid.local:/tmp/cc5_macho_vN ~/cyrius/cc5_macho

# From a checkout of the cyrius repo (includes must resolve relative to cwd)
cd ~/cyrius
./scripts/mac-selfhost.sh ./cc5_macho src/main_aarch64_macho.cyr
cat cc5_macho_b.err
```
Expected on success: `cc5_macho_b.err` contains `abcdef` (with sub-
markers `ab12pqrst345cdef`). On hang: watchdog fires at 30s.

### Required on Mac
- Cyrius repo checkout with matching source tree (includes resolve
  relative to cwd: `src/common/util.cyr`, `src/backend/aarch64/*.cyr`,
  etc.)
- `cc5_macho` ad-hoc signed (`mac-selfhost.sh` does this — strips
  xattrs + signs)
- macOS 26.4.1 Apple Silicon hardware (this was the test environment)

## Bugs fixed this session

Each one would have bitten anyone attempting Mach-O ARM self-host; all
four are now committed.

### 1. `cc5` (x86 backend) wrapping x86 code in arm64 Mach-O header

**Symptom**: `CYRIUS_MACHO_ARM=1 ./build/cc5 < source > bin` produced
a "Mach-O 64-bit arm64 executable" per `file`, but SIGILL'd on first
instruction on Apple Silicon. Crash dump showed `atPC` was x86_64
bytes (`55 48 89 E5 ...` = `push rbp; mov rbp, rsp; ...`).

**Root cause**: x86/fixup.cyr routes `_TARGET_MACHO == 2` to
`EMITMACHO_ARM64` regardless of which backend emitted the code. x86
backend's code is x86 machine instructions; wrapping them in an
arm64 Mach-O header produces a binary the kernel gladly launches
but cannot execute.

**Fix**: `src/backend/x86/fixup.cyr:EMITELF` — added a parse-time
error when `_TARGET_MACHO == 2` under the x86 backend, pointing the
user at `./build/cc5_aarch64`.

### 2. BSD raw-SVC error return convention

**Symptom**: `cc5_macho` hung indefinitely in pass 1 after
`PREPROCESS`. No output, no stderr, no crash.

**Root cause**: BSD raw syscalls on macOS signal errors via the
CPU carry flag — on error, `carry=1` and `x0` contains `errno` as a
small positive (e.g. `2` for ENOENT, `9` for EBADF). Cyrius's
higher-level code checks `if (fd < 0) { ... }`, which on Linux works
because Linux returns `-errno` in x0 on error. On macOS the small
positive looked like a valid fd, so `read(fd=2, ...)` ran against
stderr and blocked.

**Fix**: `src/backend/aarch64/emit.cyr:ESYSCALL` — for
`_TARGET_MACHO == 2`, emit `csneg x0, x0, x0, cc` (0xDA803400) after
`svc #0x80`. On carry-set (error) x0 is negated → `-errno`, matching
Linux. `if (fd < 0)` now fires correctly.

### 3. mmap flag portability in `PP_IFDEF_PASS`

**Symptom**: After the BSD-carry fix, cc5_macho SEGV'd inside
`PP_IFDEF_PASS` with markers `ab12pqr` (stopped before `s`).

**Root cause**: `lex.cyr:PP_IFDEF_PASS` mmap'd its scratch buffer
with `flags = 34` (`MAP_PRIVATE | MAP_ANONYMOUS` on Linux). On
macOS `0x20` isn't `MAP_ANON` (that's `0x1000`), so mmap needed a
valid fd but got `-1` → `EINVAL`. With the carry fix, `tmp` was
small negative; `store8(tmp + ci, ...)` → SEGV.

**Fix**: try `0x22` first, fall back to `0x1002` if the first call
returns negative. Single code path for both hosts.

### 4. (Meta) include paths must resolve on the Mac side

**Symptom**: After mmap fix, pass 1 emitted `warning:95: syscall
arity mismatch` and `error:148: unexpected '='`.

**Root cause**: `main_aarch64_macho.cyr` has `include "src/common/util.cyr"`
etc. When the Mac-side cwd didn't contain the `src/` tree, PREPROCESS
left the literal `include "..."` directives in the source, causing
parse errors.

**Fix**: none — this is expected. Mac user must run from a checkout
of the repo where include paths resolve. Documented in mac-selfhost.sh.

## Remaining bug — pass 1 scan loop

After fixes 1-4, markers sit at `ab12pqrst345c`. Either pass 1 hangs
inside its `while (scan == 1) { ... }` loop, or pass 1 emits a warning
(`syscall arity mismatch` was observed) and then the warning/error
handler itself hangs. Unclear which without more data.

### Suspects

1. **Warning/error handler writes to stderr via a syscall that hangs** —
   BSD write(2) behavior with a corrupt fd + our carry fix should
   work, but worth verifying. Unlikely: `b` marker proved stderr
   writes work.
2. **Token stream corruption** — something LEX emitted on Mac that
   parse doesn't expect, causing an infinite PEEKT/STI cycle that
   never advances. Would require comparing the token stream between
   Linux and Mac runs. Tedious but decisive.
3. **Pass 1 looping on a specific token type** — a case in the
   `while (scan == 1) { ... }` dispatch that branches without
   calling `STI(S, GTI(S) + 1)` on Mac because some condition
   evaluates differently. Would be an arithmetic or endianness bug.

### Recommended next steps (in order)

**Step 1 — lldb backtrace of the hung process.** This is the fastest
path. On the Mac:
```
./cc5_macho < src/main_aarch64_macho.cyr > /tmp/out 2> /tmp/err &
pid=$!
sleep 5
lldb -p $pid -b -o "process interrupt" -o "register read pc x0 x1 x2" \
     -o "disassemble --pc --count 16" -o "bt 10" -o "detach" -o "quit"
kill $pid
```
**The pc + backtrace tells us the loop location immediately.** If the
symbol is somewhere in pass 1's PEEKT/STI chain, case 2 or 3 above. If
it's inside `PARSE_STRUCT_DEF` or similar recursive descent, that
function loops on a specific token.

**Step 2 — add a tick marker inside the scan loop that prints the
current token type every iteration.** Gets rebuilt on Linux, pushed to
Mac, run with stderr captured to file. The repeating pattern tells us
which token type the loop spins on.

**Step 3 — if pass 1 really has completed and the hang is in a warn
or error path**: instrument `WARN` / `ERR_MSG` in
`src/frontend/parse.cyr` with entry markers. If the last marker seen
is one of those, the parse code reached an error path and its write
to stderr hangs.

## Infrastructure / environment notes

- **Mac hostname**: `archaemenid.local` (from the Linux side). Username
  on Mac is `macro`.
- **Linux hostname** (from Mac): `archaemenid.local` also — Tailscale
  or local DNS resolves the same name to different machines.
- **Cyrius repo on Linux**: `/home/macro/Repos/cyrius/`.
- **Cyrius repo on Mac**: `/Users/macro/cyrius/` (user's choice; the
  selfhost script doesn't care as long as `src/` is reachable).
- **Mac OS version**: macOS 26.4.1 (Tahoe). arm64. Apple Silicon.
  Model Mac17,8.
- **macOS 26 quirk**: `com.apple.provenance` xattr + persistent
  quarantine database silently blocks non-notarised binaries at
  `_dyld_start`. `xattr -c && codesign --force --sign -` strips both.
  `mac-selfhost.sh` does this automatically.
- **DO NOT use `lldb process launch` without a timeout or guarded**
  — first-invocation on M-series can hang the terminal completely.
  Use attach-to-running-pid instead, or kill in another terminal.

## Session chronology (abbreviated)

1. Created `main_aarch64_macho.cyr`, `EMITMACHO_OBJ` removed, v5.3.13
   staged.
2. Attempt 1: built cc5_macho with wrong compiler (`build/cc5` not
   `build/cc5_aarch64`), got x86-in-arm64-wrapper SIGILL. Fixed in
   x86/fixup.cyr gate.
3. Attempt 2: hung silently at `_dyld_start` (markers `ab`). Thought
   it was macOS 26 quarantine (verified via openai/codex#17447);
   added `xattr -c` to mac-selfhost.sh. Wasn't the real fix but is
   still good hygiene.
4. Attempt 3: instrumented main with progress markers, added BSD
   carry-flag fix in ESYSCALL, got SEGV in PREPROCESS (markers
   `ab12`).
5. Attempt 4: narrowed to PP_IFDEF_PASS via sub-markers (markers
   `ab12pqr`), found mmap flag mismatch, added fallback.
6. Attempt 5: got past preprocess + lex + EJMP0 into pass 1
   (markers `ab12pqrst345c`), watchdog fired at 30s. Current state.

## Files touched

- `src/main_aarch64_macho.cyr` (new — has progress markers; **remove
  markers before tagging v5.3.13**)
- `src/main_aarch64.cyr` — unchanged
- `src/main.cyr` — heap map updated to free 0xD8000
- `src/backend/macho/emit.cyr` — EMITMACHO_OBJ removed, stale Phase 3
  comment replaced
- `src/backend/aarch64/emit.cyr` — ESYSCALL emits csneg after svc for
  Mach-O ARM; `_AARCH64_BACKEND = 1` marker added (unused, safe)
- `src/backend/x86/fixup.cyr` — Mach-O ARM gate in EMITELF dispatch
- `src/frontend/lex.cyr` — PP_IFDEF_PASS mmap flag fallback; progress
  markers in PREPROCESS sub-passes (**remove before tagging**)
- `src/frontend/parse.cyr` — BSD SVC whitelist gate (v5.3.12)
- `scripts/mac-selfhost.sh` (new)
- `scripts/mac-diagnose.sh` (new)
- `scripts/macos-arm64-README.md` (from v5.3.12)
- `.github/workflows/release.yml` — build-macos-arm64 job honest
- `CHANGELOG.md`, `VERSION`, `CLAUDE.md`, `docs/development/roadmap.md`
- `docs/development/issues/2026-04-18-cc5-macho-sigill.md`

## Cleanup before tagging v5.3.13

1. **Remove progress markers from `src/main_aarch64_macho.cyr`** (lines
   containing `syscall(SYS_WRITE, 2, "..."", 1)` — search for the
   `# PROGRESS MARKER` comment block).
2. **Remove progress markers from `src/frontend/lex.cyr:PREPROCESS`**
   (the `p`/`q`/`r`/`s`/`t` writes inside PREPROCESS).
3. **Verify self-host on Linux still byte-identical** after marker
   removal.
4. **Verify `cyrfmt`/`cyrlint`/`cyrdoc` still produce identical Linux
   output** — marker writes in `main_aarch64_macho.cyr` don't affect
   them, but the BSD-carry-flag change in `aarch64/emit.cyr:ESYSCALL`
   could (only under `_TARGET_MACHO == 2`; should be fine).
5. Once `cc5_macho` self-hosts on Mac, **run the two-round test via
   `mac-selfhost.sh`** and cmp for byte-identity. That closes the
   loop and v5.3.13 can ship with a real validation claim.

## What v5.3.14 should NOT pick up

Keep v5.3.14's nice-to-haves-roundup scope separate:
- NSS/PAM end-to-end (dynlib follow-up)
- libro layout corruption
- aarch64 native FIXUP
- `fncall0` + `println` audit
- `dynlib_init` safety
- `distlib ""` validation

The pass-1 hang is v5.3.13-exclusive work. Once resolved, tag v5.3.13
and move on to v5.3.14.
