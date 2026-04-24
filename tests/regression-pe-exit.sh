#!/bin/sh
# Regression: Windows 11 PE32+ runtime exit code.
#
# PINNED: v5.6.29. Ships as a skip-stub pre-fix so check.sh stays
# green; flips to PASS when the Windows runtime regression is
# repaired.
#
# Background: a cross-built PE binary `syscall(60, 42)` (which
# should reroute to `kernel32!ExitProcess(42)` via the IAT) exits
# with code 0x40010080 (NTSTATUS informational, decimal
# 1073745920) on Windows 11 24H2 (build 10.0.26200) instead of
# 42. PowerShell reports `ApplicationFailedException` when invoking
# cc5_win.exe directly. v5.6.11 PE output is byte-identical to
# v5.6.10 — NOT a v5.6.11 regression. v5.5.10 memory says exit42
# byte-identity was verified against Linux cross-build, but runtime
# exit code wasn't explicitly asserted on that older Win11 build.
#
# Root cause likely in:
#   - Windows 11 24H2 loader hardening (CET shadow stack / CFG).
#   - PE preferred-base in the DYNAMIC_BASE 32-bit ASLR bucket
#     landing in a now-reserved range on 24H2.
#   - Bare PE shape (no .rsrc, no manifest) triggering 24H2
#     heuristic reject.
#
# Skip cleanly if:
#   - cc5_win isn't built,
#   - ssh target `cass` is unreachable,
#   - CYRIUS_V5629_SHIPPED not set (pre-fix).
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC_WIN="$ROOT/build/cc5_win"
SSH_TARGET="${SSH_TARGET_WIN:-cass}"

if [ ! -x "$CC_WIN" ]; then
    echo "  skip: $CC_WIN not present (PE cross-compiler not built)"
    exit 0
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" 'echo alive' >/dev/null 2>&1; then
    echo "  skip: $SSH_TARGET unreachable (no Windows runner available)"
    exit 0
fi

if [ -z "$CYRIUS_V5629_SHIPPED" ]; then
    echo "  skip: pin v5.6.29 — Windows 11 24H2 PE syscall(60,42) exits 0x40010080 not 42 (see docs/development/roadmap.md §v5.6.29)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP; ssh -o BatchMode=yes $SSH_TARGET 'del /f /q cyr_pe_*.exe cyr_pe_*.bat 2>NUL' 2>/dev/null || true" EXIT

fail=0

# ---- Test 1: bare syscall(60, 42) — simplest PE exit path
cat > "$TMP/pe_bare.cyr" <<'EOF'
fn main() { syscall(60, 42); return 0; }
EOF
"$CC_WIN" < "$TMP/pe_bare.cyr" > "$TMP/pe_bare.exe" 2>/dev/null
cat > "$TMP/runbare.bat" <<'EOF'
@echo off
cyr_pe_bare.exe
echo exit=%ERRORLEVEL%
EOF
scp -q "$TMP/pe_bare.exe" "$SSH_TARGET:cyr_pe_bare.exe" >/dev/null
scp -q "$TMP/runbare.bat" "$SSH_TARGET:cyr_pe_runbare.bat" >/dev/null
set +e
out=$(ssh "$SSH_TARGET" 'cmd /c cyr_pe_runbare.bat' 2>&1 | grep "^exit=")
set -e
rc="${out#exit=}"
if [ "$rc" != "42" ]; then
    echo "  FAIL test1 (bare syscall exit42): got '$out' (expected exit=42)"
    fail=$((fail+1))
fi

# ---- Test 2: arithmetic exercising v5.6.10 x86 combine-shuttle peephole
cat > "$TMP/pe_peep.cyr" <<'EOF'
fn add3(a, b, c) { return a + b + c; }
fn main() { syscall(60, add3(10, 20, 12)); return 0; }
EOF
"$CC_WIN" < "$TMP/pe_peep.cyr" > "$TMP/pe_peep.exe" 2>/dev/null
cat > "$TMP/runpeep.bat" <<'EOF'
@echo off
cyr_pe_peep.exe
echo exit=%ERRORLEVEL%
EOF
scp -q "$TMP/pe_peep.exe" "$SSH_TARGET:cyr_pe_peep.exe" >/dev/null
scp -q "$TMP/runpeep.bat" "$SSH_TARGET:cyr_pe_runpeep.bat" >/dev/null
set +e
out=$(ssh "$SSH_TARGET" 'cmd /c cyr_pe_runpeep.bat' 2>&1 | grep "^exit=")
set -e
rc="${out#exit=}"
if [ "$rc" != "42" ]; then
    echo "  FAIL test2 (peephole exit42): got '$out' (expected exit=42)"
    fail=$((fail+1))
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "  PASS PE32+ Windows runtime exit (bare + peephole)"
