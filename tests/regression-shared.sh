#!/bin/sh
# Regression: `shared;` directive produces a dlopen-able .so with
# working function calls, string literal refs, mutable global data,
# and DT_INIT-driven initializers.
#
# Covers 4.7.0 alpha1/alpha2/GA + the shared-mode fn-body elision fix.
#
# Skipped on systems without a C compiler.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"

if ! command -v cc >/dev/null 2>&1; then
    echo "  skip: no cc in PATH (dlopen harness needs a C compiler)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# --- 1. Shared library exercising all three PIC surfaces ---
cat > "$TMP/lib.cyr" <<'EOF'
shared;

var counter = 100;

fn add(a, b) { return a + b; }
fn greeting() { return "hello from cyrius"; }
fn get_counter() { return counter; }
fn inc_counter() { counter = counter + 1; return counter; }
EOF

cat "$TMP/lib.cyr" | "$CC" > "$TMP/lib.so" 2>/dev/null
chmod +x "$TMP/lib.so"

# --- 2. C harness: dlopen, dlsym every exported fn, call them ---
cat > "$TMP/harness.c" <<EOF
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    void *h = dlopen("$TMP/lib.so", RTLD_NOW);
    if (!h) { fprintf(stderr, "dlopen failed: %s\n", dlerror()); return 1; }

    long (*add)(long, long)    = dlsym(h, "add");
    const char *(*greeting)(void) = dlsym(h, "greeting");
    long (*get)(void)          = dlsym(h, "get_counter");
    long (*inc)(void)          = dlsym(h, "inc_counter");

    if (!add || !greeting || !get || !inc) {
        fprintf(stderr, "dlsym failed: %s\n", dlerror()); return 2;
    }

    int errors = 0;

    if (add(17, 25) != 42)                  { fputs("add wrong\n", stderr);        errors++; }
    if (strcmp(greeting(), "hello from cyrius") != 0) {
                                              fputs("greeting wrong\n", stderr);   errors++; }
    if (get() != 100)                       { fputs("DT_INIT didn't run\n", stderr); errors++; }
    if (inc() != 101)                       { fputs("inc() 1 wrong\n", stderr);    errors++; }
    if (inc() != 102)                       { fputs("inc() 2 wrong\n", stderr);    errors++; }
    if (get() != 102)                       { fputs("state didn't persist\n", stderr); errors++; }

    dlclose(h);
    return errors;
}
EOF

cc -o "$TMP/harness" "$TMP/harness.c" -ldl 2>/dev/null
"$TMP/harness"
