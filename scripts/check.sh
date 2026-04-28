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

# ── 4e2. Mach-O aarch64 cross-build smoke (5.6.40) ──
echo "── Mach-O aarch64 cross-build ──"
sh "$ROOT/tests/regression-macho-cross-build.sh" > /tmp/audit_mc_$$ 2>&1
mc_result=$?
check "main_aarch64_macho.cyr compiles to ELF" "$mc_result"
if [ "$mc_result" -ne 0 ]; then cat /tmp/audit_mc_$$; fi
rm -f /tmp/audit_mc_$$
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

# ── 4o. native aarch64 self-host on Pi (pin v5.6.32) ──
echo "── aarch64 native self-host ──"
sh "$ROOT/tests/regression-aarch64-native-selfhost.sh" > /tmp/audit_ns_$$ 2>&1
ns_result=$?
check "native cc5 self-hosts byte-identical on Pi (pin v5.6.32)" "$ns_result"
if [ "$ns_result" -ne 0 ]; then cat /tmp/audit_ns_$$; fi
rm -f /tmp/audit_ns_$$
echo ""

# ── 4p. macOS arm64 runtime exit code (pin v5.6.33) ──
echo "── Mach-O arm64 runtime ──"
sh "$ROOT/tests/regression-macho-exit.sh" > /tmp/audit_mo_$$ 2>&1
mo_result=$?
check "Mach-O arm64 syscall(60,42) → exit 42 on ecb (pin v5.6.33)" "$mo_result"
if [ "$mo_result" -ne 0 ]; then cat /tmp/audit_mo_$$; fi
rm -f /tmp/audit_mo_$$
echo ""

# ── 4q. Windows 11 PE runtime exit code (pin v5.6.36) ──
echo "── PE32+ Windows runtime ──"
sh "$ROOT/tests/regression-pe-exit.sh" > /tmp/audit_pe_$$ 2>&1
pe_result=$?
check "PE syscall(60,42) → exit 42 on cass (pin v5.6.36)" "$pe_result"
if [ "$pe_result" -ne 0 ]; then cat /tmp/audit_pe_$$; fi
rm -f /tmp/audit_pe_$$
echo ""

# ── 4q'. sit 100-commit fixture: status + fsck (pin v5.6.35) ──
echo "── sit 100-commit fixture ──"
sh "$ROOT/tests/regression-sit-status.sh" > /tmp/audit_ss_$$ 2>&1
ss_result=$?
check "sit fsck on 100-commit fixture reports 0 bad (pin v5.6.35; sankoch deflate)" "$ss_result"
if [ "$ss_result" -ne 0 ]; then cat /tmp/audit_ss_$$; fi
rm -f /tmp/audit_ss_$$
echo ""

# ── 4q''. TLS live handshake to 1.1.1.1:443 (pin v5.6.37) ──
echo "── TLS live ──"
sh "$ROOT/tests/regression-tls-live.sh" > /tmp/audit_tl_$$ 2>&1
tl_result=$?
check "libssl via fdlopen: full TLS round-trip on 1.1.1.1:443 (pin v5.6.37)" "$tl_result"
if [ "$tl_result" -ne 0 ]; then cat /tmp/audit_tl_$$; fi
rm -f /tmp/audit_tl_$$
echo ""

# ── 4q'''. TS lexer integration via cc5 --lex-ts (v5.7.2 P1.7) ──
echo "── TS lexer (cyrius-ts) ──"
sh "$ROOT/tests/regression-ts-lex.sh" > /tmp/audit_tsl_$$ 2>&1
tsl_result=$?
check "cc5 --lex-ts on synthetic TS sample (v5.7.2 P1.7 acceptance)" "$tsl_result"
if [ "$tsl_result" -ne 0 ]; then cat /tmp/audit_tsl_$$; fi
rm -f /tmp/audit_tsl_$$
echo ""

# ── 4q''''. TS parser SY acceptance gate (v5.7.2 P2.7) ──
echo "── TS parser (SY acceptance) ──"
sh "$ROOT/tests/regression-ts-parse.sh" > /tmp/audit_tsp_$$ 2>&1
tsp_result=$?
check "cc5 --parse-ts vs SY .ts corpus ≥98%% baseline (v5.7.3 P3.1)" "$tsp_result"
if [ "$tsp_result" -ne 0 ]; then cat /tmp/audit_tsp_$$; fi
rm -f /tmp/audit_tsp_$$
echo ""

# ── 4q'''''. TS parser .tsx (JSX) acceptance gate (v5.7.3 P3.3) ──
echo "── TS parser .tsx (JSX) ──"
sh "$ROOT/tests/regression-ts-parse-tsx.sh" > /tmp/audit_tsx_$$ 2>&1
tsx_result=$?
check "cc5 --parse-ts vs SY .tsx corpus ≥98%% baseline (v5.7.3 P3.3)" "$tsx_result"
if [ "$tsx_result" -ne 0 ]; then cat /tmp/audit_tsx_$$; fi
rm -f /tmp/audit_tsx_$$
echo ""

# ── 4r. Bare-truthy after fn-call (v5.6.21 codegen-bug fix) ──
echo "── Bare-truthy after fn-call ──"
sh "$ROOT/tests/regression-truthy-after-fncall.sh" > /tmp/audit_tf_$$ 2>&1
tf_result=$?
check "bare-truthy `if (r)` after fn-call branches correctly (v5.6.21 fix)" "$tf_result"
if [ "$tf_result" -ne 0 ]; then cat /tmp/audit_tf_$$; fi
rm -f /tmp/audit_tf_$$
echo ""

# ── 4s. fn-name collision warning (v5.7.9) ──
echo "── fn-name collision warning ──"
sh "$ROOT/tests/regression-fn-collision.sh" > /tmp/audit_fc_$$ 2>&1
fc_result=$?
check "duplicate fn warns; forward-decl no false-positive (v5.7.9)" "$fc_result"
if [ "$fc_result" -ne 0 ]; then cat /tmp/audit_fc_$$; fi
rm -f /tmp/audit_fc_$$
echo ""

# ── 4t. input_buf 1 MB cap (v5.7.10) ──
echo "── input_buf 1 MB cap ──"
sh "$ROOT/tests/regression-input-1mb.sh" > /tmp/audit_i1m_$$ 2>&1
i1m_result=$?
check "cc5 accepts >512 KB source (heap reshuffle, v5.7.10)" "$i1m_result"
if [ "$i1m_result" -ne 0 ]; then cat /tmp/audit_i1m_$$; fi
rm -f /tmp/audit_i1m_$$
echo ""

# ── 4u. main_cx.cyr build + startup (v5.7.11 — drift gate) ──
echo "── cyrius-x bytecode entry ──"
sh "$ROOT/tests/regression-cx-build.sh" > /tmp/audit_cx_$$ 2>&1
cx_result=$?
check "cc5 builds main_cx.cyr; cc5_cx starts clean (v5.7.11; bytecode correctness pinned v5.7.12)" "$cx_result"
if [ "$cx_result" -ne 0 ]; then cat /tmp/audit_cx_$$; fi
rm -f /tmp/audit_cx_$$
echo ""

# ── 4v. cyrius-x bytecode is x86-noise-free (v5.7.12 — path B) ──
echo "── cyrius-x bytecode cleanliness ──"
sh "$ROOT/tests/regression-cx-roundtrip.sh" > /tmp/audit_cxr_$$ 2>&1
cxr_result=$?
check "cc5_cx output: well-formed CYX, no x86 noise; cxvm consumes (v5.7.12 path B)" "$cxr_result"
if [ "$cxr_result" -ne 0 ]; then cat /tmp/audit_cxr_$$; fi
rm -f /tmp/audit_cxr_$$
echo ""

# ── 4w. String-literal escape reject cases (v5.7.13) ──
echo "── String-escape rejects ──"
sh "$ROOT/tests/regression-string-escapes.sh" > /tmp/audit_se_$$ 2>&1
se_result=$?
check "lex rejects malformed \\x## / \\u#### / \\u{...} + surrogates (v5.7.13)" "$se_result"
if [ "$se_result" -ne 0 ]; then cat /tmp/audit_se_$$; fi
rm -f /tmp/audit_se_$$
echo ""

# ── 4x. Transitive cyrius deps resolution (v5.7.14) ──
echo "── cyrius deps transitive ──"
sh "$ROOT/tests/regression-deps-transitive.sh" > /tmp/audit_dt_$$ 2>&1
dt_result=$?
check "cyrius deps walks [deps.X] transitively (3-level + diamond + cycle + rel-path; v5.7.14)" "$dt_result"
if [ "$dt_result" -ne 0 ]; then cat /tmp/audit_dt_$$; fi
rm -f /tmp/audit_dt_$$
echo ""

# ── 4y. cyrius init --lib/--bin scaffold (v5.7.15) ──
echo "── cyrius init --lib/--bin ──"
sh "$ROOT/tests/regression-init-lib-bin.sh" > /tmp/audit_ilb_$$ 2>&1
ilb_result=$?
check "cyrius init --lib emits programs/smoke.cyr + [lib]; --bin/bare keep binary shape (v5.7.15)" "$ilb_result"
if [ "$ilb_result" -ne 0 ]; then cat /tmp/audit_ilb_$$; fi
rm -f /tmp/audit_ilb_$$
echo ""

# ── 4z. cyrius init / port doc-tree per first-party-documentation.md (v5.7.16) ──
echo "── cyrius init/port doc-tree ──"
sh "$ROOT/tests/regression-init-doctree.sh" > /tmp/audit_dt2_$$ 2>&1
dt2_result=$?
check "cyrius init/port emit adr/architecture/guides/examples/development + CLAUDE.md (v5.7.16)" "$dt2_result"
if [ "$dt2_result" -ne 0 ]; then cat /tmp/audit_dt2_$$; fi
rm -f /tmp/audit_dt2_$$
echo ""

# ── 4aa. struct cap 64 → 256 + dump-on-overflow diagnostic (v5.7.17) ──
echo "── struct cap raise + diag ──"
sh "$ROOT/tests/regression-struct-cap.sh" > /tmp/audit_sc_$$ 2>&1
sc_result=$?
check "200-struct compile clean; 257-struct overflow dumps registered names (v5.7.17; kybernet)" "$sc_result"
if [ "$sc_result" -ne 0 ]; then cat /tmp/audit_sc_$$; fi
rm -f /tmp/audit_sc_$$
echo ""

# ── 4ab. Kernel-mode emit order — top-level asm before gvar inits (v5.7.19) ──
echo "── kmode emit order ──"
sh "$ROOT/tests/regression-kmode-emit-order.sh" > /tmp/audit_km_$$ 2>&1
km_result=$?
check "kmode==1: top-level asm emitted before 64-bit gvar inits (v5.7.19; agnos boot)" "$km_result"
if [ "$km_result" -ne 0 ]; then cat /tmp/audit_km_$$; fi
rm -f /tmp/audit_km_$$
echo ""

# ── 4ac. Stdlib doc coverage — every public fn in lib/*.cyr documented ──
# Mirrors the CI doc job. Pinned 2026-04-27 after v5.7.20 ship surfaced
# 28 undocumented json fns that the local audit had no gate for.
echo "── stdlib doc coverage ──"
sh "$ROOT/tests/regression-stdlib-doc-coverage.sh" > /tmp/audit_dc_$$ 2>&1
dc_result=$?
check "every public fn in lib/*.cyr has a leading doc comment (cyrdoc --check; pinned post-v5.7.20)" "$dc_result"
if [ "$dc_result" -ne 0 ]; then cat /tmp/audit_dc_$$; fi
rm -f /tmp/audit_dc_$$
echo ""

# ── 4ad. cyrius fuzz auto-prepend parity (v5.7.21) ──
echo "── cyrius fuzz auto-prepend ──"
sh "$ROOT/tests/regression-fuzz-deps-prepend.sh" > /tmp/audit_fz_$$ 2>&1
fz_result=$?
check "cyrius fuzz manifest-deps auto-prepend parity with test/bench (v5.7.21)" "$fz_result"
if [ "$fz_result" -ne 0 ]; then cat /tmp/audit_fz_$$; fi
rm -f /tmp/audit_fz_$$
echo ""

# ── 4ae. cyrfmt skips braces in `#` comments + `"..."` strings (v5.7.22) ──
echo "── cyrfmt comment/string brace skip ──"
sh "$ROOT/tests/regression-cyrfmt-comment-braces.sh" > /tmp/audit_cf_$$ 2>&1
cf_result=$?
check "cyrfmt skips {/} inside # comments + string literals (v5.7.22; agnos issue)" "$cf_result"
if [ "$cf_result" -ne 0 ]; then cat /tmp/audit_cf_$$; fi
rm -f /tmp/audit_cf_$$
echo ""

# ── 4af. install.sh --refresh-only re-links ~/.cyrius/bin (v5.7.22) ──
echo "── install --refresh-only shim ──"
sh "$ROOT/tests/regression-install-shim-symlink.sh" > /tmp/audit_is_$$ 2>&1
is_result=$?
check "install.sh --refresh-only re-links ~/.cyrius/bin to current version (v5.7.22; H3)" "$is_result"
if [ "$is_result" -ne 0 ]; then cat /tmp/audit_is_$$; fi
rm -f /tmp/audit_is_$$
echo ""

# ── 4ag. cx codegen literal-arg propagation (v5.7.23) ──
echo "── cx syscall literal propagation ──"
sh "$ROOT/tests/regression-cx-syscall-literal.sh" > /tmp/audit_csl_$$ 2>&1
csl_result=$?
check "cc5_cx propagates literal syscall args; cxvm exits with user code (v5.7.23)" "$csl_result"
if [ "$csl_result" -ne 0 ]; then cat /tmp/audit_csl_$$; fi
rm -f /tmp/audit_csl_$$
echo ""

# ── 4ah. TS asserts predicate signatures (v5.7.24) ──
echo "── TS asserts predicate signatures ──"
sh "$ROOT/tests/regression-ts-asserts.sh" > /tmp/audit_tsa_$$ 2>&1
tsa_result=$?
check "cc5 --parse-ts accepts asserts predicate signatures + this-type (v5.7.24)" "$tsa_result"
if [ "$tsa_result" -ne 0 ]; then cat /tmp/audit_tsa_$$; fi
rm -f /tmp/audit_tsa_$$
echo ""

# ── 4ai. TS mapped types + modifiers (v5.7.25) ──
echo "── TS mapped types + modifiers ──"
sh "$ROOT/tests/regression-ts-mapped.sh" > /tmp/audit_tsm_$$ 2>&1
tsm_result=$?
check "cc5 --parse-ts accepts mapped types + as-clause + +/- modifiers (v5.7.25)" "$tsm_result"
if [ "$tsm_result" -ne 0 ]; then cat /tmp/audit_tsm_$$; fi
rm -f /tmp/audit_tsm_$$
echo ""

# ── 4aj. TS 5.0 stage-3 decorators (v5.7.26) ──
echo "── TS decorators ──"
sh "$ROOT/tests/regression-ts-decorators.sh" > /tmp/audit_tsd_$$ 2>&1
tsd_result=$?
check "cc5 --parse-ts accepts TS 5.0 stage-3 decorators (v5.7.26)" "$tsd_result"
if [ "$tsd_result" -ne 0 ]; then cat /tmp/audit_tsd_$$; fi
rm -f /tmp/audit_tsd_$$
echo ""

# ── 4ak. Cross-backend token-offset parity (v5.7.28) ──
echo "── Token-offset parity ──"
sh "$ROOT/tests/regression-cx-token-offsets.sh" > /tmp/audit_to_$$ 2>&1
to_result=$?
check "lex token writes match every backend's TOKTYP / TOKVAL reads (v5.7.28)" "$to_result"
if [ "$to_result" -ne 0 ]; then cat /tmp/audit_to_$$; fi
rm -f /tmp/audit_to_$$
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
