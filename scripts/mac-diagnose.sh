#!/bin/sh
# mac-diagnose.sh — dump everything needed to debug a SIGILL in cc5_macho.
# Run on the Mac. Paste the whole output back.
#
# Usage:
#   ./mac-diagnose.sh [path-to-cc5_macho]
set +e  # keep going past failing commands

CC5=${1:-./cc5_macho}

echo "========================================"
echo "cc5_macho SIGILL diagnosis"
echo "========================================"
echo
echo "### System"
uname -a
sw_vers 2>/dev/null
echo "cwd: $(pwd)"
echo

echo "### Binary sanity"
ls -la "$CC5"
file "$CC5"
echo
echo "  header:"
otool -h "$CC5" 2>&1 | head -20
echo
echo "  load commands (first 30 lines):"
otool -l "$CC5" 2>&1 | head -30
echo

echo "### Codesign status"
codesign -dvvv "$CC5" 2>&1 | head -15
echo
codesign --verify --verbose "$CC5" 2>&1
echo

echo "### Baseline toolchain probe"
echo "  Writing exit42 probe..."
printf 'syscall(60, 42);\n' > /tmp/exit42_probe.cyr
# If cc5_aarch64 isn't on the Mac, skip. Otherwise sanity-check it.
if [ -x "./cc5_aarch64" ] || command -v cc5_aarch64 >/dev/null 2>&1; then
    CROSS=$(command -v cc5_aarch64 || echo "./cc5_aarch64")
    echo "  Using $CROSS"
    CYRIUS_MACHO_ARM=1 "$CROSS" < /tmp/exit42_probe.cyr > /tmp/exit42.macho 2>&1
    chmod +x /tmp/exit42.macho 2>/dev/null
    codesign -s - --force /tmp/exit42.macho 2>/dev/null
    /tmp/exit42.macho
    ec=$?
    echo "  exit42.macho → $ec (expect 42)"
else
    echo "  SKIP: no local cc5_aarch64 on Mac. Push an exit42.macho from Linux"
    echo "        to reproduce the baseline check here."
fi
echo

echo "### Running cc5_macho under lldb to capture PC at SIGILL"
cat > /tmp/lldb_cmds.txt <<'LLDB'
process launch -i /dev/null -o /dev/null
register read pc x0 x1 x16 sp
disassemble --pc --count 8
memory read --size 4 --count 4 $pc
bt
quit
LLDB

lldb -s /tmp/lldb_cmds.txt "$CC5" 2>&1 | tail -60
echo

echo "### Direct run (fallback) — captures exit / signal"
"$CC5" < /dev/null > /dev/null 2>&1
ec=$?
echo "  direct run exit=$ec  (137=SIGKILL, 132=SIGILL on macOS, 139=SIGSEGV)"
echo

echo "========================================"
echo "End of diagnostic. Paste all of the above."
echo "========================================"
