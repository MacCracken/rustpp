#!/bin/sh
# Regression: v5.7.35 stdlib syscall surface additions
# (agnosys-surfaced — drm/luks/security).
#
# Covers `tests/tcyr/syscall_surface_v5735.tcyr`:
#   1. sys_getrandom + GrndFlag enum (lib/syscalls.cyr + lib/random.cyr)
#   2. random_bytes loop wrapper (lib/random.cyr)
#   3. sys_getdents64 wiring (lib/syscalls.cyr)
#   4. sys_landlock_* wiring (lib/syscalls.cyr)
#   5. lib/security.cyr LandlockAccessFs / LandlockRuleType + GrndFlag
#      enum constants (compile-time + runtime values)
#
# v5.7.35-fix (post-ship): split "wiring verification" from "behavior
# verification". The first version made strong claims about specific
# landlock return values and getdents64 reading `/` — neither held
# universally across CI environments (AGNOS in particular implements
# only a subset of landlock; sandboxed CI runners may not allow `/`
# enumeration). The fix: only `sys_getrandom` is asserted at the
# behavior level (universal Linux ≥ 3.17, including AGNOS). The other
# four wrappers are CALLED but accept any kernel response — the test
# only requires them to not segfault, which is what "the wrapper is
# wired up" actually means.
#
# Single binary; exit-code-encoded failure mode:
#   0  — all assertions held
#   1  — sys_getrandom returned wrong byte count
#   2  — sys_getrandom buffer all-zero (CSPRNG dead?)
#   7  — security.cyr / random.cyr enum constant mismatch
#  11  — random_bytes returned wrong count
#  12  — random_bytes buffer all-zero

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC5="$ROOT/build/cc5"
TEST="$ROOT/tests/tcyr/syscall_surface_v5735.tcyr"

if [ ! -x "$CC5" ]; then
    echo "  skip: $CC5 not built"
    exit 0
fi
if [ ! -f "$TEST" ]; then
    echo "  skip: $TEST missing"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

BIN="$TMP/syscall_surface"
"$CC5" < "$TEST" > "$BIN" 2>"$TMP/compile.err"
chmod +x "$BIN"

if [ ! -s "$BIN" ]; then
    echo "  FAIL: syscall_surface_v5735.tcyr did not compile"
    grep -vE "^\s*dead:|^note:" "$TMP/compile.err" | head -5
    exit 1
fi

# Surface unexpected compile warnings (excluding the noise floor).
unexpected=$(grep -E "^(error|warning):" "$TMP/compile.err" | \
             grep -vE "syscall arity mismatch" || true)
if [ -n "$unexpected" ]; then
    echo "  FAIL: unexpected compile diagnostics"
    echo "$unexpected" | head -5
    exit 1
fi

set +e
"$BIN" >/dev/null 2>&1
rc=$?
set -e

case "$rc" in
    0)
        echo "  PASS: stdlib syscall surface — getrandom + getdents64 + landlock + random_bytes (v5.7.35)"
        exit 0
        ;;
    1)  echo "  FAIL: sys_getrandom returned wrong byte count"; exit 1 ;;
    2)  echo "  FAIL: sys_getrandom buffer all-zero (CSPRNG?)"; exit 1 ;;
    7)  echo "  FAIL: enum constant mismatch (security.cyr or random.cyr)"; exit 1 ;;
    11) echo "  FAIL: random_bytes returned wrong count"; exit 1 ;;
    12) echo "  FAIL: random_bytes buffer all-zero"; exit 1 ;;
    *)  echo "  FAIL: unexpected exit code $rc (segfault or stack/heap corruption)"; exit 1 ;;
esac
