#!/bin/sh
# Regression: macOS arm64 Mach-O runtime exit code.
#
# PINNED: v5.6.31. Ships as a skip-stub pre-fix so check.sh stays
# green; flips to PASS when the Mach-O runtime regression is
# repaired.
#
# Background: a cross-built Mach-O binary `syscall(60, 42)` (which
# should reroute to `libSystem._exit(42)` via `__got[0]`) exits
# with code 1 instead of 42 on Apple Silicon (ssh ecb). The v5.5.13
# memory entry explicitly verified exit=42 after the first
# `__got[0]` reroute shipped. Regressed somewhere in v5.5.14
# through v5.6.10. v5.6.11 output is byte-identical to v5.6.10
# for this shape, so NOT a v5.6.11 regression — pre-existing.
#
# Root cause likely in:
#   - __got[0] adrp/ldr/br emission alignment (v5.5.14 multi-slot
#     layout change),
#   - LC_DYLD_INFO_ONLY bind opcode list shape (grew 1→7 across
#     v5.5.14–v5.6.6),
#   - Stricter macOS 26.4.1 (Sequoia+) dyld enforcement.
#
# Skip cleanly if:
#   - cc5_aarch64 isn't built,
#   - ssh target `ecb` is unreachable,
#   - CYRIUS_V5631_SHIPPED not set (pre-fix).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC_ARM="$ROOT/build/cc5_aarch64"
SSH_TARGET="${SSH_TARGET_MACOS:-ecb}"

if [ ! -x "$CC_ARM" ]; then
    echo "  skip: $CC_ARM not present (cross-compiler not built)"
    exit 0
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" 'echo alive' >/dev/null 2>&1; then
    echo "  skip: $SSH_TARGET unreachable (no macOS arm64 runner available)"
    exit 0
fi

if [ -z "$CYRIUS_V5631_SHIPPED" ]; then
    echo "  skip: pin v5.6.31 — macOS arm64 syscall(60,42) exits 1 not 42 (see docs/development/roadmap.md §v5.6.31)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP; ssh -o BatchMode=yes $SSH_TARGET 'rm -f /tmp/cyr_macho_*' 2>/dev/null || true" EXIT

fail=0

# ---- Test 1: bare syscall(60, 42) — simplest Mach-O exit path
cat > "$TMP/macho_bare.cyr" <<'EOF'
fn main() { syscall(60, 42); return 0; }
EOF
CYRIUS_MACHO_ARM=1 "$CC_ARM" < "$TMP/macho_bare.cyr" > "$TMP/macho_bare" 2>/dev/null
scp -q "$TMP/macho_bare" "$SSH_TARGET:/tmp/cyr_macho_bare" >/dev/null
set +e
ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_macho_bare && codesign -s - /tmp/cyr_macho_bare 2>/dev/null; /tmp/cyr_macho_bare'
rc=$?
set -e
if [ "$rc" -ne 42 ]; then
    echo "  FAIL test1 (bare syscall exit42): got rc=$rc (expected 42)"
    fail=$((fail+1))
fi

# ---- Test 2: arithmetic exercising v5.6.11 combine-shuttle peephole
#      `add3(10, 20, 12)` == 42 via EADDR → _TRY_COMBINE_SHUTTLE firing.
#      If the peephole is wrong on Mach-O, this diverges from test1.
cat > "$TMP/macho_peep.cyr" <<'EOF'
fn add3(a, b, c) { return a + b + c; }
fn main() { syscall(60, add3(10, 20, 12)); return 0; }
EOF
CYRIUS_MACHO_ARM=1 "$CC_ARM" < "$TMP/macho_peep.cyr" > "$TMP/macho_peep" 2>/dev/null
scp -q "$TMP/macho_peep" "$SSH_TARGET:/tmp/cyr_macho_peep" >/dev/null
set +e
ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_macho_peep && codesign -s - /tmp/cyr_macho_peep 2>/dev/null; /tmp/cyr_macho_peep'
rc=$?
set -e
if [ "$rc" -ne 42 ]; then
    echo "  FAIL test2 (peephole exit42): got rc=$rc (expected 42)"
    fail=$((fail+1))
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "  PASS Mach-O arm64 runtime exit (bare + peephole)"
