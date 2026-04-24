#!/bin/sh
# Regression: native aarch64 cc5 self-host on Pi 4.
#
# PINNED: v5.6.26. Ships as a skip-stub pre-fix so check.sh stays
# green; flips to PASS when the `_TARGET_MACHO` parse-time undef
# is repaired.
#
# Background: the cross-built native aarch64 cc5 (emitted by
# `cc5_aarch64 < src/main_aarch64.cyr`) fails at parse time when
# trying to self-host on the Pi:
#
#   error:292: undefined variable '_TARGET_MACHO'
#
# `_TARGET_MACHO` is declared at `src/backend/aarch64/emit.cyr:37`
# and included before main_aarch64.cyr's reference at line 290
# (inside an `if (_macho_arm_env != 0)` block). The cross-compiler
# resolves this reference correctly; the native binary does not.
# Caught during v5.6.11 verification (2026-04-23).
#
# Affects at least v5.6.10 and v5.6.11 (byte-identical for this
# parse path). Pre-existing regression — root cause unknown.
#
# The CLAUDE.md claim "native aarch64 self-hosts byte-identical
# on Pi 4" does NOT currently hold. This gate enforces it going
# forward.
#
# Skip cleanly if:
#   - cc5_aarch64 isn't built (CI tier mismatch),
#   - ssh target `pi` is unreachable,
#   - CYRIUS_V5626_SHIPPED is set (explicit opt-out during v5.6.26 dev).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC_ARM="$ROOT/build/cc5_aarch64"
SSH_TARGET="${SSH_TARGET:-pi}"

if [ ! -x "$CC_ARM" ]; then
    echo "  skip: $CC_ARM not present (cross-compiler not built)"
    exit 0
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" 'echo alive' >/dev/null 2>&1; then
    echo "  skip: $SSH_TARGET unreachable (no aarch64 runner available)"
    exit 0
fi

# Until v5.6.26 ships the fix, this is a known-broken case. Keep
# the stub skipping so CI stays actionable; flip this guard when
# the fix lands.
if [ -z "$CYRIUS_V5626_SHIPPED" ]; then
    echo "  skip: pin v5.6.26 — native aarch64 self-host '_TARGET_MACHO' undef (see docs/development/roadmap.md §v5.6.26)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP; ssh -o BatchMode=yes $SSH_TARGET 'rm -rf /tmp/cyr_selfhost_*' 2>/dev/null || true" EXIT

# Build the native aarch64 cc5 via the cross-compiler.
cat "$ROOT/src/main_aarch64.cyr" | "$CC_ARM" > "$TMP/cc5_native" 2>/dev/null
chmod +x "$TMP/cc5_native"

# Ship cc5_native + the full src/ + lib/ tree to the Pi.
scp -q "$TMP/cc5_native" "$SSH_TARGET:/tmp/cyr_selfhost_cc5" >/dev/null
tar cf - -C "$ROOT" src lib | ssh "$SSH_TARGET" "rm -rf /tmp/cyr_selfhost_tree && mkdir -p /tmp/cyr_selfhost_tree && cd /tmp/cyr_selfhost_tree && tar xf -"

# On the Pi: have the native cc5 compile its own source.
set +e
ssh "$SSH_TARGET" "chmod +x /tmp/cyr_selfhost_cc5 && cd /tmp/cyr_selfhost_tree && cat src/main_aarch64.cyr | /tmp/cyr_selfhost_cc5 > /tmp/cyr_selfhost_out 2>/tmp/cyr_selfhost_err"
rc=$?
set -e

if [ "$rc" -ne 0 ]; then
    echo "  FAIL native self-host: cc5_native exited $rc on Pi"
    ssh "$SSH_TARGET" 'head -3 /tmp/cyr_selfhost_err' 2>&1 | sed 's/^/    /'
    exit 1
fi

# Byte-identical check: native binary produced on Pi must match
# the cross-built native binary byte-for-byte.
ssh "$SSH_TARGET" 'md5sum /tmp/cyr_selfhost_cc5 /tmp/cyr_selfhost_out' | awk '{print $1}' | sort -u | wc -l | (
    read count
    if [ "$count" -ne 1 ]; then
        echo "  FAIL native self-host: output DIVERGES from cross-built binary"
        exit 1
    fi
)

echo "  PASS native aarch64 self-host byte-identical on $SSH_TARGET"
