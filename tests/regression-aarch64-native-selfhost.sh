#!/bin/sh
# Regression: native aarch64 cc5 self-host on Pi 4.
#
# PINNED: v5.6.32 ✅ shipped. Gate now active.
#
# Background: before v5.6.32 the native variant
# `src/main_aarch64_native.cyr` was missing
# `include "src/common/ir.cyr"` that `src/main_aarch64.cyr` (the
# x86-hosted cross-compiler) already had. `parse_*.cyr` references
# `IR_RAW_EMIT` unconditionally (shipped as v5.6.12 O3a
# instrumentation markers), so the native build errored at parse
# time with "undefined variable 'IR_RAW_EMIT'". The earlier
# "undefined variable '_TARGET_MACHO'" report from the v5.6.11
# session was a stale symptom shape from pre-v5.6.12 source where
# the first undefined reference hit a different symbol; v5.6.32
# unblocks both by adding the ir.cyr include.
#
# v5.6.32 fix: 1-line include add to main_aarch64_native.cyr.
#
# Pipeline this gate enforces:
#   1. Cross-build: cat src/main_aarch64.cyr | build/cc5 > cc5_cross
#      (x86 binary, aarch64 backend)
#   2. Cross-build native: cat src/main_aarch64_native.cyr
#      | cc5_cross > cc5_native
#      (aarch64 binary, aarch64 backend, aarch64 syscall numbers)
#   3. Ship cc5_native + src/ + lib/ to Pi.
#   4. On Pi: cat src/main_aarch64_native.cyr | ./cc5_native > cc5_b
#   5. On Pi: cat src/main_aarch64_native.cyr | ./cc5_b > cc5_c
#   6. Assert cc5_b == cc5_c byte-identical.
#
# Skip cleanly if:
#   - build/cc5 not present,
#   - ssh target `pi` is unreachable.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"
SSH_TARGET="${SSH_TARGET:-pi}"

if [ ! -x "$CC" ]; then
    echo "  skip: $CC not present"
    exit 0
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" 'echo alive' >/dev/null 2>&1; then
    echo "  skip: $SSH_TARGET unreachable (no aarch64 runner available)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP; ssh -o BatchMode=yes $SSH_TARGET 'rm -rf /tmp/cyr_selfhost_*' 2>/dev/null || true" EXIT

# Step 1: cross-compiler (x86 host, aarch64 backend)
cat "$ROOT/src/main_aarch64.cyr" | "$CC" > "$TMP/cc5_cross" 2>/dev/null
chmod +x "$TMP/cc5_cross"

# Step 2: native cc5 (aarch64 host, aarch64 backend) via cross-compiler
cat "$ROOT/src/main_aarch64_native.cyr" | "$TMP/cc5_cross" > "$TMP/cc5_native" 2>/dev/null

# Step 3: ship to Pi
scp -q "$TMP/cc5_native" "$SSH_TARGET:/tmp/cyr_selfhost_cc5" >/dev/null
tar cf - -C "$ROOT" src lib | ssh "$SSH_TARGET" "rm -rf /tmp/cyr_selfhost_tree && mkdir -p /tmp/cyr_selfhost_tree && cd /tmp/cyr_selfhost_tree && tar xf -"

# Steps 4-5: two-step native compile
set +e
ssh "$SSH_TARGET" "chmod +x /tmp/cyr_selfhost_cc5 && \
    cd /tmp/cyr_selfhost_tree && \
    cat src/main_aarch64_native.cyr | /tmp/cyr_selfhost_cc5 > cc5_b 2>/tmp/cyr_selfhost_err_b && \
    chmod +x cc5_b && \
    cat src/main_aarch64_native.cyr | ./cc5_b > cc5_c 2>/tmp/cyr_selfhost_err_c"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
    echo "  FAIL native self-host: compile exited $rc on Pi"
    ssh "$SSH_TARGET" 'head -3 /tmp/cyr_selfhost_err_b /tmp/cyr_selfhost_err_c' 2>&1 | sed 's/^/    /'
    exit 1
fi

# Step 6: byte-identical fixpoint check
if ssh "$SSH_TARGET" 'cd /tmp/cyr_selfhost_tree && cmp cc5_b cc5_c' >/dev/null 2>&1; then
    echo "  PASS native aarch64 self-host byte-identical on $SSH_TARGET"
else
    echo "  FAIL native self-host: cc5_b != cc5_c"
    exit 1
fi
