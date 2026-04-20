# majra cbarrier_arrive_and_wait SIGSEGV under multi-threaded arrival

**Discovered:** 2026-04-19 during majra 2.3.0 modernization
**Severity:** Medium (hard failure with a known workaround — non-blocking
`cbarrier_arrive` + polling works; the threaded blocking path does not)
**Affects:** cc5 5.4.8 (most likely all 5.4.x — the relay-dedup class bug
that gated nearby majra code was cc3-era and is now resolved, but the
thread + futex + barrier combination still crashes)

## Summary

majra ships a `ConcurrentBarrierSet` primitive whose blocking entry point
`cbarrier_arrive_and_wait` (in `/home/macro/Repos/majra/src/barrier.cyr`,
line ~240) parks the calling thread on a `SYS_FUTEX` `FUTEX_WAIT` until
all registered participants have arrived, at which point the "release"
path flips a sentinel and issues `FUTEX_WAKE`. This path was previously
gated behind the cc3-era `map_get`-after-`map_set`-in-nested-calls bug
— under cc5 5.4.8 the hashmap surface works cleanly (the relay-dedup
assertions in majra's `test_relay` that lived under the same historical
gate now pass).

The multi-threaded blocking path does **not** pass. When the barrier is
driven by multiple worker threads spawned via `thread_create`, the
process SIGSEGVs shortly after the second thread resumes from its futex
wait. The single-threaded / non-blocking `cbarrier_arrive` variant
(which returns immediately with arrival/expected counts rather than
parking) continues to work correctly, so the hashmap-mutation surface
alone is not the culprit — the crash lives in the thread + futex-wake +
global-state interaction specific to `cbarrier_arrive_and_wait`.

## Reproduction

Minimal standalone reproducer at
`/home/macro/Repos/majra/tests/repro_aaw_crash.cyr`:

```
# Minimal reproducer for cbarrier_arrive_and_wait crash under cc5 5.4.8
#
# Spawns N threads that call cbarrier_arrive_and_wait on a shared
# ConcurrentBarrierSet. The first thread to satisfy the barrier
# wakes the others via futex. Observed: SIGSEGV shortly after the
# second thread resumes.

include "lib/string.cyr"
include "lib/fmt.cyr"
include "lib/alloc.cyr"
include "lib/freelist.cyr"
include "lib/vec.cyr"
include "lib/str.cyr"
include "lib/hashmap.cyr"
include "lib/syscalls.cyr"
include "lib/tagged.cyr"
include "lib/fnptr.cyr"
include "lib/thread.cyr"
include "lib/assert.cyr"

include "src/error.cyr"
include "src/barrier.cyr"

var _rep_cbs = 0;
var _rep_done = 0;
var _rep_mtx = 0;

fn _rep_worker(participant) {
    var ret = cbarrier_arrive_and_wait(_rep_cbs, "sync", participant);
    mutex_lock(_rep_mtx);
    _rep_done = _rep_done + 1;
    mutex_unlock(_rep_mtx);
    return 0;
}

fn main() {
    alloc_init();
    fl_init();

    _rep_cbs = cbarrier_set_new();
    _rep_done = 0;
    _rep_mtx = mutex_new();

    var parts = vec_new();
    vec_push(parts, "t1"); vec_push(parts, "t2"); vec_push(parts, "t3");
    cbarrier_create(_rep_cbs, "sync", parts);

    var t1 = thread_create(&_rep_worker, "t1");
    var t2 = thread_create(&_rep_worker, "t2");
    var t3 = thread_create(&_rep_worker, "t3");

    thread_join(t1);
    thread_join(t2);
    thread_join(t3);

    if (_rep_done != 3) {
        println("FAIL: expected 3 wakeups");
        return 1;
    }
    println("OK: all three threads woke from barrier");
    return 0;
}

var r = main();
syscall(SYS_EXIT, r);
```

Build and run from the majra repo root:

```
cd /home/macro/Repos/majra
cyrius build tests/repro_aaw_crash.cyr build/repro_aaw
./build/repro_aaw
```

**Expected:** `OK: all three threads woke from barrier`, exit code 0.
**Actual:** process SIGSEGVs, core dump, no "OK" line printed.

## Root cause (if known)

Unknown — below is speculation, flagged as such.

The `cbarrier_arrive_and_wait` body (barrier.cyr lines 216-262):

```
# Globals for arrive_and_wait — avoids local clobbering across function calls
var _aaw_result_state = 0;
var _aaw_result_code = 0;

fn _cbarrier_do_arrive(cbs_ptr, name, participant) {
    var barriers = load64(cbs_ptr);
    var state = map_get(barriers, name);
    if (state == 0) {
        _aaw_result_state = 0;
        _aaw_result_code = ERR_BARRIER;
        return 0;
    }
    _set_add(load64(state + 8), participant);
    if (_cbarrier_check_release(state) == 1) {
        _aaw_result_state = 0;
        _aaw_result_code = 0;
        return 0;
    }
    _aaw_result_state = state;
    _aaw_result_code = 1;
    return 0;
}

fn cbarrier_arrive_and_wait(cbs, name, participant) {
    var mtx = load64(cbs + 8);
    mutex_lock(mtx);
    _cbarrier_do_arrive(load64(cbs), name, participant);

    if (_aaw_result_code != 1) {
        mutex_unlock(mtx);
        return _aaw_result_code;
    }

    var state = _aaw_result_state;
    var futex_addr = state + 32;
    var released_addr = state + 24;
    var val = load64(futex_addr);
    mutex_unlock(mtx);

    while (1) {
        if (load64(released_addr) == 1) { return 0; }
        syscall(SYS_FUTEX, futex_addr, FUTEX_WAIT, val, 0, 0, 0);
        if (load64(released_addr) == 1) { return 0; }
        val = load64(futex_addr);
    }
}
```

Three candidate hypotheses, ordered by plausibility:

**H1 — Global-promotion pattern is not thread-safe.** The
`_aaw_result_state` / `_aaw_result_code` globals were introduced to dodge
the local-clobbering-across-nested-calls bug (the "save state to globals"
pattern documented in majra's CLAUDE.md). Cyrius has no thread-local
storage; these globals are shared process-wide. Two threads entering
`cbarrier_arrive_and_wait` near-simultaneously race on the global pair
even though `_cbarrier_do_arrive` is called under the per-cbs mutex — the
second thread's `var state = _aaw_result_state` on line 250 can read a
value stomped by a third thread that has since entered. The reads on
lines 250-253 happen under the mutex too, but if the compiler reorders or
if `_aaw_result_state` gets clobbered by the `mutex_unlock` call on
line 254 (which itself may touch globals internally), the subsequent
`futex_addr = state + 32` computes against stale or zero state and the
SIGSEGV would land on the first `load64(futex_addr)` / `load64(released_addr)`
in the wake loop.

**H2 — Futex-wake path returns a clobbered local.** `state`, `futex_addr`,
`released_addr`, and `val` are all locals that live across the
`syscall(SYS_FUTEX, futex_addr, FUTEX_WAIT, val, 0, 0, 0)` call on
line 258. majra's CLAUDE.md explicitly calls out "function parameters
and locals may be overwritten by nested function calls" as a known cc
issue, with the stated workaround being to promote across-call values to
globals. The non-blocking `cbarrier_arrive` path doesn't invoke syscall
after its arrive, so it doesn't exercise this surface. If `syscall` is
treated by the register allocator like any other call and the loop body
locals aren't preserved across it, the second `load64(released_addr)`
(line 259) reads garbage and faults.

**H3 — `CLONE_VM` + Cyrius runtime assumption mismatch.** Cyrius's
allocator / freelist / hashmap runtime may make single-process
assumptions (e.g., a per-arena cursor not guarded by atomics, or a
hashmap rehash path that's not reentrant) that don't hold when
`thread_create` shares the address space via `CLONE_VM`. The barrier
case exercises this harder than most tests because the futex wake path
re-enters `load64` against shared state immediately after being parked.
This one is the hardest to pin down from the consumer side.

H1 is the most likely in my view, because the crash only appears with
>1 thread and the globals are the load-bearing cross-call state
specifically for this path.

## Proposed fix

None — just surfacing. I don't know cc5 internals well enough to propose
a change. A compiler expert should look at the interaction between:

1. the global-promotion pattern under multiple threads (whether
   thread-local storage should be the recommended workaround instead),
2. local-variable preservation across `syscall` calls specifically (vs.
   ordinary function calls), and
3. the Cyrius runtime's thread-safety assumptions for allocator / hashmap
   code touched from futex-wake paths.

A minimal triage step is to run the repro under `gdb` with
`handle SIGSEGV stop print` and look at which address faults — that
should immediately distinguish H1 (faulting in `load64(state+32)` with
`state==0` or clearly garbage) from H2 (faulting on a plausible address
but in the wake loop, not the initial compute) from H3 (faulting inside
libc / allocator internals).

## Consumer-side workaround (if any)

Use the non-blocking `cbarrier_arrive` entry point (same file,
lines 190-214) and poll. `cbarrier_arrive` returns a
`(code, arrived, expected)` triple without parking the calling thread,
so it exercises the hashmap surface (which cc5 handles correctly post
relay-dedup fix) but not the futex-wait surface. Consumers that need
blocking semantics can wrap it in a sleep-and-retry loop at the caller.

In majra's own test suite, the blocking-path assertion in
`tests/test_core.tcyr` is gated off with a comment pointing at this
issue. The six previously-gated relay-dedup assertions in `test_relay`
have been revived and pass under 5.4.8 — that class of bug is
independently confirmed fixed. Only the thread + futex + barrier
combination remains broken.
