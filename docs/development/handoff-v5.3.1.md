# v5.3.1 Handoff — Apple Silicon: Strings + Globals

**Written at the close of v5.3.0, 2026-04-18. For whoever picks up v5.3.1.**

This document assumes you have not read the three prior sessions.
It is self-contained. Everything you need to continue the Apple Silicon
work is here or linked.

## Where we are

v5.3.0 shipped 2026-04-18. First Cyrius-compiled arm64 Mach-O binaries
running on macOS 26.4.1 Apple Silicon. The scope is **syscall-only
programs**: anything that uses only `syscall(...)` calls compiles,
codesigns, and runs on Apple Silicon.

The foundation is solid:

- `EMITMACHO_ARM64` in `src/backend/macho/emit.cyr` emits the full
  15-load-command Mach-O structure validated against clang's output
  for a trivial arm64 binary.
- `src/backend/aarch64/emit.cyr:ESYSCALL/ESYSXLAT/EEXIT` all branch
  on `_TARGET_MACHO == 2` and emit BSD-style syscalls (`svc #0x80`,
  x16 register, BSD numbers).
- `src/main_aarch64.cyr` reads `CYRIUS_MACHO_ARM=1` env var.

What does not work yet:

- String literals (`"hello"`) — the program will emit code that
  references a string address, but the address encoding is wrong
  under PIE.
- Global variables — same PIE problem plus no `__DATA` segment emitted.
- Function-address references — same.

## Why PIE breaks our existing addressing

On Linux, the aarch64 FIXUP pass in `src/backend/aarch64/fixup.cyr`
patches 3-instruction **MOVZ/MOVK/MOVK** sequences with 48-bit
absolute virtual addresses:

```
movz xN, #low16            ; bits 15:0
movk xN, #mid16, lsl 16    ; bits 31:16
movk xN, #hi16, lsl 32     ; bits 47:32
```

This works because Linux aarch64 binaries are loaded at a fixed
vaddr (or static-linked with known layout).

On Apple Silicon, `MH_PIE` is mandatory. The kernel applies an ASLR
slide at exec, so the "absolute vaddr" we baked into the MOVZ/MOVK
sequence is wrong after load. The binary will load fine — dyld does
not know those instructions reference code addresses — but any
dereference of the computed pointer will hit unmapped memory and
segfault (or worse, hit someone else's memory).

The arm64 standard approach is **PC-relative addressing**:

```
adrp xN, #page_of_target     ; xN = (pc & ~0xFFF) + (page_diff << 12)
add  xN, xN, #offset_in_page ; xN += low 12 bits of target
```

Or for an indirection through a pointer table (like clang's `__got`):

```
adrp xN, #page_of_got_slot
ldr  xN, [xN, #offset_in_page]  ; load the pointer value
```

Both are 2 instructions = 8 bytes, vs the current 3 instructions =
12 bytes. That shifts all subsequent code offsets by 4 bytes per
fixup. Not a deal-breaker, but the fixup pass needs to know when
the shorter encoding is in play.

## v5.3.1 work plan

### Phase 1 — scaffold hardening (half session)

1. Pick a few representative Cyrius programs and compile them to
   Linux aarch64 + x86_64 to baseline: how many MOVZ/MOVK sequences
   per program, how many string refs, how many global vars.
2. Audit `aarch64/fixup.cyr:FIXUP_MOV`. Understand every caller site:
   - `ftype == 1`: function address fixup
   - `ftype == 0` (fallthrough): variable / string address fixup
   The fixup table already tags entries by type.
3. Write a probe: `programs/macho_probe_arm_adrp.cyr` that hand-emits
   a Mach-O arm64 binary using adrp+add for a string reference,
   writes "hello\n" via `_write`, returns 42. Validate on hardware
   that adrp addressing works (should, since that is what clang emits).

### Phase 2 — encoder helpers (one session)

1. Add `EADRP(S, reg, target_coff)` to `src/backend/aarch64/emit.cyr`.
   Emits `adrp xN, <placeholder>` (0x90000000 | reg). Target is
   patched by FIXUP to `(target_page - pc_page) >> 12`.
2. Add `EADD_IMM12(S, reg_dst, reg_src, imm12_coff)`. Emits
   `add xdst, xsrc, #<placeholder>`. Patched by FIXUP to
   `target_vaddr & 0xFFF`.
3. Add fixup kinds `FIXUP_ADRP` and `FIXUP_ADD_LO12`. Record each
   half of the addressing pair separately. Both reference the same
   target; at patch time compute page_diff and low12 independently.
4. Do NOT remove the existing MOVZ/MOVK path. It stays for Linux
   targets. Only swap on `_TARGET_MACHO == 2`.

### Phase 3 — emit.cyr Mach-O arm64 extensions (one session)

1. `EMITMACHO_ARM64` gains a `__cstring` section inside `__TEXT`:
   - `addr = TEXT_VMADDR + CSTRING_OFF` (computed; place after code)
   - `size = spos` (string data size)
   - `flags = 0x00000002` (S_CSTRING_LITERALS)
   - Copy `S + 0x14A000` into the output at CSTRING_OFF.
2. If `totvar > 0`, emit a third segment `__DATA`:
   - `vmaddr = TEXT_VMADDR + 0x8000` (page 2; __LINKEDIT moves to page 3)
   - `vmsize = page-aligned(totvar)`
   - `initprot = 3` (R|W)
   - One section `__data`, `addr = vmaddr`, `size = totvar`, zero-init.
3. Remove the "totvar > 0" and "spos > 0" early errors now that the
   segments exist.
4. Adjust `__LINKEDIT` fileoff/vmaddr to accommodate the new segment.

### Phase 4 — codegen swap (one session)

Make the parser/emit route variable and string references through the
new adrp+add pair when `_TARGET_MACHO == 2`.

1. Find callers of `FIXUP_MOV` (or wherever MOVZ/MOVK gets emitted for
   references). They are in `aarch64/emit.cyr` — functions that emit
   variable loads and string literal pushes.
2. Gate each: if `_TARGET_MACHO == 2`, emit `EADRP + EADD_IMM12`
   pair (2 instructions = 8 bytes) instead of MOVZ/MOVK triple
   (3 instructions = 12 bytes). Record a paired fixup.
3. The fixup pass then patches both halves: page_diff for the ADRP,
   low 12 bits for the ADD.

### Phase 5 — test + closeout (half session)

1. Write a target Cyrius program: `println("hello");` using the
   standard `lib/fmt.cyr` path. Compile with CYRIUS_MACHO_ARM=1,
   sign, run on Mac. Expect: "hello\n" printed, clean exit.
2. Re-run `cyrius bench` vs v5.3.0 baseline; confirm no regression.
3. Self-host verify. All tests pass.
4. Closeout: CHANGELOG entry, roadmap table "Strings + Globals Done",
   Platform Status row update, version-bump.sh 5.3.1.

## Known-good references

- **Stage 3 probe** — `programs/macho_probe_arm_hello.cyr` is the
  byte-exact reference for how clang emits hello-world on arm64
  macOS. When in doubt about adrp+add encoding, check this file.
  It uses `adrp x1, 0; add x1, x1, #0x4a0` for the cstring address.
- **v5.3.0 design doc** — `docs/development/v5.3.0-apple-silicon-emitter.md`
  has the full reasoning for the Phase 1 research pass. Still
  accurate for the architecture; just the scope expands.
- **Project memory** — `/home/macro/.claude/projects/-home-macro-Repos-cyrius/memory/project_apple_silicon_blockers.md`
  has the cumulative state including what's still open.

## Test environment

- Linux dev machine with cc5 (x86_64 host).
- MacBook Pro, Apple Silicon, macOS 26.4.1. ssh reachable as `<mbp>`
  (typically via Tailscale hostname — check user's `~/.ssh/config`).
- Round trip pattern:
  ```
  cat src/main_aarch64.cyr | build/cc5 > build/cc5_aarch64 && chmod +x build/cc5_aarch64
  echo '<test program>' > /tmp/t.cyr
  CYRIUS_MACHO_ARM=1 build/cc5_aarch64 < /tmp/t.cyr > /tmp/t.macho
  scp /tmp/t.macho <mbp>:~
  ssh <mbp> 'chmod +x t.macho && codesign -s - --force t.macho && ./t.macho; echo exit=$?'
  ```

## Watchpoints

- **Self-host byte-identity** — every change to aarch64/emit.cyr or
  the fixup pass risks breaking `cmp cc5 cc5b`. Validate with
  `cat src/main.cyr | build/cc5 > /tmp/a && cat src/main.cyr |
  /tmp/a > /tmp/b && cmp /tmp/a /tmp/b` after every file edit.
- **Two-step bootstrap for heap changes** — if you need to move any
  compiler state (new regions for adrp fixup tracking, etc.),
  the heap map in `src/main.cyr` must change, and the compiler
  must compile itself compiled-by-itself. Stage through cc5 →
  cc5b → cc5c byte-identically.
- **PIE slide testing** — Apple Silicon does not always apply a
  slide in every exec. You may see a program appear to work under
  the broken MOVZ/MOVK encoding if the slide is zero. Test multiple
  runs; vary the binary slightly (add padding) to force slide.
- **Raw SVC whitelist** — v5.3.0 relies on `_exit` and `_write`
  being accepted as raw BSD syscalls. Unverified on every
  syscall we plan to translate. If `_mmap` via raw SVC fails,
  fall back to libSystem stub path (the infrastructure in
  `src/backend/macho/imports.cyr` is staged for this).

## What NOT to do

- Do not remove `src/backend/macho/imports.cyr`. It is staged but
  not wired up yet. It becomes the fallback when raw SVC stops
  working for some syscall or when we want `printf` and friends
  from libSystem directly.
- Do not regress the Linux targets. The aarch64 Linux path is used
  by the `build/cc5_aarch64` cross-compiler and the (eventual)
  native aarch64 compiler for the Pi. Every change to
  `src/backend/aarch64/` must be guarded by `_TARGET_MACHO` when
  it changes codegen.
- Do not try to handle libSystem imports in v5.3.1 scope. Strings
  and globals are enough work. Imports stay deferred; the
  import table module is there when we need it.

## Success criterion for v5.3.1

The following Cyrius program compiles with `CYRIUS_MACHO_ARM=1`,
signs ad-hoc, runs on Apple Silicon, and prints `hello` on stdout
then exits 0:

```
include "lib/string.cyr";
var msg = "hello\n";
syscall(1, 1, msg, 6);
```

Once that works, v5.3.1 can ship. `println` and full `fmt`
support follow naturally because they use the same primitives.

Good hunting.
