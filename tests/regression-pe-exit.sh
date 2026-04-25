#!/bin/sh
# Regression: Windows 11 PE32+ runtime exit code.
#
# History: pinned to v5.6.34 (later v5.6.36) after a cross-built
# `fn main() { syscall(60, 42); return 0; }` fixture exited
# 0x40010080 (decimal 1073745920) on ssh cass — same exact
# misdiagnosis pattern as v5.6.33's Mach-O gate. Cyrius has no
# auto-invoked `main()`; top-level statements are the program
# entry. The `fn main()` body is dead code; the entry prologue
# branches over it to EEXIT, which calls
# `kernel32!ExitProcess(arg)` with whatever happens to be in the
# arg-slot register at that point on Win11 24H2 (= 0x40010080,
# an NTSTATUS-shaped value left there by the runtime). Gate
# rewritten at v5.6.36 to use correct top-level syntax;
# end-to-end confirmed exit=42 on Win11 24H2 build 26200.
#
# The PE shape itself is fine on Win11 24H2 (loader does NOT
# require NX_COMPAT / DYNAMIC_BASE — verified by patching
# DllCharacteristics from 0x0000 → 0x0160 and observing
# byte-identical exit behavior).
#
# Skip cleanly if cc5_win cross-build isn't built OR ssh target
# `cass` is unreachable.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Linux-host PE cross-compiler. `build/cc5_win` is the SELF-HOSTED
# Windows-native cyrius compiler (PE32+); we need the Linux ELF
# cross-compiler that emits PE. Build it on demand if missing.
CC_PE="$ROOT/build/cc5_win_cross"
SSH_TARGET="${SSH_TARGET_WIN:-cass}"

if [ ! -x "$CC_PE" ]; then
    if [ -x "$ROOT/build/cc5" ] && [ -f "$ROOT/src/main_win.cyr" ]; then
        "$ROOT/build/cc5" < "$ROOT/src/main_win.cyr" > "$CC_PE" 2>/dev/null || true
        chmod +x "$CC_PE" 2>/dev/null || true
    fi
fi
if [ ! -x "$CC_PE" ]; then
    echo "  skip: $CC_PE not present (Linux→PE cross-compiler not built)"
    exit 0
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" 'echo alive' >/dev/null 2>&1; then
    echo "  skip: $SSH_TARGET unreachable (no Windows runner available)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP; ssh -o BatchMode=yes $SSH_TARGET 'del /f /q cyr_pe_*.exe cyr_pe_*.bat 2>NUL' 2>/dev/null || true" EXIT

fail=0

# ---- Test 1: bare top-level syscall(60, 42) — simplest PE exit path
#      Proves: PE entry, IAT, kernel32!ExitProcess reroute, Win11
#      24H2 loader accepts our PE shape.
cat > "$TMP/pe_exit.cyr" <<'EOF'
syscall(60, 42);
EOF
"$CC_PE" < "$TMP/pe_exit.cyr" > "$TMP/pe_exit.exe" 2>/dev/null
cat > "$TMP/runexit.bat" <<'EOF'
@echo off
cyr_pe_exit.exe
echo exit=%ERRORLEVEL%
EOF
scp -q "$TMP/pe_exit.exe" "$SSH_TARGET:cyr_pe_exit.exe" >/dev/null
scp -q "$TMP/runexit.bat" "$SSH_TARGET:cyr_pe_runexit.bat" >/dev/null
set +e
out=$(ssh "$SSH_TARGET" 'cmd /c cyr_pe_runexit.bat' 2>&1 | tr -d '\r' | grep "^exit=")
set -e
rc="${out#exit=}"
if [ "$rc" != "42" ]; then
    echo "  FAIL test1 (exit42 via kernel32 IAT): got '$out' (expected exit=42)"
    fail=$((fail+1))
fi

# ---- Test 2: write "hello\n" then exit 42 — kernel32!WriteFile + ExitProcess
#      Proves: stdout write reroute, IAT call sequence with multi-arg setup,
#              ExitProcess reroute after a successful prior IAT call.
cat > "$TMP/pe_write.cyr" <<'EOF'
syscall(1, 1, "hello\n", 6);
syscall(60, 42);
EOF
"$CC_PE" < "$TMP/pe_write.cyr" > "$TMP/pe_write.exe" 2>/dev/null
cat > "$TMP/runwrite.bat" <<'EOF'
@echo off
cyr_pe_write.exe
echo exit=%ERRORLEVEL%
EOF
scp -q "$TMP/pe_write.exe" "$SSH_TARGET:cyr_pe_write.exe" >/dev/null
scp -q "$TMP/runwrite.bat" "$SSH_TARGET:cyr_pe_runwrite.bat" >/dev/null
set +e
out_full=$(ssh "$SSH_TARGET" 'cmd /c cyr_pe_runwrite.bat' 2>&1 | tr -d '\r')
set -e
rc=$(echo "$out_full" | grep "^exit=" | sed 's/^exit=//')
hello_seen=$(echo "$out_full" | grep -c "^hello$")
if [ "$rc" != "42" ]; then
    echo "  FAIL test2 (write+exit rc): got '$out_full' (expected exit=42)"
    fail=$((fail+1))
fi
if [ "$hello_seen" != "1" ]; then
    echo "  FAIL test2 (write+exit stdout): 'hello' not in output ($out_full)"
    fail=$((fail+1))
fi

# ---- Test 3: arithmetic via user fn — v5.6.10 x86 combine-shuttle peephole
#      Proves: peephole correctness on PE-emitted code paths + call/ret pair.
cat > "$TMP/pe_peep.cyr" <<'EOF'
fn add3(a, b, c) { return a + b + c; }
syscall(60, add3(10, 20, 12));
EOF
"$CC_PE" < "$TMP/pe_peep.cyr" > "$TMP/pe_peep.exe" 2>/dev/null
cat > "$TMP/runpeep.bat" <<'EOF'
@echo off
cyr_pe_peep.exe
echo exit=%ERRORLEVEL%
EOF
scp -q "$TMP/pe_peep.exe" "$SSH_TARGET:cyr_pe_peep.exe" >/dev/null
scp -q "$TMP/runpeep.bat" "$SSH_TARGET:cyr_pe_runpeep.bat" >/dev/null
set +e
out=$(ssh "$SSH_TARGET" 'cmd /c cyr_pe_runpeep.bat' 2>&1 | tr -d '\r' | grep "^exit=")
set -e
rc="${out#exit=}"
if [ "$rc" != "42" ]; then
    echo "  FAIL test3 (peephole add3 exit42): got '$out' (expected exit=42)"
    fail=$((fail+1))
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

echo "  PASS PE32+ Windows runtime (exit + write + peephole)"
