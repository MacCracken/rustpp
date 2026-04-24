#!/bin/sh
# Regression: macOS arm64 Mach-O runtime gate.
#
# History: this gate was pinned to v5.6.33 after a cross-built
# `fn main() { syscall(60, 42); return 0; }` fixture exited 1
# instead of 42 on ssh ecb. v5.6.33 investigation determined the
# fixture itself was buggy — cyrius has no auto-invoked `main()`;
# top-level statements are the entry point. The fixture's
# `fn main` body was dead code between the argv prologue's
# branch-over-fn-bodies target and the `_exit(argc=1)` tail,
# hence rc=1. Gate rewritten at v5.6.33 to use correct top-level
# syntax, which exercises the __got[0]=_exit + __got[1]=_write
# reroutes end-to-end on macOS 26.4.1 (Sequoia+).
#
# Skip cleanly if cc5_aarch64 isn't built OR ssh target `ecb` is
# unreachable.
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

TMP=$(mktemp -d)
trap "rm -rf $TMP; ssh -o BatchMode=yes $SSH_TARGET 'rm -f /tmp/cyr_macho_*' 2>/dev/null || true" EXIT

fail=0

# ---- Test 1: bare top-level syscall(60, 42) — __got[0]=_exit reroute
#      Proves: argv prologue, EJMP0→PARSE_PROG target patch, EMACHO_EXIT_ARM,
#              FIXUP ftype=5 adrp+ldr+br through __got[0].
cat > "$TMP/macho_exit.cyr" <<'EOF'
syscall(60, 42);
EOF
CYRIUS_MACHO_ARM=1 "$CC_ARM" < "$TMP/macho_exit.cyr" > "$TMP/macho_exit" 2>/dev/null
scp -q "$TMP/macho_exit" "$SSH_TARGET:/tmp/cyr_macho_exit" >/dev/null
set +e
ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_macho_exit && codesign -s - /tmp/cyr_macho_exit 2>/dev/null; /tmp/cyr_macho_exit'
rc=$?
set -e
if [ "$rc" -ne 42 ]; then
    echo "  FAIL test1 (exit42 via __got[0]): got rc=$rc (expected 42)"
    fail=$((fail+1))
fi

# ---- Test 2: write "hello\n" to stdout then exit 42 — __got[0] + __got[1]
#      Proves: EMACHO_WRITE_ARM arg marshalling (x0/x1/x2 pop order),
#              string literal data in __DATA_CONST, __got[1]=_write bind
#              opcode list parses correctly on Sequoia dyld.
cat > "$TMP/macho_write.cyr" <<'EOF'
syscall(1, 1, "hello\n", 6);
syscall(60, 42);
EOF
CYRIUS_MACHO_ARM=1 "$CC_ARM" < "$TMP/macho_write.cyr" > "$TMP/macho_write" 2>/dev/null
scp -q "$TMP/macho_write" "$SSH_TARGET:/tmp/cyr_macho_write" >/dev/null
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_macho_write && codesign -s - /tmp/cyr_macho_write 2>/dev/null; /tmp/cyr_macho_write')
rc=$?
set -e
if [ "$rc" -ne 42 ]; then
    echo "  FAIL test2 (write+exit rc): got rc=$rc (expected 42)"
    fail=$((fail+1))
fi
if [ "$out" != "hello" ]; then
    echo "  FAIL test2 (write+exit stdout): got '$out' (expected 'hello')"
    fail=$((fail+1))
fi

# ---- Test 3: user fn + arithmetic — exercises v5.6.11 aarch64 combine-shuttle
#      peephole + bl/ret instruction pair + fn prologue/epilogue on Mach-O.
cat > "$TMP/macho_peep.cyr" <<'EOF'
fn add3(a, b, c) { return a + b + c; }
syscall(60, add3(10, 20, 12));
EOF
CYRIUS_MACHO_ARM=1 "$CC_ARM" < "$TMP/macho_peep.cyr" > "$TMP/macho_peep" 2>/dev/null
scp -q "$TMP/macho_peep" "$SSH_TARGET:/tmp/cyr_macho_peep" >/dev/null
set +e
ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_macho_peep && codesign -s - /tmp/cyr_macho_peep 2>/dev/null; /tmp/cyr_macho_peep'
rc=$?
set -e
if [ "$rc" -ne 42 ]; then
    echo "  FAIL test3 (peephole add3 exit42): got rc=$rc (expected 42)"
    fail=$((fail+1))
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "  PASS Mach-O arm64 runtime (exit + write + peephole)"
