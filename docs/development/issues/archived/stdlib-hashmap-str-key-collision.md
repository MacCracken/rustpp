# stdlib hashmap: hash_str mishandles Str-struct keys (~3% entry loss)

**Discovered:** 2026-04-20 during majra 2.4.0-dev soak test development
**Severity:** Medium
**Affects:** cc5 5.4.x through current (verified on 5.4.12-1). Bug is in
`lib/hashmap.cyr`'s `hash_str` — cc-version-independent, stdlib-specific.

## Summary

`hash_str(s)` in `lib/hashmap.cyr` walks `s` byte-by-byte until a NUL
terminator using `load8(s + hi)`. That's correct for C-strings. But the
idiomatic Cyrius map-key construction pattern —

```
var key = str_from_int(id);
map_set(m, key, val);
```

— passes a **Str struct pointer**, not a cstring. A `Str` is a fat
`{data_ptr, len}` pair (two i64s); its first 16 bytes are pointer + length
with no NUL, so `hash_str` walks off into adjacent bump-allocator memory
until it happens to hit a zero byte. The resulting hash is effectively a
function of the Str's *address*, not its textual content. Different Strs
with different logical content collide frequently; the collision path's
`streq` in `_map_find` (line 71) DOES compare Str contents correctly, so
we don't read wrong values — but `_map_find` returns a wrong-bucket
tombstone and the next `map_set` silently overwrites the colliding entry.

Empirical loss rate is stable at ~3% across counts 50, 100, 200, 400, 500,
1000, 5000 (constant collision density, consistent with address-derived
hashing rather than content-derived).

## Reproduction

Minimal source, runs on any 5.4.x build:

```
include "lib/string.cyr"
include "lib/fmt.cyr"
include "lib/alloc.cyr"
include "lib/freelist.cyr"
include "lib/vec.cyr"
include "lib/str.cyr"
include "lib/hashmap.cyr"
include "lib/syscalls.cyr"
include "lib/io.cyr"

fn main() {
    alloc_init();
    fl_init();
    var m = map_new();
    var i = 1;
    while (i <= 500) {
        var key = str_from_int(i);
        map_set(m, key, i);
        i = i + 1;
    }
    fmt_int_fd(1, map_size(m)); println(" / 500");
    return 0;
}

var r = main();
syscall(SYS_EXIT, r);
```

Expected: `500 / 500`.
Actual: `485 / 500` or `486 / 500` (varies with allocator layout, stays in
the 14–15 entries lost range for this count).

## Root cause

`lib/hashmap.cyr` lines 23–33 (the full `hash_str` fn). `load8(s + hi)`
reads raw bytes starting at `s`, but in the `str_from_int → map_set`
pattern `s` is a Str struct pointer. The byte walk terminates on whatever
zero byte the struct or its neighbouring freelist slot happens to contain
— essentially random.

The collision is silent because `_map_find` (line 71) compares candidate
keys with `streq`, which IS struct-aware: the wrong-bucket lookup doesn't
return a false-positive match, it just returns a tombstone or an
occupied-by-different-key slot. `map_set` then happily overwrites that
slot, losing whichever entry was already there.

So we have two stdlib functions with opposite key-type assumptions
(`hash_str` → cstr, `streq` → Str struct) both invoked on the same input
inside the same `_map_find` call. That mismatch is the bug.

## Proposed fix

Two-part, not mutually exclusive:

1. **Rename** the existing `hash_str` to `hash_cstr` — it's a cstr hash,
   call it what it is. Leave the old name as a deprecated alias for one
   release so downstream cstr-key callers have a migration window.

2. **Add a Str-aware hash** under the `hash_str` name:

   ```
   fn hash_str(s) {
       if (s == 0) { return 0; }
       var data = str_data(s);
       var len = str_len(s);
       var h = 0xCBF29CE484222325;
       var hi = 0;
       while (hi < len) {
           h = h ^ load8(data + hi);
           h = h * 0x100000001B3;
           hi = hi + 1;
       }
       return h;
   }
   ```

   Update `_map_find`, `_map_lookup`, and the other internal sites to
   call the new `hash_str` (Str-aware). This matches the `streq` already
   in use. Callers who genuinely have cstrings migrate to `hash_cstr` or
   wrap via `str_from`.

The rename+replace is a source-level breaking change for direct
`hash_str` callers. Empirically the only downstream callers are
`map_set` / `map_get` / friends in `lib/hashmap.cyr` itself — the rest
of the ecosystem reaches `hash_str` transitively through the map API,
so fixing the map API fixes them all.

## Consumer-side workaround

What majra is doing in its 2.4.0-dev soak test:

- `mq_total_completed` (a `counter_inc`-backed i64) is treated as the
  authoritative invariant for completed-job counts.
- `mq_job_count` (which is `map_size` of a Str-keyed map populated via
  `str_from_int(job_id)`) is marked **informational-only** in the soak
  harness with a comment referencing this issue.

Alternative workaround available to consumers who need the per-id
presence check: unwrap the Str to its cstr backing before `map_set` /
`map_get`, e.g. `map_set(m, str_data(key), val)` and likewise on lookup.
Works as long as the cstr backing stays alive for the map's lifetime —
`str_from_int`'s cstr backing is freelist-owned so this is safe in a
single-lifetime soak but not in a general-purpose map where the Str may
go out of scope before the map does.

Neither workaround is ideal; both are fine until the upstream fix lands.
