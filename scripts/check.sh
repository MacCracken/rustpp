#!/bin/sh
# Full project audit: self-host, test suite, heap audit, format, lint
# Usage: cyrius audit  (or: sh scripts/check.sh)
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC="$ROOT/build/cc5"
CYRFMT="$ROOT/build/cyrfmt"
CYRLINT="$ROOT/build/cyrlint"

# Shared fmt/lint walkers (skip symlinked deps, identical semantics with the
# `cyrius audit` dispatcher's generic path).
if [ -f "$ROOT/scripts/lib/audit-walk.sh" ]; then
    . "$ROOT/scripts/lib/audit-walk.sh"
fi

pass=0
fail=0
total=0

check() {
    total=$((total + 1))
    if [ "$2" = "0" ]; then
        printf "  \033[32mPASS\033[0m: %s\n" "$1"
        pass=$((pass + 1))
    else
        printf "  \033[31mFAIL\033[0m: %s\n" "$1"
        fail=$((fail + 1))
    fi
}

echo "=== Cyrius v2.0 Audit ==="
echo ""

# ── 1. Self-hosting (two-step) ──
echo "── Self-Hosting ──"
cc_a="/tmp/audit_cc_a_$$"
cc_b="/tmp/audit_cc_b_$$"
cat "$ROOT/src/main.cyr" | "$CC" > "$cc_a" 2>/dev/null && chmod +x "$cc_a"
cat "$ROOT/src/main.cyr" | "$cc_a" > "$cc_b" 2>/dev/null
cmp -s "$cc_a" "$cc_b" 2>/dev/null
check "cc5==cc5 byte-identical" "$?"
sz=$(wc -c < "$cc_a")
printf "    binary: %d bytes\n" "$sz"
rm -f "$cc_a" "$cc_b"
echo ""

# ── 2. Heap Map Audit ──
echo "── Heap Map ──"
sh "$ROOT/tests/heapmap.sh" > /tmp/audit_heap_$$ 2>&1
hm_result=$?
check "no heap overlaps" "$hm_result"
if [ "$hm_result" -ne 0 ]; then cat /tmp/audit_heap_$$; fi
rm -f /tmp/audit_heap_$$
echo ""

# ── 3. Test Suite (.tcyr) ──
echo "── Test Suite ──"
test_fail=0
test_total=0
for tfile in "$ROOT"/tests/tcyr/*.tcyr; do
    [ -f "$tfile" ] || continue
    name=$(basename "$tfile" .tcyr)
    tmpbin="/tmp/audit_t_$$"
    printf "  %-20s " "$name"
    if cat "$tfile" | "$CC" > "$tmpbin" 2>/dev/null && chmod +x "$tmpbin"; then
        output=$("$tmpbin" 2>&1 | tr -d '\0')
        ec=$?
        summary=$(echo "$output" | grep -o '[0-9]* passed, [0-9]* failed' | tail -1)
        if [ -n "$summary" ]; then
            f=$(echo "$summary" | grep -o '[0-9]* failed' | grep -o '^[0-9]*')
            if [ "$f" -gt 0 ]; then
                echo "FAIL ($summary)"
                test_fail=$((test_fail + 1))
            else
                echo "PASS ($summary)"
            fi
        elif [ "$ec" -eq 0 ]; then
            echo "PASS"
        else
            echo "FAIL (exit $ec)"
            test_fail=$((test_fail + 1))
        fi
    else
        echo "FAIL (compile)"
        test_fail=$((test_fail + 1))
    fi
    test_total=$((test_total + 1))
    rm -f "$tmpbin"
done
check "test suite ($test_total files)" "$test_fail"
echo ""

# ── 4a. Shared-object regression (.so + dlopen) ──
echo "── Shared-object ──"
sh "$ROOT/tests/regression-shared.sh" > /tmp/audit_so_$$ 2>&1
so_result=$?
check "shared; + dlopen round-trip" "$so_result"
if [ "$so_result" -ne 0 ]; then cat /tmp/audit_so_$$; fi
rm -f /tmp/audit_so_$$
echo ""

# ── 4b. Linker regression (cyrld) ──
echo "── Linker ──"
sh "$ROOT/tests/regression-linker.sh" > /tmp/audit_ld_$$ 2>&1
ld_result=$?
check "cyrld cross-module link" "$ld_result"
if [ "$ld_result" -ne 0 ]; then cat /tmp/audit_ld_$$; fi
rm -f /tmp/audit_ld_$$
echo ""

# ── 4c. Capacity meter regression (4.8.3) ──
echo "── Capacity meter ──"
sh "$ROOT/tests/regression-capacity.sh" > /tmp/audit_cap_$$ 2>&1
cap_result=$?
check "cyrius capacity (default / --check / --json / fnc>2048)" "$cap_result"
if [ "$cap_result" -ne 0 ]; then cat /tmp/audit_cap_$$; fi
rm -f /tmp/audit_cap_$$
echo ""

# ── 4d. object;-mode init binding (5.4.9) ──
echo "── Object init binding ──"
sh "$ROOT/tests/regression-object-init.sh" > /tmp/audit_oi_$$ 2>&1
oi_result=$?
check "_cyrius_init STB_GLOBAL in object; mode" "$oi_result"
if [ "$oi_result" -ne 0 ]; then cat /tmp/audit_oi_$$; fi
rm -f /tmp/audit_oi_$$
echo ""

# ── 4e. aarch64 syscall stdlib + thread trampoline (5.4.11) ──
echo "── aarch64 syscalls + threads ──"
sh "$ROOT/tests/regression-aarch64-syscalls.sh" > /tmp/audit_aa_$$ 2>&1
aa_result=$?
check "aarch64 syscall stdlib + post-clone trampoline (via ssh pi)" "$aa_result"
if [ "$aa_result" -ne 0 ]; then cat /tmp/audit_aa_$$; fi
rm -f /tmp/audit_aa_$$
echo ""

# ── 4f. inline-asm discard-result gate (5.5.19) ──
echo "── Inline-asm discard-result ──"
sh "$ROOT/tests/regression-inline-asm-discard.sh" > /tmp/audit_ia_$$ 2>&1
ia_result=$?
check "120B asm fn + standalone sys_write (sigil AES-NI shape)" "$ia_result"
if [ "$ia_result" -ne 0 ]; then cat /tmp/audit_ia_$$; fi
rm -f /tmp/audit_ia_$$
echo ""

# ── 4g. cyrfmt --write in-place rewrite (5.5.22) ──
echo "── cyrfmt --write ──"
sh "$ROOT/tests/regression-cyrfmt-write.sh" > /tmp/audit_cf_$$ 2>&1
cf_result=$?
check "cyrfmt --write / -w in-place rewrite + idempotent mtime" "$cf_result"
if [ "$cf_result" -ne 0 ]; then cat /tmp/audit_cf_$$; fi
rm -f /tmp/audit_cf_$$
echo ""

# ── 4h. Reserved-keyword diagnostic (5.5.26) ──
echo "── Reserved-keyword diag ──"
sh "$ROOT/tests/regression-reserved-kw-diag.sh" > /tmp/audit_kw_$$ 2>&1
kw_result=$?
check "'var match/in/default/shared' → 'reserved keyword ... cannot be used as identifier'" "$kw_result"
if [ "$kw_result" -ne 0 ]; then cat /tmp/audit_kw_$$; fi
rm -f /tmp/audit_kw_$$
echo ""

# ── 4i. lib/shadow.cyr + lib/pam.cyr (5.5.27) ──
echo "── Shadow + PAM ──"
sh "$ROOT/tests/regression-shadow-pam.sh" > /tmp/audit_sp_$$ 2>&1
sp_result=$?
check "shadow_getspnam + unix_chkpwd auth paths" "$sp_result"
if [ "$sp_result" -ne 0 ]; then cat /tmp/audit_sp_$$; fi
rm -f /tmp/audit_sp_$$
echo ""

# ── 4j. lib/fdlopen.cyr primitives (5.5.28) ──
echo "── fdlopen primitives ──"
sh "$ROOT/tests/regression-fdlopen.sh" > /tmp/audit_fdl_$$ 2>&1
fdl_result=$?
check "setjmp/longjmp + helper-path + state-buf API" "$fdl_result"
if [ "$fdl_result" -ne 0 ]; then cat /tmp/audit_fdl_$$; fi
rm -f /tmp/audit_fdl_$$
echo ""

# ── 4k. lib/thread_local.cyr per-thread slots (5.5.30) ──
echo "── thread-local slots ──"
sh "$ROOT/tests/regression-thread-local.sh" > /tmp/audit_tl_$$ 2>&1
tl_result=$?
check "%fs / TPIDR_EL0 slots + CLONE_SETTLS worker isolation" "$tl_result"
if [ "$tl_result" -ne 0 ]; then cat /tmp/audit_tl_$$; fi
rm -f /tmp/audit_tl_$$
echo ""

# ── 4l. lib/atomic.cyr primitives + mutex race-free (5.5.31) ──
echo "── atomics + mutex race-free ──"
sh "$ROOT/tests/regression-atomics.sh" > /tmp/audit_at_$$ 2>&1
at_result=$?
check "atomic_cas/fetch_add/fence + 4-thread contention + mutex" "$at_result"
if [ "$at_result" -ne 0 ]; then cat /tmp/audit_at_$$; fi
rm -f /tmp/audit_at_$$
echo ""

# ── 4m. stdlib thread-safety audit pattern (5.5.32) ──
echo "── thread-safety pattern ──"
sh "$ROOT/tests/regression-thread-safety.sh" > /tmp/audit_ts_$$ 2>&1
ts_result=$?
check "mutex-wrapped hashmap + vec under 4-thread contention" "$ts_result"
if [ "$ts_result" -ne 0 ]; then cat /tmp/audit_ts_$$; fi
rm -f /tmp/audit_ts_$$
echo ""

# ── 4n. lib/flags.cyr getopt-long parser (5.5.33) ──
echo "── flags parser ──"
sh "$ROOT/tests/regression-flags.sh" > /tmp/audit_fl_$$ 2>&1
fl_result=$?
check "bool/int/str flags + positionals + error paths" "$fl_result"
if [ "$fl_result" -ne 0 ]; then cat /tmp/audit_fl_$$; fi
rm -f /tmp/audit_fl_$$
echo ""

# ── 4o. native aarch64 self-host on Pi (pin v5.6.27) ──
echo "── aarch64 native self-host ──"
sh "$ROOT/tests/regression-aarch64-native-selfhost.sh" > /tmp/audit_ns_$$ 2>&1
ns_result=$?
check "native cc5 self-hosts byte-identical on Pi (pin v5.6.27)" "$ns_result"
if [ "$ns_result" -ne 0 ]; then cat /tmp/audit_ns_$$; fi
rm -f /tmp/audit_ns_$$
echo ""

# ── 4p. macOS arm64 runtime exit code (pin v5.6.28) ──
echo "── Mach-O arm64 runtime ──"
sh "$ROOT/tests/regression-macho-exit.sh" > /tmp/audit_mo_$$ 2>&1
mo_result=$?
check "Mach-O arm64 syscall(60,42) → exit 42 on ecb (pin v5.6.28)" "$mo_result"
if [ "$mo_result" -ne 0 ]; then cat /tmp/audit_mo_$$; fi
rm -f /tmp/audit_mo_$$
echo ""

# ── 4q. Windows 11 PE runtime exit code (pin v5.6.29) ──
echo "── PE32+ Windows runtime ──"
sh "$ROOT/tests/regression-pe-exit.sh" > /tmp/audit_pe_$$ 2>&1
pe_result=$?
check "PE syscall(60,42) → exit 42 on cass (pin v5.6.29)" "$pe_result"
if [ "$pe_result" -ne 0 ]; then cat /tmp/audit_pe_$$; fi
rm -f /tmp/audit_pe_$$
echo ""

# ── 5. Format Check ──
echo "── Format ──"
if [ -x "$CYRFMT" ]; then
    if command -v audit_fmt_walk > /dev/null 2>&1; then
        audit_fmt_walk "$CYRFMT" "$ROOT/lib"
        check "format (stdlib)" "$AW_FMT_FAIL"
        if [ "$AW_FMT_SKIPPED" -gt 0 ]; then
            printf "    (%d dep files skipped)\n" "$AW_FMT_SKIPPED"
        fi
    else
        echo "  skip: scripts/lib/audit-walk.sh not found"
    fi
else
    echo "  skip: cyrfmt not built"
fi
echo ""

# ── 5. Lint ──
echo "── Lint ──"
if [ -x "$CYRLINT" ]; then
    if command -v audit_lint_walk > /dev/null 2>&1; then
        audit_lint_walk "$CYRLINT" "$ROOT/lib"
        if [ "$AW_LINT_TOTAL" -gt 0 ]; then
            echo "  $AW_LINT_TOTAL warnings"
            check "lint (stdlib)" "1"
        else
            check "lint (stdlib)" "0"
        fi
        if [ "$AW_LINT_SKIPPED" -gt 0 ]; then
            printf "    (%d dep files skipped)\n" "$AW_LINT_SKIPPED"
        fi
    else
        echo "  skip: scripts/lib/audit-walk.sh not found"
    fi
else
    echo "  skip: cyrlint not built"
fi
echo ""

# ── Summary ──
echo "════════════════════════"
printf "%d passed, %d failed (%d total)\n" "$pass" "$fail" "$total"
exit $fail
