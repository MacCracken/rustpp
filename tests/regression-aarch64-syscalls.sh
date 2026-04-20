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

exit $fail
