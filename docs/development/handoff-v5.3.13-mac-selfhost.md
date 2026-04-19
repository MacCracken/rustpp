# v5.3.13 Handoff — Apple Silicon cc5 Self-Host Debug

**Written at the close of the v5.3.13 debugging session, 2026-04-18. For
the agent / engineer who picks up the Mac self-host work.**

Assumes no knowledge of the prior session. Everything needed to resume
is here or linked.

## Where we are

**v5.3.13 self-hosts byte-identically on Apple Silicon as of 2026-04-18.**
Validated end-to-end on macOS 26.4.1 (Ecbatana.local):

- Linux cross-compile (cc5_aarch64 → cc5_macho): 475320 bytes,
  md5 `18301fb3c5d5004c21e84726f4aafab7`
- Mac self-compile round 1: same 475320 bytes, same md5
- Mac self-compile round 2 (Mac-built compiler → its own output): same
- Full progress-marker sequence `ab12pqrst345cdef` prints on every run
- Compile time on M-series: < 1s

**v5.3.12 is tagged and released.** v5.3.13 is staged on `main` and
ready for closeout + tag. Still TODO before tag: remove progress
markers (see cleanup list below), rerun Linux self-host byte-identity
after marker removal, and update CHANGELOG/roadmap. Every "was a compiler bug" has been fixed across the
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

## Root cause found (2026-04-18, local Mac session) — BUG #5: aarch64 LDUR sign-bit + 9-bit imm wrap

The `c` marker does get printed. The hang is in **pass 2** (LASE
optimisation), inside `parse.cyr:3346-3376`:

```cyr
DSE_PASS(S, fn_start);
var lase_cp = GCP(S);
var lase_i = fn_start;
var lase_count = 0;
while (lase_i + 14 <= lase_cp) {
    if (load8(S + 0x54A000 + lase_i) == 0x48) { ... }
    lase_i += 1;
}
```

lldb attach on the hung process showed PC cycling in a 116-byte band
with **fp pinned** (i.e. tight loop in a single frame, not recursion).
Reading the locals directly from the stack: `lase_i ≈ 0x10081d1d0`,
`lase_cp ≈ 0x105cba0e0` — both absolute pointers, difference ~88 MB.
The loop runs ~88 million iterations before terminating; the 30s
watchdog fires first.

### Why lase_i/lase_cp hold absolute pointers, not small offsets

PARSE_FN_DEF has so many locals that by the time `lase_cp`, `lase_i`,
`lase_count` are declared, their local index is ≥ 32. In
`src/backend/aarch64/emit.cyr`, `EFLLOAD`/`EFLSTORE` (and the width-
aware variants, plus `ESTOREREGPARM`/`ESTORESTACKPARM`) all computed:

```cyr
var disp = 0 - ((idx + 1) * 8);
var off9 = disp & 0x1FF;
EW(S, <base> | (off9 << 12));
```

with **no bounds check**. For idx ≥ 32, disp < -256, which is outside
the LDUR/STUR signed 9-bit imm9 range (-256..+255). `disp & 0x1FF`
silently wraps.

Two compounding problems:
1. **Typo in EFLLOAD's base**: `0xF85003A0` should be `0xF84003A0`. The
   `5` (vs. `4`) sets bit 20 of the instruction — which is the sign bit
   of imm9. EFLLOAD's base therefore hardcoded "negative" into every
   load. EFLSTORE's base correctly had `0xF80003A0` (bit 20 clear).
2. **No range check**. Even with the typo fixed, offsets beyond -256
   still wrap the imm9 field with no guard.

For `lase_i` (idx 36, disp = -296):
- `off9 = -296 & 0x1FF = 0xD8`
- EFLSTORE (bit 20 = 0) encodes `stur x0, [fp + 216]` (+0xD8 — above fp,
  in *caller's frame*).
- EFLLOAD (bit 20 = 1) encodes `ldur x0, [fp - 40]` (-0x28 — a
  completely different, low-idx local that happens to hold a stable
  value).

Store and load for the same variable diverge. The loop test keeps
reading the same stable value and the increment never reaches the
condition's RHS. Loop spins ~88 M iterations until watchdog.

### Fix applied (2026-04-18)

`src/backend/aarch64/emit.cyr` — six functions patched:
- `EFLLOAD`, `EFLSTORE`
- `EFLLOAD_W`, `EFLSTORE_W`
- `ESTOREREGPARM`, `ESTORESTACKPARM`

Each now checks `if (disp >= 0 - 256) { <fast path, imm9 as before> }`
and falls through to an out-of-range path that computes the address
into a scratch register first:

```
movz x9, #abs_disp
sub  x9, x29, x9
ldr/str Xt, [x9]
```

`ESTORESTACKPARM` uses x10 for the address since x9 already holds the
loaded caller-stack value (`str x9, [x10]`).

EFLLOAD's typo is also corrected: `0xF85003A0` → `0xF84003A0`.

Helper `_EFP_ADDR_X9` centralises the 2-instruction address compute.
MOVZ encodes a 16-bit imm; |disp| fits in 16 bits until a function has
>= 8192 locals (implausible).

### Cross-platform impact

The x86_64 backend is unaffected — disp32 has plenty of range.
The Linux aarch64 cross-compiler path (`build/cc5_aarch64` emitting
`main_aarch64.cyr` for Linux aarch64) has the same latent bug but it
would only manifest on a native aarch64 Linux host running the
compiler itself; cross-builds emitting output that's never executed
by the buggy compiler won't surface it.

### Remaining work before tagging v5.3.13

1. **Rebuild `cc5_macho` from the fixed source.** Requires running
   `CYRIUS_MACHO_ARM=1 build/cc5_aarch64 < src/main_aarch64_macho.cyr
   > cc5_macho_new` on a Linux x86_64 host. (Mac has no working
   cross-compiler locally yet — Docker/Lima would close that gap.)
2. **Validate two-round self-host on Mac** via `mac-selfhost.sh`.
3. **Remove progress markers** from `main_aarch64_macho.cyr` and
   `lex.cyr:PREPROCESS` per the cleanup checklist below.
4. **Re-verify Linux self-host** byte-identity after marker removal
   and emit.cyr changes.

## Infrastructure / environment notes

- **Mac hostname**: as of 2026-04-18 the repo lives on `Ecbatana.local`
  (Darwin 25.4.0, macOS 26.4.1, arm64). Prior sessions used
  `archaemenid.local`.
- **Cyrius repo on Linux**: `/home/macro/Repos/cyrius/`.
- **Cyrius repo on Mac**: `/Users/macro/Repos/cyrius/` (checkout is
  full — includes resolve relative to cwd).
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
   (markers `ab12pqrst345c`), watchdog fired at 30s.
7. 2026-04-18 (local Mac session): lldb attach on the hung process
   pinned the spin inside LASE (`parse.cyr:3351`). Read locals
   directly — `lase_i`/`lase_cp` held absolute pointers ~88 MB apart.
   Traced the ~88 M-iteration loop to the aarch64 emit.cyr imm9
   wrap + EFLLOAD typo. Fix applied; waiting on a Linux rebuild of
   `cc5_macho` to validate.

## Files touched

- `src/main_aarch64_macho.cyr` (new). Progress markers (`a`/`b`/`1`–
  `5`/`c`–`f`) were present during debug; all removed 2026-04-18.
- `src/main_aarch64.cyr` — unchanged
- `src/main.cyr` — heap map updated to free 0xD8000
- `src/backend/macho/emit.cyr` — EMITMACHO_OBJ removed, stale Phase 3
  comment replaced
- `src/backend/aarch64/emit.cyr` — ESYSCALL emits csneg after svc for
  Mach-O ARM; `_AARCH64_BACKEND = 1` marker added (unused, safe);
  **2026-04-18 imm9 wrap fix**: EFLLOAD/EFLSTORE, EFLLOAD_W/EFLSTORE_W,
  ESTOREREGPARM/ESTORESTACKPARM now range-guard disp and fall through
  to a `movz+sub+ldr/str` sequence for locals at idx ≥ 32; also fixes
  EFLLOAD base typo `0xF85003A0` → `0xF84003A0`. New helper
  `_EFP_ADDR_X9` centralises the out-of-range address compute.
- `src/backend/x86/fixup.cyr` — Mach-O ARM gate in EMITELF dispatch
- `src/frontend/lex.cyr` — PP_IFDEF_PASS mmap flag fallback. Progress
  markers were added during debug and removed 2026-04-18 after the
  self-host closed.
- `src/frontend/parse.cyr` — BSD SVC whitelist gate (v5.3.12)
- `scripts/mac-selfhost.sh` (new)
- `scripts/mac-diagnose.sh` (new)
- `scripts/macos-arm64-README.md` (from v5.3.12)
- `.github/workflows/release.yml` — build-macos-arm64 job honest
- `CHANGELOG.md`, `VERSION`, `CLAUDE.md`, `docs/development/roadmap.md`
- `docs/development/issues/2026-04-18-cc5-macho-sigill.md`

## Closeout (completed 2026-04-18)

1. ✅ Progress markers removed from `src/main_aarch64_macho.cyr` and
   `src/frontend/lex.cyr:PREPROCESS`.
2. ✅ Linux self-host byte-identical after marker removal (432928 B,
   cc5 → cc5_new → cc5_new2 all match).
3. ✅ `cc5_aarch64` cross-compiler rebuilt from new source
   (331896 B, regression-free).
4. ✅ Mac self-host: Linux cross-compile == Mac round 1 == Mac
   round 2 (475320 B, md5 stable). Full `mac-selfhost.sh` PASS.
5. ✅ `mac-selfhost.sh` updated to compare unsigned outputs (ad-hoc
   codesign is non-deterministic — signed cmp always false-failed).

## What v5.3.14 should NOT pick up

Keep v5.3.14's nice-to-haves-roundup scope separate:
- NSS/PAM end-to-end (dynlib follow-up)
- libro layout corruption
- aarch64 native FIXUP
- `fncall0` + `println` audit
- `dynlib_init` safety
- `distlib ""` validation

Apple Silicon self-host is v5.3.13-exclusive. With it closed, tag
v5.3.13 and move on to v5.3.14.
