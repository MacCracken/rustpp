# Libro Unblock — v3.4.20 P(-1) Review

## Status: **Root cause identified, fix proposed, WIP separation needed**

## Context

Libro (cryptographic audit chain, SHA-256 hash-linked event log) has been
blocked from release for months — "still struggling to get out" per the
user. Cyrius v3.4.20's P(-1) scaffold-hardening pass included a libro
review, and the blockers are now understood.

Empirically verified against Cyrius 3.4.20 on committed libro state plus
the three-line include fix: **202/202 tests pass, exit 0**.

## Root causes (ordered by impact)

### 1. Three missing `include` directives in `src/main.cyr`

Libro's `main.cyr` references `patra_init()`, `patra_open()`,
`patra_exec()`, `patrastore_open()`, `patrastore_append()`, `patrastore_*`
wrappers, plus internal helpers that patra uses (`fmt_int_buf`) — but
never includes the files that define them.

Cyrius treats undefined functions as warnings, not errors. Unresolved fns
get NULL stub offsets (`fn_offsets[fi] = -1`), and when called at runtime,
they jump to NULL → SIGSEGV with no diagnostic tracing back to "you
forgot an include."

Missing includes:

| Include | What it provides | Where libro uses it |
|---------|-------|-------|
| `lib/patra.cyr` | `patra_init`, `patra_open`, `patra_exec`, `patra_close`, `PATRA_OK` | `src/patra_store.cyr` wraps these; `main.cyr` test group calls `patra_init()` |
| `lib/fmt.cyr` | `fmt_int_buf` | Patra internally calls it during SQL execution (integer column serialization) |
| `src/patra_store.cyr` | `patrastore_open`, `patrastore_append`, `patrastore_load_all`, `patrastore_is_empty`, `patrastore_len`, `patrastore_close`, `patrastore_query`, `patrastore_by_source`, `patrastore_begin`, `patrastore_commit` | All PatraStore test functions (`test_patrastore_*`) |

### 2. Uncommitted WIP crashes the full suite

Libro's working tree has ~385 uncommitted lines in a new "Gap coverage"
test group (`test_retention_keep_duration`, `test_retention_keep_after`,
`test_retention_keep_duration_future`, `test_compliance_presets`,
`test_query_time_range`, `test_query_agent_id`, `test_export_csv_special_chars`,
`test_entry_validated_too_long`, `test_chain_by_agent`, `test_merkle_large_tree`,
`test_anchor_receipt`, `test_stream_recv_drain`). These tests work
individually but crash when combined with the rest of the suite —
**even after the include fix is applied**. The crash surfaces in the
PatraStore section as a silent SIGSEGV with 0 PASS/0 FAIL reported.

Bisection was inconclusive; the crash is cumulative across prior test
groups rather than traceable to one specific test. Classic heisenbug —
memory state from earlier tests corrupts something that PatraStore's
`test_patrastore_append_load` hits.

### 3. Latent patra bug: silent SIGSEGV if `patra_init()` not called

`lib/patra.cyr` declares `var _sql_toks = 0;` and expects the consumer
to call `patra_init()` → `_sql_init()` to allocate the actual token
buffer via `fl_alloc()`. If `patra_open()` is called before `patra_init()`,
the first `sql_tokenize()` does `store64(0 + offset, ...)` and segfaults.

This is the same silent-failure pattern as v3.4.19's input_buf truncation.
Libro actually calls `patra_init()` correctly at the right place in its
test suite — but because of #1 above, `patra_init()` was resolving to a
NULL stub, so patra's internal state was never actually initialized.

**Upstream fix recommendation:** `patra_open()` should either call
`patra_init()` unconditionally, or `sql_tokenize()` should lazy-init
on first use, or both should emit a clear diagnostic when called
uninitialized. Tracked as a patra 0.15.x item, not fixed in Cyrius
v3.4.20 since `lib/patra.cyr` is a dep bundle owned upstream.

## Fix plan

### Phase 1: Commit the include fix (unblocks libro)

One-line changes to `libro/src/main.cyr`:

```diff
  include "lib/chrono.cyr"
+ include "lib/fmt.cyr"   # patra needs fmt_int_buf

+ include "lib/patra.cyr" # SQL-backed audit log backend

  include "lib/sigil.cyr"

  ...
  include "src/file_store.cyr"
+ include "src/patra_store.cyr"
  include "src/streaming.cyr"
```

After this commit: libro builds with **zero warnings**, 202/202 tests
pass (against the currently-committed test suite).

### Phase 2: Separate or complete the WIP gap-coverage tests

The 385-line uncommitted "Gap coverage" additions either need to be
completed (find and fix the cumulative-state bug) or reverted (ship
libro without them, add them later with proper isolation).

Recommended: revert them to a separate branch, ship libro 1.0.2 or
1.1.0 with just the include fix, then reland the gap-coverage tests
one-at-a-time on main with proper isolation (each test should use
unique temp-file paths and not assume clean state from prior tests).

### Phase 3: Upstream the patra init bug

File a patra issue: `patra_open()` must not require a separate
`patra_init()` call, or it must diagnose the missing init rather
than segfault. Separate patra dep release.

## Reproduction

```bash
cd ~/Repos/libro

# Committed version (as of today) crashes because of missing includes:
cat src/main.cyr | cc3 > /tmp/libro_orig 2>&1
chmod +x /tmp/libro_orig
/tmp/libro_orig  # → SIGSEGV or "undefined function" warnings

# Apply the three-line include fix, keep WIP stashed:
git stash push -- src/main.cyr
# (apply the include fix to the now-committed-state file)
sed -i '/^include "lib\/chrono.cyr"/a include "lib/patra.cyr"' src/main.cyr
sed -i '/^include "lib\/str.cyr"/a include "lib/fmt.cyr"' src/main.cyr
sed -i '/^include "src\/file_store.cyr"/a include "src/patra_store.cyr"' src/main.cyr

cat src/main.cyr | cc3 > /tmp/libro_fixed 2>&1
chmod +x /tmp/libro_fixed
/tmp/libro_fixed  # → "202 passed, 0 failed (202 total)", exit 0

# Restore WIP:
git checkout src/main.cyr
git stash pop
```

## Timeline

- **Libro v1.0.1** (released): current state, missing includes, crash
  silently with "undefined function" warnings.
- **Libro v1.0.2** (proposed, ~minutes of work): apply the three-line
  include fix. Ship the 202-test suite. Close the "still struggling to
  get out" status.
- **Libro v1.1.0** (later): reland the gap-coverage additions with
  test isolation. Bump test count to ~220+.
- **Patra v0.15.x** (upstream, later): fix the silent-init SIGSEGV.
