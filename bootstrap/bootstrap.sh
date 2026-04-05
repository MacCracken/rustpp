#!/bin/sh
# Bootstrap the Cyrius toolchain from the committed asm binary.
# Requires: Linux x86_64, sh, chmod. Nothing else.
#
# Produces: build/stage1f (compiler) and build/asm (assembler)
# After this, compile any .cyr program with:
#   cat program.cyr | ./build/stage1f > program && chmod +x program

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$DIR")"

# Validate inputs
if [ ! -f "$DIR/asm" ]; then
    echo "ERROR: bootstrap/asm not found" >&2
    exit 1
fi
if [ ! -f "$DIR/stage1f.cyr" ]; then
    echo "ERROR: stage1/stage1f.cyr not found" >&2
    exit 1
fi

mkdir -p "$ROOT/build"
chmod +x "$DIR/asm"

echo "=== Cyrius Bootstrap ==="
echo "Seed: $DIR/asm ($(wc -c < "$DIR/asm") bytes)"

# Step 1: Assemble the compiler from source
echo "Assembling stage1f..."
cat "$DIR/stage1f.cyr" | "$DIR/asm" > "$ROOT/build/stage1f"
chmod +x "$ROOT/build/stage1f"
SZ=$(wc -c < "$ROOT/build/stage1f")
echo "  -> build/stage1f ($SZ bytes)"
if [ "$SZ" -lt 10000 ]; then echo "ERROR: stage1f output truncated" >&2; exit 1; fi

# Step 2: Compile the assembler from source (self-hosting verification)
echo "Compiling asm..."
cat "$DIR/asm.cyr" | "$ROOT/build/stage1f" > "$ROOT/build/asm"
chmod +x "$ROOT/build/asm"
SZ=$(wc -c < "$ROOT/build/asm")
echo "  -> build/asm ($SZ bytes)"
if [ "$SZ" -lt 20000 ]; then echo "ERROR: asm output truncated" >&2; exit 1; fi

# Step 3: Verify bootstrap closure
echo "Verifying bootstrap closure..."
cat "$DIR/stage1f.cyr" | "$ROOT/build/asm" > "$ROOT/build/stage1f_check"
if cmp -s "$ROOT/build/stage1f" "$ROOT/build/stage1f_check"; then
    echo "  PASS: stage1f assembled by build/asm matches stage1f assembled by seed"
else
    echo "  FAIL: bootstrap mismatch!"
    exit 1
fi

echo ""
echo "Bootstrap complete. Toolchain ready:"
echo "  Compiler: $ROOT/build/stage1f"
echo "  Assembler: $ROOT/build/asm"
echo ""
echo "Usage:"
echo "  cat program.cyr | ./build/stage1f > program && chmod +x program"
echo "  cat assembly.cyr | ./build/asm > binary && chmod +x binary"
