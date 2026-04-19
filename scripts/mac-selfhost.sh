#!/bin/sh
# mac-selfhost.sh — validate cc5_macho byte-identical self-host on Apple Silicon.
# Run this ON the Mac (archaemenid.local) after you've scp'd cc5_macho over
# and ad-hoc-signed it. The source file can already live alongside (checked
# out) or be scp'd in too — script handles both.
#
# Usage (from the Mac):
#   ./mac-selfhost.sh [path-to-cc5_macho] [path-to-main_aarch64_macho.cyr]
# Defaults: ./cc5_macho and ./main_aarch64_macho.cyr (or src/...)
set -e

CC5=${1:-./cc5_macho}
SRC=${2:-}

# Locate the source file if not explicit
if [ -z "$SRC" ]; then
    if [ -f "./main_aarch64_macho.cyr" ]; then
        SRC=./main_aarch64_macho.cyr
    elif [ -f "./src/main_aarch64_macho.cyr" ]; then
        SRC=./src/main_aarch64_macho.cyr
    else
        echo "error: main_aarch64_macho.cyr not found. Pass as arg 2, or place"
        echo "  in cwd / src/. Pull with:"
        echo "    scp macro@<linux-host>:Repos/cyrius/src/main_aarch64_macho.cyr ."
        exit 1
    fi
fi

if [ ! -x "$CC5" ]; then
    echo "error: $CC5 not executable. Run: chmod +x $CC5 && codesign -s - --force $CC5"
    exit 1
fi

echo "cc5:    $CC5 ($(wc -c < "$CC5") bytes)"
echo "source: $SRC ($(wc -c < "$SRC") bytes)"
echo ""

# Sanity check the signature — unsigned ad-hoc binaries segfault on Apple
# Silicon before they even reach main.
if ! codesign -dv "$CC5" >/dev/null 2>&1; then
    echo "  note: $CC5 is not codesigned. Signing ad-hoc..."
    codesign -s - --force "$CC5"
fi

# Round 1: use the cc5_macho to compile itself → cc5_macho_b.
# Guarded by a 30s watchdog: a correct compile on M-series takes <2s, so if
# we're past 30s the compiler is looping and we bail with enough context.
echo "=== Round 1: compile self ==="
echo "  cc5:  $CC5 ($(wc -c < "$CC5") bytes)"
echo "  src:  $SRC ($(wc -c < "$SRC") bytes)"
echo "  starting compile..."

"$CC5" < "$SRC" > cc5_macho_b 2> cc5_macho_b.err &
pid=$!
elapsed=0
while kill -0 $pid 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [ $elapsed -ge 30 ]; then
        echo "  TIMEOUT after ${elapsed}s — compiler is stuck. Killing pid $pid."
        kill -9 $pid 2>/dev/null
        wait $pid 2>/dev/null
        echo "  partial stdout (first 256 bytes):"
        head -c 256 cc5_macho_b | xxd | head -4
        echo "  stderr:"
        head -20 cc5_macho_b.err
        echo
        echo "FAIL: self-host compile hung. Likely causes:"
        echo "  - cc5_macho built with wrong backend (re-check it's cc5_aarch64 output)"
        echo "  - infinite loop in a host-specific code path"
        echo "  - stdin redirect not wired; try: cat \"$SRC\" | \"$CC5\" > cc5_macho_b"
        exit 1
    fi
done
wait $pid
rc=$?
echo "  finished in ${elapsed}s, cc5_macho_b: $(wc -c < cc5_macho_b 2>/dev/null) bytes, exit=$rc"
if [ $rc -ne 0 ]; then
    echo "  stderr:"
    head -20 cc5_macho_b.err
    exit 1
fi
chmod +x cc5_macho_b
codesign -s - --force cc5_macho_b

# Round 2: verify byte-identical.
if cmp "$CC5" cc5_macho_b; then
    echo ""
    echo "PASS: cc5_macho == cc5_macho_b (byte-identical self-host on Apple Silicon)"
else
    echo ""
    echo "FAIL: binaries differ — not self-hosting."
    echo "  sizes: $(wc -c < "$CC5") vs $(wc -c < cc5_macho_b)"
    echo "  first-diff byte offset: $(cmp "$CC5" cc5_macho_b 2>&1 | head -1)"
    exit 1
fi

# Round 3: second-generation self-host — cc5_macho_b compiles self → cc5_macho_c.
# Catches codegen drift that only shows up when the compiler-of-origin is
# already the Mach-O build (belt-and-suspenders against any compile-time
# env quirks between cross-compile and native-compile).
echo ""
echo "=== Round 2: second-gen self-host ==="
./cc5_macho_b < "$SRC" > cc5_macho_c
chmod +x cc5_macho_c
codesign -s - --force cc5_macho_c
echo "  cc5_macho_c: $(wc -c < cc5_macho_c) bytes"

if cmp cc5_macho_b cc5_macho_c; then
    echo ""
    echo "PASS: cc5_macho_b == cc5_macho_c (fixed point on Apple Silicon)"
else
    echo "FAIL: round-2 drift — $(cmp cc5_macho_b cc5_macho_c 2>&1 | head -1)"
    exit 1
fi

echo ""
echo "Apple Silicon self-host verified. You can pull these back to Linux with:"
echo "  scp macro@archaemenid.local:$(pwd)/cc5_macho_b /tmp/"
