#!/bin/sh
# Regression: aarch64 Linux syscall stdlib + post-clone thread
# trampoline (v5.4.11).
#
# Covers the yukti + majra bugs that motivated v5.4.11:
#
#   yukti: lib/syscalls.cyr pre-v5.4.11 was hardcoded to Linux
#   x86_64 syscall numbers (SYS_OPEN=2, SYS_STAT=4, …). Cross-
#   built aarch64 binaries inherited these verbatim — `syscall(4,
#   …)` invokes `pivot_root` on aarch64 instead of `stat`, which
#   SIGSEGV'd yukti's `test_query_permissions_dev_null` on real
#   Pi hardware. v5.4.11 splits into per-arch peers behind the
#   `lib/syscalls.cyr` selector; aarch64 gets its generic-table
#   numbers + at-family wrappers (openat / newfstatat / mkdirat /
#   unlinkat / pipe2 / clone(SIGCHLD) / ppoll).
#
#   majra: lib/thread.cyr v5.4.10 fixed the x86 post-clone child
#   trampoline (inline asm, no cyrius locals after syscall) but
#   left aarch64 stubbed to return -1 pending v5.4.11's syscall
#   split (`SYS_CLONE=56` in pre-v5.4.11 was `io_setup` on
#   aarch64). v5.4.11 lands the aarch64 asm transpose — `svc #0`,
#   args in `x0..x4`, `blr x9`, `SYS_CLONE=220`, `SYS_EXIT=93`.
#
# Test strategy: cross-build two minimal programs, scp to a real
# aarch64 host, run, assert exit codes and output. Skips cleanly
# if:
#   - cc5_aarch64 isn't in build/ (separate CI tier handles that),
#   - sshpass isn't installed,
#   - the SSH target doesn't respond.
# This keeps cyrius CI hermetic while still giving a local gate
# for anyone with a Pi on their desk.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CC_ARM="$ROOT/build/cc5_aarch64"
# Expect an ~/.ssh/config entry named `pi` with key-based auth (no
# password). Override with SSH_TARGET if your setup differs.
SSH_TARGET="${SSH_TARGET:-pi}"

if [ ! -x "$CC_ARM" ]; then
    echo "  skip: $CC_ARM not present (cross-compiler not built)"
    exit 0
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" 'echo alive' >/dev/null 2>&1; then
    echo "  skip: $SSH_TARGET unreachable (no aarch64 runner available)"
    exit 0
fi

TMP=$(mktemp -d)
trap "rm -rf $TMP; ssh -o BatchMode=yes $SSH_TARGET 'rm -f /tmp/cyr_aarch64_regr_*' 2>/dev/null || true" EXIT

fail=0

# ---- Test 1: syscall stdlib — sys_open/sys_read/sys_write/sys_close
#      The aarch64 peer routes sys_open through openat(AT_FDCWD, …);
#      SYS_READ=63 (not 0), SYS_WRITE=64 (not 1), SYS_CLOSE=57
#      (not 3). Any number inherited from x86_64 would invoke a
#      different syscall and fail.
cat > "$TMP/sys_open_test.cyr" <<'EOF'
include "lib/syscalls.cyr"

fn main() {
    var fd = sys_open("/etc/hostname", O_RDONLY, 0);
    if (fd < 0) { syscall(SYS_EXIT, 11); }  # open failed
    var buf[256];
    var n = sys_read(fd, &buf, 255);
    sys_close(fd);
    if (n <= 0) { syscall(SYS_EXIT, 12); }  # read failed
    sys_write(STDOUT_FD, &buf, n);
    syscall(SYS_EXIT, 0);
}
main();
EOF
cat "$TMP/sys_open_test.cyr" | "$CC_ARM" > "$TMP/sys_open_test" 2>/dev/null
chmod +x "$TMP/sys_open_test"
scp -q "$TMP/sys_open_test" "$SSH_TARGET:/tmp/cyr_aarch64_regr_1" >/dev/null 2>&1
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_aarch64_regr_1; /tmp/cyr_aarch64_regr_1')
rc=$?
set -e
expected=$(ssh "$SSH_TARGET" 'cat /etc/hostname')
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test1 (syscall stdlib): exit=$rc (expected 0)"
    fail=$((fail+1))
elif [ "$out" != "$expected" ]; then
    echo "  FAIL test1 (syscall stdlib): got '$out' expected '$expected'"
    fail=$((fail+1))
fi

# ---- Test 2: thread spawn + join
#      Exercises the v5.4.11 aarch64 inline-asm trampoline in
#      _thread_spawn (clone → svc #0, child pops fp/arg from new
#      sp, blr, SYS_EXIT=93). Without the trampoline v5.4.10
#      stubbed _thread_spawn to return -1 on aarch64; with it
#      broken the child SIGSEGV'd (mirrors the v5.4.10 x86 fix).
cat > "$TMP/thread_test.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"
include "lib/thread.cyr"

fn _worker(arg) {
    syscall(SYS_EXIT, 0);
    return 0;
}

fn main() {
    alloc_init();
    var t = thread_create(&_worker, 0);
    if (t == 0) { syscall(SYS_EXIT, 21); }  # spawn failed
    var rj = thread_join(t);
    if (rj != 0) { syscall(SYS_EXIT, 22); }  # join failed
    sys_write(STDOUT_FD, "joined\n", 7);
    syscall(SYS_EXIT, 0);
}
main();
EOF
cat "$TMP/thread_test.cyr" | "$CC_ARM" > "$TMP/thread_test" 2>/dev/null
chmod +x "$TMP/thread_test"
scp -q "$TMP/thread_test" "$SSH_TARGET:/tmp/cyr_aarch64_regr_2" >/dev/null 2>&1
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_aarch64_regr_2; /tmp/cyr_aarch64_regr_2')
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test2 (thread spawn+join): exit=$rc (expected 0)"
    fail=$((fail+1))
elif [ "$out" != "joined" ]; then
    echo "  FAIL test2 (thread spawn+join): got '$out' expected 'joined'"
    fail=$((fail+1))
fi

# ---- Test 3 (v5.5.18): alloc stress — 256 × 1KB blocks
#      Exercises lib/alloc.cyr's brk-based Linux path on real Pi.
#      A smoke test the bump allocator survives 256 back-to-back
#      alloc() calls without falling off the end of the heap's
#      initial 1 MB window; the heap has never been asked for
#      anything larger in automated testing.
cat > "$TMP/alloc_test.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"

fn main() {
    alloc_init();
    var i = 0;
    var last = 0;
    while (i < 256) {
        var p = alloc(1024);
        if (p == 0) { syscall(SYS_EXIT, 31); }
        store64(p, i);
        last = p;
        i = i + 1;
    }
    if (load64(last) != 255) { syscall(SYS_EXIT, 32); }
    sys_write(STDOUT_FD, "alloc_ok\n", 9);
    syscall(SYS_EXIT, 0);
}
main();
EOF
cat "$TMP/alloc_test.cyr" | "$CC_ARM" > "$TMP/alloc_test" 2>/dev/null
chmod +x "$TMP/alloc_test"
scp -q "$TMP/alloc_test" "$SSH_TARGET:/tmp/cyr_aarch64_regr_3" >/dev/null 2>&1
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_aarch64_regr_3; /tmp/cyr_aarch64_regr_3')
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test3 (alloc stress): exit=$rc (expected 0)"
    fail=$((fail+1))
elif [ "$out" != "alloc_ok" ]; then
    echo "  FAIL test3 (alloc stress): got '$out' expected 'alloc_ok'"
    fail=$((fail+1))
fi

# ---- Test 4 (v5.5.18): fs roundtrip — write-then-read a scratch file
#      Exercises lib/io.cyr's file_open/file_write/file_read/file_close
#      on real Pi. Pre-v5.5.18 lib/io.cyr hardcoded Linux x86_64
#      syscall numbers (2/3/0/1) — those mean io_setup/io_destroy/
#      io_submit/io_cancel on aarch64, so file_open returned -1
#      immediately. v5.5.18 routes io.cyr through the per-arch
#      sys_open/sys_close/sys_read/sys_write wrappers that already
#      existed for the same-category v5.4.11 yukti fix.
cat > "$TMP/fs_test.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/io.cyr"

fn main() {
    var path = "/tmp/cyrius_regr_fs_probe.txt";
    var msg = "hello_fs\n";
    var mlen = 9;
    var fd = file_open(path, O_WRONLY | O_CREAT | O_TRUNC, 0x1A4);
    if (fd < 0) { syscall(60, 41); }
    var w = file_write(fd, msg, mlen);
    file_close(fd);
    if (w != mlen) { syscall(60, 42); }
    var rfd = file_open(path, O_RDONLY, 0);
    if (rfd < 0) { syscall(60, 43); }
    var buf[64];
    var n = file_read(rfd, &buf, 64);
    file_close(rfd);
    if (n != mlen) { syscall(60, 44); }
    var i = 0;
    while (i < mlen) {
        if (load8(&buf + i) != load8(msg + i)) { syscall(60, 45); }
        i = i + 1;
    }
    syscall(1, 1, "fs_ok\n", 6);
    syscall(60, 0);
}
main();
EOF
cat "$TMP/fs_test.cyr" | "$CC_ARM" > "$TMP/fs_test" 2>/dev/null
chmod +x "$TMP/fs_test"
scp -q "$TMP/fs_test" "$SSH_TARGET:/tmp/cyr_aarch64_regr_4" >/dev/null 2>&1
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_aarch64_regr_4; /tmp/cyr_aarch64_regr_4')
rc=$?
ssh "$SSH_TARGET" 'rm -f /tmp/cyrius_regr_fs_probe.txt' >/dev/null 2>&1
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test4 (fs roundtrip): exit=$rc (expected 0)"
    fail=$((fail+1))
elif [ "$out" != "fs_ok" ]; then
    echo "  FAIL test4 (fs roundtrip): got '$out' expected 'fs_ok'"
    fail=$((fail+1))
fi

# ---- Test 5 (v5.5.18): multi-thread spawn (4 × parallel)
#      Scales test 2 from 1 thread to 4. Confirms that the v5.4.11
#      aarch64 clone trampoline, v5.4.10 futex-private alignment,
#      and `lib/alloc.cyr`'s brk-based heap all survive parallel
#      thread creation + join. Note the `handles[32]` sizing —
#      cyrius `var[N]` is **bytes** not elements (4 threads × 8 B
#      each = 32 B); easy gotcha to miss, and using `var[4]` silently
#      clobbers adjacent globals when loops store past the 4th byte.
cat > "$TMP/mt_test.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"
include "lib/thread.cyr"

fn _worker(arg) {
    var x = 0;
    var i = 0;
    while (i < 100) { x = x + i; i = i + 1; }
    syscall(SYS_EXIT, 0);
    return 0;
}

fn main() {
    alloc_init();
    var handles[32];                       # 4 × 8 B — bytes not elements
    var i = 0;
    while (i < 4) {
        var t = thread_create(&_worker, i);
        if (t == 0) { syscall(SYS_EXIT, 51); }
        store64(&handles + i * 8, t);
        i = i + 1;
    }
    i = 0;
    while (i < 4) {
        var rj = thread_join(load64(&handles + i * 8));
        if (rj != 0) { syscall(SYS_EXIT, 52); }
        i = i + 1;
    }
    sys_write(STDOUT_FD, "mt_ok\n", 6);
    syscall(SYS_EXIT, 0);
}
main();
EOF
cat "$TMP/mt_test.cyr" | "$CC_ARM" > "$TMP/mt_test" 2>/dev/null
chmod +x "$TMP/mt_test"
scp -q "$TMP/mt_test" "$SSH_TARGET:/tmp/cyr_aarch64_regr_5" >/dev/null 2>&1
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_aarch64_regr_5; /tmp/cyr_aarch64_regr_5')
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test5 (multi-thread × 4): exit=$rc (expected 0)"
    fail=$((fail+1))
elif [ "$out" != "mt_ok" ]; then
    echo "  FAIL test5 (multi-thread × 4): got '$out' expected 'mt_ok'"
    fail=$((fail+1))
fi

# ---- Test 6 (v5.5.30): thread_local slots via TPIDR_EL0
#      Verifies `lib/thread_local.cyr`'s aarch64 path — `msr
#      TPIDR_EL0, x0` install + `mrs x1, TPIDR_EL0` + `ldr/str
#      [x1, x0, lsl #3]` slot access. Also exercises CLONE_SETTLS
#      wiring in `_thread_spawn` for aarch64 (kernel copies tls
#      arg into TPIDR_EL0 at clone time).
cat > "$TMP/tl_test.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"
include "lib/thread.cyr"
include "lib/thread_local.cyr"

var _tl_mtx = 0;
var _tl_mismatches = 0;

fn _tl_worker(arg) {
    var tid = gettid();
    thread_local_set(0, tid);
    var i = 0;
    while (i < 1000) { i = i + 1; }
    if (thread_local_get(0) != tid) {
        mutex_lock(_tl_mtx);
        _tl_mismatches = _tl_mismatches + 1;
        mutex_unlock(_tl_mtx);
    }
    syscall(SYS_EXIT, 0);
    return 0;
}

fn main() {
    alloc_init();
    if (thread_local_init() != 1) { syscall(SYS_EXIT, 61); }
    thread_local_set(0, 0x5A5A5A5A);
    thread_local_set(7, 0xCAFEBABE);
    if (thread_local_get(0) != 0x5A5A5A5A) { syscall(SYS_EXIT, 62); }
    if (thread_local_get(7) != 0xCAFEBABE) { syscall(SYS_EXIT, 63); }
    _tl_mtx = mutex_new();
    var t1 = thread_create(&_tl_worker, 0);
    var t2 = thread_create(&_tl_worker, 0);
    var t3 = thread_create(&_tl_worker, 0);
    var t4 = thread_create(&_tl_worker, 0);
    thread_join(t1); thread_join(t2); thread_join(t3); thread_join(t4);
    if (_tl_mismatches != 0) { syscall(SYS_EXIT, 64); }
    if (thread_local_get(0) != 0x5A5A5A5A) { syscall(SYS_EXIT, 65); }
    sys_write(STDOUT_FD, "tl_ok\n", 6);
    syscall(SYS_EXIT, 0);
}
main();
EOF
cat "$TMP/tl_test.cyr" | "$CC_ARM" > "$TMP/tl_test" 2>/dev/null
chmod +x "$TMP/tl_test"
scp -q "$TMP/tl_test" "$SSH_TARGET:/tmp/cyr_aarch64_regr_6" >/dev/null 2>&1
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_aarch64_regr_6; /tmp/cyr_aarch64_regr_6')
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test6 (thread_local via TPIDR_EL0): exit=$rc (expected 0)"
    fail=$((fail+1))
elif [ "$out" != "tl_ok" ]; then
    echo "  FAIL test6 (thread_local via TPIDR_EL0): got '$out' expected 'tl_ok'"
    fail=$((fail+1))
fi

# ---- Test 7 (v5.5.31): atomics LL-SC encoding verification
#      Verifies `lib/atomic.cyr`'s aarch64 path — `ldxr` /
#      `stxr` / `clrex` / `cmp` / `b.ne` / `cbnz` / `dmb ish`
#      encodings execute correctly on real Pi 4 (ARMv8.0-A,
#      no LSE atomics). Stresses atomic_cas + atomic_fetch_add
#      under 4-thread contention — without a working LL-SC
#      retry loop, concurrent increments lose updates and the
#      final tally falls short of the expected sum.
cat > "$TMP/at_test.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"
include "lib/atomic.cyr"
include "lib/thread.cyr"

fn _at_worker(arg) {
    var p = arg;
    var i = 0;
    while (i < 500) {
        atomic_fetch_add(p, 1);
        i = i + 1;
    }
    syscall(SYS_EXIT, 0);
    return 0;
}

fn main() {
    alloc_init();
    var p = alloc(8);
    atomic_store(p, 0);
    # CAS success + failure
    if (atomic_cas(p, 0, 100) != 1) { syscall(SYS_EXIT, 71); }
    if (atomic_load(p) != 100) { syscall(SYS_EXIT, 72); }
    if (atomic_cas(p, 999, 200) != 0) { syscall(SYS_EXIT, 73); }
    if (atomic_load(p) != 100) { syscall(SYS_EXIT, 74); }
    # fetch_add basic
    if (atomic_fetch_add(p, 50) != 100) { syscall(SYS_EXIT, 75); }
    if (atomic_load(p) != 150) { syscall(SYS_EXIT, 76); }
    # Reset and stress under contention
    atomic_store(p, 0);
    var t1 = thread_create(&_at_worker, p);
    var t2 = thread_create(&_at_worker, p);
    var t3 = thread_create(&_at_worker, p);
    var t4 = thread_create(&_at_worker, p);
    thread_join(t1); thread_join(t2); thread_join(t3); thread_join(t4);
    if (atomic_load(p) != 2000) { syscall(SYS_EXIT, 77); }
    atomic_fence();
    sys_write(STDOUT_FD, "at_ok\n", 6);
    syscall(SYS_EXIT, 0);
}
main();
EOF
cat "$TMP/at_test.cyr" | "$CC_ARM" > "$TMP/at_test" 2>/dev/null
chmod +x "$TMP/at_test"
scp -q "$TMP/at_test" "$SSH_TARGET:/tmp/cyr_aarch64_regr_7" >/dev/null 2>&1
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_aarch64_regr_7; /tmp/cyr_aarch64_regr_7')
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test7 (atomics LL-SC): exit=$rc (expected 0)"
    fail=$((fail+1))
elif [ "$out" != "at_ok" ]; then
    echo "  FAIL test7 (atomics LL-SC): got '$out' expected 'at_ok'"
    fail=$((fail+1))
fi

# ---- Test 8 (v5.5.32): stdlib thread-safety pattern
#      Verifies mutex-wrapped hashmap / vec under 4-thread
#      contention works on aarch64 — exercises the full stack
#      (atomic_cas, mutex_lock, map_u64_set, vec_push) on
#      ARMv8.0-A without LSE. Pre-v5.5.31 would lose updates
#      to the memory-model race in mutex_unlock; v5.5.31's
#      fences and this test together confirm the pattern is
#      field-ready.
cat > "$TMP/ts_test.cyr" <<'EOF'
include "lib/syscalls.cyr"
include "lib/alloc.cyr"
include "lib/string.cyr"
include "lib/vec.cyr"
include "lib/hashmap.cyr"
include "lib/atomic.cyr"
include "lib/thread.cyr"

var _ts_mtx = 0;
var _ts_map = 0;

fn _ts_worker(arg) {
    var tid = arg;
    var i = 0;
    while (i < 50) {
        mutex_lock(_ts_mtx);
        map_u64_set(_ts_map, tid * 1000 + i, tid * 10000 + i);
        mutex_unlock(_ts_mtx);
        i = i + 1;
    }
    syscall(SYS_EXIT, 0);
    return 0;
}

fn main() {
    alloc_init();
    _ts_mtx = mutex_new();
    _ts_map = map_u64_new();
    var t1 = thread_create(&_ts_worker, 1);
    var t2 = thread_create(&_ts_worker, 2);
    var t3 = thread_create(&_ts_worker, 3);
    var t4 = thread_create(&_ts_worker, 4);
    thread_join(t1); thread_join(t2); thread_join(t3); thread_join(t4);
    if (map_u64_size(_ts_map) != 200) { syscall(SYS_EXIT, 81); }
    var tid = 1;
    while (tid < 5) {
        var i = 0;
        while (i < 50) {
            if (map_u64_get(_ts_map, tid * 1000 + i) != tid * 10000 + i) {
                syscall(SYS_EXIT, 82);
            }
            i = i + 1;
        }
        tid = tid + 1;
    }
    sys_write(STDOUT_FD, "ts_ok\n", 6);
    syscall(SYS_EXIT, 0);
}
main();
EOF
cat "$TMP/ts_test.cyr" | "$CC_ARM" > "$TMP/ts_test" 2>/dev/null
chmod +x "$TMP/ts_test"
scp -q "$TMP/ts_test" "$SSH_TARGET:/tmp/cyr_aarch64_regr_8" >/dev/null 2>&1
set +e
out=$(ssh "$SSH_TARGET" 'chmod +x /tmp/cyr_aarch64_regr_8; /tmp/cyr_aarch64_regr_8')
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
    echo "  FAIL test8 (thread-safety pattern): exit=$rc (expected 0)"
    fail=$((fail+1))
elif [ "$out" != "ts_ok" ]; then
    echo "  FAIL test8 (thread-safety pattern): got '$out' expected 'ts_ok'"
    fail=$((fail+1))
fi

exit $fail
