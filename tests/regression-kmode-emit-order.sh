#!/bin/sh
# Regression: under `kernel;` (kmode == 1), top-level asm — including
# the multiboot 32→64 long-mode boot shim — MUST be emitted BEFORE
# 64-bit gvar-init code. Pinned to v5.7.19 from the agnos team's
# proposal at agnos/docs/development/proposals/2026-04-27-cc5-kernel-boot-shim-regression.md.
#
# Pre-v5.7.19 cc5 emitted gvar inits first; the multiboot loader
# handed control in 32-bit protected mode, so the 64-bit `mov rcx,
# imm64; mov [rcx], rax` sequences #GP'd before the boot shim could
# transition to long mode → triple fault → BIOS reset. agnos 1.23.0
# compiled clean + passed all in-tree tests but did not boot.
#
# This gate compiles a minimal kernel; source with a recognizable
# 4-byte top-level asm marker (4× HLT, 0xF4) and a single gvar init
# (var marker = 0xDEADBEEF; emits 48 b9 ... 48 89 01 — REX.W mov
# rcx, imm64; mov [rcx], rax). Then it asserts the asm marker's file
# offset is LESS than the first 48 b9 occurrence.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"
if [ ! -x "$CC" ]; then echo "  skip: $CC not built"; exit 0; fi

TMPDIR="${TMPDIR:-/tmp}"
SC="$TMPDIR/cyrius_kmode_emit_$$"
mkdir -p "$SC"
trap 'rm -rf "$SC"' EXIT

# Build the minimal kmode source.
cat > "$SC/kmode.cyr" <<KMOD
kernel;

var marker_var = 0xDEADBEEF;

asm { 0xF4; 0xF4; 0xF4; 0xF4; }
KMOD

if ! "$CC" < "$SC/kmode.cyr" > "$SC/kmode.bin" 2> "$SC/kmode.err"; then
    echo "  FAIL: kmode compile"
    cat "$SC/kmode.err"
    exit 1
fi

# Convert binary to hex string and find byte offsets of the two markers.
hex=$(xxd -p "$SC/kmode.bin" | tr -d '\n')
asm_pos=$(printf '%s' "$hex" | grep -bo 'f4f4f4f4' | head -1 | cut -d: -f1)
gvar_pos=$(printf '%s' "$hex" | grep -bo '48b9' | head -1 | cut -d: -f1)

if [ -z "$asm_pos" ]; then
    echo "  FAIL: asm marker (f4 f4 f4 f4) not found in kmode binary"
    xxd "$SC/kmode.bin" | tail -10
    exit 1
fi
if [ -z "$gvar_pos" ]; then
    echo "  FAIL: gvar-init marker (48 b9) not found in kmode binary"
    xxd "$SC/kmode.bin" | tail -10
    exit 1
fi

asm_byte=$((asm_pos / 2))
gvar_byte=$((gvar_pos / 2))

if [ "$asm_byte" -ge "$gvar_byte" ]; then
    echo "  FAIL: asm marker at byte $asm_byte not before gvar init at byte $gvar_byte"
    echo "  This is the v5.7.19 regression — kmode emit order broken;"
    echo "  agnos kernel will triple-fault on multiboot entry."
    xxd "$SC/kmode.bin" | tail -10
    exit 1
fi

echo "  PASS: kmode emit order — asm (offset $asm_byte) before gvar init (offset $gvar_byte)"
exit 0
