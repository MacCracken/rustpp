# dynlib NSS-dispatch bootstrap — investigation log

**Status:** partially unblocked in v5.5.24; full NSS dispatch
deferred (no fixed slot — glibc 2.34+ inlined the previously-
separate `libnss_*.so.2` modules into libc itself, so the fix
has to reconstruct libc's internal NSS state without exported
entry points, which isn't tractable in a patch release).

## What works today (after all v5.5.24 bootstraps)

```
dynlib_bootstrap_cpu_features();
dynlib_bootstrap_tls();
dynlib_bootstrap_stack_end(0);
var hc = dynlib_open("libc.so.6");
dynlib_init(hc);                   // IRELATIVE + DT_INIT_ARRAY
dynlib_bootstrap_locale(hc);       // v5.5.23
dynlib_bootstrap_environ(hc);      // v5.5.24
```

| libc fn                         | works? | notes |
|---------------------------------|--------|-------|
| `strlen` / `strcmp` / `memcmp`  | ✓      | |
| `getpid` / `getuid`             | ✓      | |
| `gettimeofday`                  | ✓      | |
| `setlocale(LC_ALL, NULL)` query | ✓      | query path |
| `newlocale` + `uselocale`       | ✓      | per-thread |
| `getenv`                        | ✓ (v5.5.24) | returns null (empty env) |
| **`setlocale(LC_ALL, "C")`**    | ✗      | `__libc_setlocale_lock` rwlock |
| **`setenv(…)`**                 | ✗      | heap realloc path — `__environ` alloc isn't a real malloc chunk |
| **`strerror(N)`**               | ✗      | locale msg tables not fully init |
| **`getpwuid(0)`**               | ✗      | NSS dispatch |
| **`getgrouplist(…)`**           | ✗      | NSS dispatch |
| **`pam_authenticate(…)`**       | ✗      | via libpam → NSS dispatch |
| **`getaddrinfo(…)`**            | ✗      | NSS dispatch |
| **`__nss_configure_lookup(…)`** | ✗      | NSS dispatch (private API) |
| **`__libc_early_init(1)`**      | SIGFPE | requires auxv state we don't set |

## Investigation attempts (v5.5.24, 3 attempts per CLAUDE.md rule)

### Attempt 1 — init `__environ` / `environ`

`__environ` starts NULL; `getenv` / `setenv` / NSS internals walk
it. Hypothesis: pointing it at a valid empty terminator-only
array unblocks NSS.

**Result:** partially. `getenv` now works (returns NULL safely
for missing keys). `getpwuid` still SIGSEGVs. `setenv` still
SIGSEGVs (tries to realloc the array — our cyrius `alloc`
returns memory that isn't a glibc malloc chunk, so the realloc
crashes). **Shipped `dynlib_bootstrap_environ(hc)` in v5.5.24 —
captures the getenv unblock.**

### Attempt 2 — probe available private init symbols

`nm -D libc.so.6` exports some private symbols. Checked
availability:

| symbol                        | exported? |
|-------------------------------|-----------|
| `__libc_init_first`           | ✓ |
| `__libc_early_init`           | ✓ |
| `__pthread_initialize_minimal`| ✗ |
| `__nss_database_lookup2`      | ✗ |
| `__nss_disable_nscd`          | ✗ |
| `__libc_enable_secure`        | ✗ |

Key missing: `__nss_database_lookup2` (the internal entry that
`getpwuid` hits and crashes in). Without it (or its successor on
current glibc), we can't pre-warm the NSS dispatch table. The
NSS module tables are static-private linkage in glibc 2.34+.

### Attempt 3 — call `__libc_early_init(1)` directly

`__libc_early_init` is the glibc private entry point that ld.so
calls early in startup. Tried calling it directly before
`dynlib_init`. Crashes with **SIGFPE** (exit 136) — it expects
auxv state we haven't populated.

Populating auxv correctly requires: parsing `/proc/self/auxv`
(or synthesizing one), writing AT_RANDOM to a stable location,
AT_PLATFORM, AT_SYSINFO_EHDR for VDSO, etc. That's its own
multi-day investigation because auxv is kernel-populated and
we'd be hand-faking it — it's not clear every consumer path
even accepts synthesized values.

### Conclusion

Full NSS dispatch bootstrap requires reverse-engineering
`__libc_start_main`'s auxv-consuming flow against the current
glibc version, which is neither stable across glibc releases nor
exposed through a public API. **Not tractable as a patch release.**

## Workarounds for current consumers

- **shakti's `pam_authenticate`** — stays stubbed; caller falls
  through to `syscall(execve, "/usr/bin/su", …)`. Works,
  different shape.
- **Any consumer needing `getpwuid`** — read `/etc/passwd`
  directly via cyrius file I/O. Skips NSS entirely. Only works
  for systems with `passwd: files` NSS config but that's most
  of them.
- **`getenv`** — works after `dynlib_bootstrap_environ`.

## If this is picked up again

Worth trying:
1. Synthesize an auxv by parsing `/proc/self/auxv`, write it to a
   known stack location, then call `__libc_early_init(1)`.
2. If that works, `__libc_init_first` should also run cleanly.
3. That MIGHT unblock NSS dispatch as a side effect.

But: this couples cyrius to glibc's specific auxv expectations,
which drift across versions. Probably only viable if auxv
forwarding is pinned to a minimum glibc version.
