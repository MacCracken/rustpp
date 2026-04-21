# Inline asm stores silently drop when the emitting fn is include'd rather than same-TU

**Discovered:** 2026-04-20 during sigil 2.9.0 AES-NI implementation
**Severity:** High
**Affects:** cc5 5.4.12, 5.4.12-1, v5.5.19 (still reproduces; see
v5.5.19 update below — root cause pinned to v5.5.20)

## v5.5.19 update — bug narrowed, root cause deferred

The v5.5.19 investigation failed to reproduce the bug at "include
boundary" as originally framed. Cyrius compiles byte-identical
binaries when the same content is split between files vs. inlined;
runtime behavior matches. The actual trigger is a DIFFERENT
codegen defect that happens to manifest under the same circumstances
sigil ran into:

- Callee fn has a ~120-byte asm block (7+ disp8 indexed reads, 6
  disp32 indexed reads, movdqu store — AES-NI shape).
- Caller allocates multiple stack arrays (`var rk[240]; var pt[16];
  var ct[16];`).
- Caller makes the asm-block call, then immediately does a
  `sys_write(...)` or similar syscall wrapper with one of the
  stack-array pointers.

**Narrower trigger discovered in v5.5.19:** the bug is sensitive
to whether the callee's translation-unit (same-TU *or* included)
contains preceding global variable declarations. With a global var
preceding the asm-block fn, the subsequent `sys_write` writes 16
bytes. Without, it writes 0. This shape-sensitivity is why sigil
saw the bug on `src/aes_ni.cyr` (the real file has no leading
global in some configurations) and why our minimal repros didn't
fire (they had no globals, or the file layout happened to align
the fixup window to a working offset).

**Workaround for sigil (v5.5.19+):** keep the scaffold in the same
TU as the caller, or add a leading global var in the included file
before the asm-block fn declaration. The existing `_aes_ni_cache`
global in `src/aes_ni.cyr` is already positioned correctly — sigil
2.9.1 can ship with AES-NI wired into the GCM dispatch without
code changes beyond the one-line `_aes_ni_cache` flip. The v5.5.19
regression test (`tests/regression-inline-asm-discard.sh`) locks
in the workaround shape so future stdlib changes don't accidentally
re-break it.

**Root cause (still speculative):** most likely the fixup-table
pressure theory from the original report. A ~120-byte asm block
inside a fn (same-TU or include'd) probably crosses a fixup window
boundary in a way that offsets the CP tracking for the FOLLOWING
function's emit. Leading globals shift the layout enough to avoid
the boundary crossover. The CP miscounting causes the next
syscall's args to resolve to a wrong address or length, so
`sys_write` sees count=0 and returns 0.

**Pinned to v5.5.20** for an actual backend fix. The regression
test acts as the gate — when v5.5.20 lands a real fix, the test
gets a second assertion asserting both shapes (with and without
leading globals) write 16 bytes.

## Summary

`asm { 0xXX; 0xXX; ... }` blocks that write to memory through a
caller-supplied output-pointer parameter produce the correct machine
code but the stores no-op at runtime when the containing fn is reached
via `include` rather than living in the same compilation unit as its
caller.

Symptom: `objdump` disassembles the two cases to byte-identical machine
code. The asm bytes land in the final ELF at the correct RIP. The
caller's post-call reload from the output slot reads the pre-call zero
anyway, as though the store had been routed to a different virtual
address (or the fn's prologue/epilogue clobbered the pointer register
between entry and the asm block). The sigil agent chased this through
three minimal programs and confirmed the issue is specifically about
the `include` boundary — not about the asm block itself, not about the
AES-NI opcodes (`66 0F 38 DC /r` / `66 0F 38 DD /r`), not about XMM
register handling. Same behaviour reproduces with a plain pointer store
that ignores CPUID entirely, ruling out the CPUID serializing path.

Consequence for the shipping 2.9.0 consumer: AES-NI acceleration (the
headline reason for sigil's minor bump) had to be deferred to 2.9.1.
The scaffold is staged in `src/aes_ni.cyr` with `aes_ni_available()`
pinned to return 0 so the GCM dispatch stays on the well-tested
software path. No data-loss risk (verify is unaffected — AES-NI is
the encrypt side only). HKDF, the other 2.9.0 feature, is independent
and shipped live.

## Reproduction

We attempted a minimal two-file repro at two scales. **Neither
minimal repro fired — both print the expected `66`.** The bug needs a
richer setup than a single-byte-store or a trivial MOVDQU; the sigil
agent reports that three minimal programs at the AES-round-key scale
did reproduce it. The minimal cases are documented here so the Cyrius
agent can confirm the negative result and then extend toward the
sigil scaffold shape.

### Minimal case A — single-byte store through `[rdi]` (did NOT reproduce)

`inline_asm_store.cyr`:

```
fn asm_write_byte(out_ptr) {
    asm {
        # mov rdi, [rbp-8]          ; load out_ptr arg into rdi
        0x48; 0x8B; 0x7D; 0xF8;
        # mov byte ptr [rdi], 0x42
        0xC6; 0x07; 0x42;
    }
    return 0;
}
```

Variant 1 — `asm_write_byte` defined inline in main TU:

```
include "lib/syscalls.cyr"
include "lib/fmt.cyr"
include "lib/string.cyr"

fn asm_write_byte(out_ptr) {
    asm { 0x48; 0x8B; 0x7D; 0xF8; 0xC6; 0x07; 0x42; }
    return 0;
}

fn main() {
    var buf = 0;
    asm_write_byte(&buf);
    fmt_int_fd(1, buf & 0xFF);
    println("");
    return 0;
}

var r = main();
syscall(SYS_EXIT, r);
```

Variant 2 — `asm_write_byte` pulled in via `include`:

```
include "lib/syscalls.cyr"
include "lib/fmt.cyr"
include "lib/string.cyr"
include "/tmp/asm_repro/inline_asm_store.cyr"

fn main() {
    var buf = 0;
    asm_write_byte(&buf);
    fmt_int_fd(1, buf & 0xFF);
    println("");
    return 0;
}

var r = main();
syscall(SYS_EXIT, r);
```

Build+run:

```
cyrius build variant1_inline.cyr v1 && ./v1   # prints 66
cyrius build variant2_included.cyr v2 && ./v2 # prints 66 — ALSO WORKS
```

Expected: variant 1 prints `66`, variant 2 prints `0`. Actual: both
print `66`. Minimal repro does not fire.

### Minimal case B — MOVDQU XMM store to 16-byte alloc (did NOT reproduce)

Richer shape, closer to AES-NI: pxor xmm0, movd xmm0 with 0x42 in
lane 0, movdqu [rdx], xmm0 through a caller-supplied heap pointer.
Same outcome — both variants print `66`. The XMM state machinery is
not the trigger on its own.

### Sigil's actually-failing shape

The shape that failed in sigil 2.9.0 is the full
`aes256_encrypt_block_ni` in `/home/macro/Repos/sigil/src/aes_ni.cyr`
— fourteen AESENC rounds over a 240-byte round-key schedule using
both disp8 (`0x47 <byte>`) and disp32 (`0x87 <dword>`) indexed loads
from `[rdi]`, writing via `movdqu [rdx], xmm0`. Encrypts the FIPS
197 §C.3 vector correctly when inlined; fails silently when the fn
is `include`d. That's a 120-byte asm block vs. our 7-byte and 21-byte
minimals. The delta suggests the trigger is either (a) the fixup
pass choking on many disp32 forward references inside a single asm
block in an included TU, (b) register-allocation interaction with
`include`-scope fn prologues when RDI / RSI / RDX are all live across
the asm, or (c) the disp32 form specifically (both minimals used
disp0 / reg-direct addressing).

Next minimal to try: include an fn whose asm block does
`0x66 0x0F 0x38 0xDC 0x87 <disp32>` — the disp32 AESENC form — over
a caller-supplied round-key pointer, then movdqu the result out
through a second caller-supplied pointer. If that fires, the bug is
scoped to disp32 memory operands inside included asm.

## Root cause (speculation — flag as such)

Most likely: `include`-resolved fn bodies are emitted into a different
section or fixup pass than same-TU fn bodies, and the store through
the output pointer isn't surviving the relocation. Byte-identical
objdump output means the instructions ARE in the final ELF; they're
just not reaching the right RIP, or the fn's prologue/epilogue
clobbers the pointer register between entry and the asm block.

Less likely but worth checking:

- **Calling-convention drift across TU boundaries.** If `include`d fns
  get a different prologue that doesn't preserve the `[rbp-N]` arg
  layout the asm expects, the `mov rdi, [rbp-8]` reads garbage and
  the store writes to a random address. This would be consistent
  with the minimals (which use disp0 / `[rdi]` / `[rdx]` after an
  explicit `mov rdi, [rbp-8]`) also failing — except they don't, they
  pass. So either the calling convention is consistent for small
  cases and drifts only under register pressure, or this isn't it.
- **DCE over-aggressively stripping what it thinks is a dead store**
  because it can't see through the asm block. If cc5 reasons about
  the asm block as "may-clobber nothing visible" in an `include`
  context but "may-clobber *out_ptr" in a same-TU context, it would
  strip the store in the include case. Speculative — would require
  reading cc5's dead-code pass.
- **Fixup-table pressure inside the asm block.** sigil's 120-byte
  asm has disp32 constants; cc5's fixup table is 8192 entries
  globally. If disp32 bytes inside `asm {}` consume fixup slots
  (they shouldn't — they're literal bytes, not symbol references —
  but that's the speculation), spilling across an `include`-emitted
  fn's fixup window could silently drop the later stores. This is
  the guess that best explains "rich repro fires, minimal repro
  doesn't."

Agent cannot narrow further without reading the cc5 backend's
emit-fn-body / fixup-pass / include-resolution interaction.

## Proposed fix

None — just surfacing. This is a compiler-internal codegen issue; a
Cyrius-side fix needs someone who knows how the include-resolution
pass interacts with the asm-block emission and fixup queues. The
sigil agent is confident the asm is right (byte-accurate against
Intel SDM Vol 2A, encrypts the FIPS 197 §C.3 vector correctly when
inlined) and confirmed the issue is the `include` boundary, not the
asm bytes.

## Consumer-side workaround

Inline the asm-containing fn into the same compilation unit as the
caller. For sigil 2.9.0 this would have meant moving
`src/aes_ni.cyr`'s body into `src/aes_gcm.cyr` directly — losing the
separate-file hygiene the project values. The sigil agent instead
chose to:

1. Keep `src/aes_ni.cyr` in-tree with full byte-accurate asm bodies
   and the CPUID probe, so 2.9.1 is a one-line flip to wire them in
   once Cyrius fixes this.
2. Pin `_aes_ni_cache = 0` so `aes_ni_available()` returns 0
   unconditionally in 2.9.0.
3. Leave `aes_gcm_encrypt` / `aes_gcm_decrypt` dispatch unchanged on
   the software path.

Downstream verification trail:

- sigil 2.9.0 ships HKDF live and the software AES-GCM path
  unchanged. No consumer-visible regression.
- majra's `src/ipc_encrypted.cyr` uses sigil's AES-GCM software
  path — no observable change at the majra layer.

Alternative if the include-scope fn body is tolerable to rehome: a
single-compilation-unit `programs/smoke_ni.cyr`-style build that
inlines the asm directly. Works; costs the cross-consumer hygiene.

## References

- `/home/macro/Repos/sigil/src/aes_ni.cyr` — 120-line scaffold, two
  asm blocks (CPUID probe + 14-round AES-256 encrypt), byte-accurate
  Intel SDM Vol 2A opcode sequences, unwired in 2.9.0.
- `/tmp/asm_repro/` — minimal-case source used for this report's
  "did not reproduce" attempts (byte-store variant A,
  MOVDQU/XMM variant B).
- sigil CHANGELOG 2.9.0 entry documents the deferral; 2.9.1 milestone
  is blocked on this issue's resolution.
