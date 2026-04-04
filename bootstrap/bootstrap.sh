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

mkdir -p "$ROOT/build"

echo "=== Cyrius Bootstrap ==="
echo "Seed: $DIR/asm ($(wc -c < "$DIR/asm") bytes)"

# Step 1: Assemble the compiler from source
echo "Assembling stage1f..."
cat "$ROOT/stage1/stage1f.cyr" | "$DIR/asm" > "$ROOT/build/stage1f"
chmod +x "$ROOT/build/stage1f"
echo "  -> build/stage1f ($(wc -c < "$ROOT/build/stage1f") bytes)"

# Step 2: Compile the assembler from source (self-hosting verification)
echo "Compiling asm..."
cat "$ROOT/stage1/asm.cyr" | "$ROOT/build/stage1f" > "$ROOT/build/asm"
chmod +x "$ROOT/build/asm"
echo "  -> build/asm ($(wc -c < "$ROOT/build/asm") bytes)"

# Step 3: Verify bootstrap closure
echo "Verifying bootstrap closure..."
cat "$ROOT/stage1/stage1f.cyr" | "$ROOT/build/asm" > "$ROOT/build/stage1f_check"
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
