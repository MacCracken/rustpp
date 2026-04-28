# dynlib NSS-dispatch bootstrap — investigation log

**Status (2026-04-21, closed):** the NSS-dispatch arc is
CLOSED. The auxv-synthesis approach was confirmed insufficient
in v5.5.25 and **re-planned** same day after external research
converged on glibc maintainers' own guidance. The three-patch
plan that shipped:

* **v5.5.26 ✅** — `lib/pwd.cyr` + `lib/grp.cyr` (musl-style pure-
  cyrius `/etc/passwd` + `/etc/group` reader). Bypasses glibc
  NSS entirely. Solves 95% of consumers.
* **v5.5.27 ✅** — `lib/shadow.cyr` + `lib/pam.cyr` (forks
  `/usr/sbin/unix_chkpwd` for non-root auth — same path
  `pam_unix.so` takes from unprivileged processes). Shadow auth
  without glibc.
* **v5.5.28 ✅** — `lib/fdlopen.cyr` primitives + C helper
  (foreign-dlopen pattern from Cosmopolitan / pfalcon) — the
  API for the cases that need real glibc state. **v5.5.34**
  completed orchestration (40/40 round-trip
  `dlopen("libc.so.6")+dlsym("getpid")` == `syscall(SYS_GETPID)`
  after the ELF `PF_R/PF_X` ↔ `PROT_READ/PROT_EXEC` bit-swap
  fix).

Historical log below preserved for future investigators.

The v5.5.23/24/25 primitives (`dynlib_bootstrap_locale`,
`dynlib_bootstrap_environ`, `dynlib_read_auxv`, `dynlib_auxv_get`)
remain useful for the subset of consumers that want direct libc
access without the full foreign-dlopen bootstrap (simple libc calls
like `strlen`, `getpid`, `getenv` already work after them).

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

## v5.5.25 — auxv synthesis attempt (re-planned after)

**Attempts (3 of 3, rule triggered):**

### Attempt 1 — `dynlib_read_auxv` / `dynlib_auxv_get` primitives

`/proc/self/auxv` is a sequence of `(u64 type, u64 value)` pairs
terminated by `(AT_NULL=0, 0)`. `dynlib_read_auxv(buf, maxbytes)`
slurps the file into `buf`; `dynlib_auxv_get(buf, bytes, tag)`
scans for a specific tag. Independently useful (exposes
`AT_PAGESZ`, `AT_RANDOM`, `AT_SYSINFO_EHDR` / vDSO base,
`AT_HWCAP`, etc.) regardless of the NSS outcome.
**Shipped.**

### Attempt 2 — populate `_rtld_global_ro` from auxv

`programs/nss_probe.cyr` confirmed:

1. libc.so.6's GLOB_DAT relocation for `_rtld_global_ro` **does
   resolve correctly** during `dynlib_open` — `_dynlib_process_rela`
   walks `.rela.dyn`, finds the symbol via `_dynlib_resolve_global`
   against the already-registered `/lib64/ld-linux-x86-64.so.2`,
   and writes ld.so's export address into libc's GOT slot. So the
   v5.5.24 SIGFPE in `__libc_early_init` is **not** a GOT
   resolution bug.
2. `_rtld_global_ro` is mapped-but-zero-filled. Offsets `+0x2a0`
   and `+0x2a8` are both zero. `__libc_early_init` divides by
   `*(rtld_ro + 0x2a8)` — with zero there, SIGFPE. Root cause:
   ld.so's `_dl_start` was never invoked on our process, so the
   fields it would populate from auxv are left at zero.
3. Populating `+0x2a8` with `AT_PAGESZ` and `+0x2a0` with 8 MB
   (plausible defaults) **moved past SIGFPE → SIGSEGV elsewhere**
   in `__libc_early_init`. The missing-init cascade is wider than
   two fields.

### Attempt 3 — skip `__libc_early_init`, call `getpwuid(0)` directly

With `_rtld_global_ro` partially populated, direct `getpwuid(0)`
still SIGSEGVs inside NSS dispatch. The NSS module table is
private-static state that's populated by a code path we can't
reach through exported symbols.

### Conclusion

Populating `_rtld_global_ro` from auxv is a fragile, glibc-
version-coupled, and ultimately insufficient approach — each
call into libc reveals new uninitialised struct fields. Without
executing ld.so's `_dl_start` (which requires auxv on the real
stack and proper `PT_INTERP` wiring), libc's internal state
cannot be made consistent from outside.

**Full NSS dispatch fix was initially unpinned** from the
roadmap after v5.5.25 — then re-planned the same day based on
external research (see the "v5.5.26+ plan" section below). The
real solution doesn't require hand-populating `_rtld_global_ro`
at all. If a future maintainer still wants to try the synthesis
path, see `programs/nss_probe.cyr` for
a reproduced starting point.

## v5.5.29 — foreign-dlopen orchestration attempt (partial)

Shipped the orchestration code for Path B (foreign-dlopen),
hit 3-attempts-defer per CLAUDE.md rule on making it actually
run helper main. All primitives work in isolation; end-to-end
path fails silently.

### What works

- `_fdlopen_mmap_elf(path, out)` — minimal ELF PT_LOAD mapper.
  Tested in isolation on both `~/.cyrius/dlopen-helper` and
  `/lib64/ld-linux-x86-64.so.2`. Returns correct base, entry,
  phdr address, phnum, phentsize. Anonymous mmap + memcpy from
  file-backed mmap + mprotect per PF_* → PROT_* translation.
- `_fdlopen_build_stack` — lays out kernel-style startup data
  at a 64 KB stack region: argc=3, argv[0..2] (helper path,
  state-hex, cb-hex), NULL, empty envp NULL, 15 auxv pairs
  (AT_PHDR/PHENT/PHNUM/PAGESZ/BASE/FLAGS/ENTRY/UID/EUID/GID/
  EGID/HWCAP/SECURE/RANDOM/EXECFN/SYSINFO_EHDR/NULL).
  Returns 16-byte-aligned RSP.
- `_fdlopen_hex64` — u64 to 16-char lowercase hex + NUL.
- `_fdlopen_cb` + `dl_longjmp` — tested direct-call round
  trip; setjmp receives rt=1 correctly.
- `fdlopen_init` returns shape-stable FDL_ERR_UNINIT (-8) after
  helper probe succeeds; existing tests stay green.

### What fails

Invoking `_fdlopen_enter_ldso(ldso_entry, new_rsp)` fires the
raw-hex inline asm `mov rsp, new_rsp; xor edx, edx; jmp rax`.
Ld.so enters (no SIGSEGV from the first instruction). But the
process then exits cleanly (exit 0) without ever invoking
helper main.

A raw-write `write(2, "HELPER-MAIN\n", 12)` at the very first
line of `programs/dlopen-helper.c::main` confirmed: helper
main is NEVER reached under our constructed-stack jump. Ld.so
is running some code path that concludes without calling
`__libc_start_main` on the helper.

### Three attempts per CLAUDE.md

1. **Plain p_flags → prot** with `(p_fl/4)*4 == p_fl` bit
   extraction. SIGSEGV at first jmp. Translation bug — the
   expression didn't extract R correctly.
2. **Fixed R/W/X via div+mod**: `r_half = p_fl/4`, `if
   r_half - (r_half/2)*2 == 1` etc. Ld.so enters cleanly, no
   crash, but exits 0 silent. Helper main never reached.
3. **Added AT_UID/EUID/GID/EGID/HWCAP/SECURE/FLAGS** sourced
   from our own `/proc/self/auxv` via `dynlib_auxv_get`. Same
   result: exit 0 silent.

### Pinned: v5.5.30 completion — concrete starting points

Not speculation — each is a specific diagnostic against the
empirical findings above:

1. **AT_PHDR content verification.** Dump `helper_info + 16`
   bytes and compare byte-for-byte against `readelf -l
   ~/.cyrius/dlopen-helper` output for the phdr range. If
   mismatch, our copy pass has a bug.
2. **File-backed mmap of helper PT_LOAD.** Switch from
   `mmap_anon + memcpy` to `mmap(base+p_vaddr, memsz, prot,
   MAP_PRIVATE|MAP_FIXED, fd, p_offset & ~4095)`.
   Cosmopolitan uses file-backed; may be load-bearing for
   ld.so's self-map introspection via `/proc/self/maps`.
3. **strace diff.** Run on a host with strace installed:
   `strace -f ./dlopen-helper ADDR ADDR` vs probe2 with
   strace. Pinpoint the first syscall that diverges.
4. **Cosmopolitan cosmo_dlopen cross-reference.** Walk
   `libc/dlopen/dlopen.c` in the cosmopolitan repo for any
   pre-jump setup step we're skipping: locale init, TLS base
   setup via `arch_prctl`, signal mask save/restore, stack
   canary init, rseq init.
5. **Register state at jump.** Verify `xor edx, edx` happens
   BEFORE `mov rsp, new_rsp` (currently correct in
   `_fdlopen_enter_ldso`). Also check whether ld.so needs
   `rdi` cleared — some dl-machine.h variants assume rdi is
   zero or matches rsp.

All of this is reproducible: `/home/macro/.cyrius/dlopen-helper`
is the compiled helper on my development host. The 64 KB
anonymous stack is allocated fresh each call. The bug is
deterministic (reproduces every run).

## Shipped primitives (v5.5.24 + v5.5.25)

| function                         | since  | purpose |
|----------------------------------|--------|---------|
| `dynlib_bootstrap_cpu_features`  | v5.3.x | zero `__cpu_features`; unblocks IRELATIVE |
| `dynlib_bootstrap_tls`           | v5.3.x | `arch_prctl(ARCH_SET_FS)` to TLS block |
| `dynlib_bootstrap_stack_end`     | v5.3.x | populate `__libc_stack_end` |
| `dynlib_bootstrap_locale`        | v5.5.23 | `newlocale` + `uselocale` for per-thread locale |
| `dynlib_bootstrap_environ`       | v5.5.24 | `__environ` / `environ` point at empty array |
| `dynlib_read_auxv`               | v5.5.25 | slurp `/proc/self/auxv` |
| `dynlib_auxv_get`                | v5.5.25 | scan auxv for a tag |

## v5.5.26+ plan — external research (2026-04-21)

Two research agents converged on the same conclusion: **stop fighting
`_rtld_global_ro`.** Glibc maintainers themselves say auxv synthesis
doesn't work:

> "Change the static dlopen implementation to load ld.so first and
> let it handle all further dynamic linking."
> — Florian Weimer, libc-alpha 2017-12
> https://sourceware.org/legacy-ml/libc-alpha/2017-12/msg00521.html

There are two legitimate escape valves, and cyrius should take both:

### Path A — bypass glibc NSS entirely (v5.5.26 + v5.5.27)

This is what musl libc does for its entire identity surface. No
NSS dispatcher, no `_rtld_global_ro`, no `/etc/nsswitch.conf`
parsing. Just:

```
open /etc/passwd, for each line:
  split on ':' into 7 fields: name, passwd, uid, gid, gecos, dir, shell
  if uid matches: return struct
```

Musl's implementation is ~50 LoC of real logic:
* `src/passwd/getpwent.c` — 25 LoC entry points
* `src/passwd/getpwent_a.c` — ~55 LoC parser
* `src/passwd/getpw_a.c` — ~40 LoC
* `src/passwd/getpw_r.c` — 45 LoC reentrant wrapper

References:
* https://git.musl-libc.org/cgit/musl/plain/src/passwd/getpwent.c
* https://git.musl-libc.org/cgit/musl/plain/src/passwd/getpwent_a.c
* https://git.musl-libc.org/cgit/musl/plain/src/passwd/getpw_a.c

Shadow auth (`pam_authenticate`) = read `/etc/shadow` + sigil's
SHA-512-crypt. Unix `crypt(3)` format is `$6$salt$hash` / `$5$salt$hash`
/ `$1$salt$hash`. sigil already has SHA-256 + SHA-512 primitives.

For systems where `/etc/shadow` is 600 root:root and cyrius isn't
root: fork `/usr/sbin/unix_chkpwd` — setuid-root, designed for
pipe-based invocation by non-root PAM modules. Exactly what
Linux-PAM's `pam_unix` uses. Reference:
* https://reviews.freebsd.org/D34322 — FreeBSD Linux-PAM port
* https://github.com/Zirias/unix-selfauth-helper

**Limitation:** only handles `passwd: files` / `group: files` NSS
configs. Won't work with LDAP, SSSD, NIS, winbind. That's fine for
AGNOS ecosystem targets. The 5% of consumers that need LDAP can
use Path B.

### Path B — foreign-dlopen pattern (v5.5.28)

For cases that genuinely need full glibc state (getaddrinfo DNS
with `/etc/resolv.conf` + `/etc/hosts`; strerror with locale
messages; setlocale global rwlock; setenv realloc path): implement
the foreign-dlopen pattern used by two production codebases:

* **pfalcon/foreign-dlopen** — https://github.com/pfalcon/foreign-dlopen
  — "dlopen from statically-linked applications where static exe
  and loaded shared lib may use completely different libc's"
* **Cosmopolitan libc** — https://github.com/jart/cosmopolitan/blob/master/libc/dlopen/dlopen.c
  — Jart's `cosmo_dlopen`

How it works:

1. Compile a tiny helper binary at install time against the system
   libc. ~40 lines of C — just calls `dlopen` / `dlsym`, then
   invokes a caller-provided callback with the captured fn pointers.
   Cache at `~/.cyrius/dlopen-helper`.
2. mmap both the helper ELF and ld-linux.so.2 into our address
   space. No fork, no exec.
3. Build a fake argv/envp/auxv on a fresh 64 KB stack region. Set:
   `AT_PHDR`, `AT_BASE`, `AT_ENTRY`, `AT_PAGESZ`, `AT_RANDOM`,
   `AT_SYSINFO_EHDR` (vDSO), argv[0], envp.
4. `setjmp` in our static code so control can return.
5. Jump to ld.so's ELF entry point (`e_entry` from the interpreter's
   header) with the constructed stack. ld.so now runs its *normal*
   `_dl_start` → `_dl_sysdep_start` → `dl_main` → `_dl_start_user`
   flow, populates `_rtld_global_ro` legitimately, and invokes
   `__libc_start_main` in the helper.
6. Helper's `main()` runs. It resolves our requested symbols via
   real `dlsym` and calls back into us via a function pointer we
   passed in the constructed argv.
7. Callback does `longjmp` back into the static binary with a
   struct of real function pointers into a fully-initialized libc
   living in our address space.
8. Call them directly. NSS dispatch works because ld.so did its
   job properly.

Implementation cost (cyrius): ~200 LoC + ~40 LoC C helper +
setjmp/longjmp primitives (~10 lines inline asm each). Multi-session.

Risks:
* Locale double-init may clash with `dynlib_bootstrap_locale`.
  Mitigation: foreign-dlopen path owns locale setup; skip the
  earlier bootstrap when this path is in use.
* TLS ordering: ld.so will set up TLS for the helper's libc. Our
  static cyrius code already has TLS via `arch_prctl`. Need to
  verify `%fs`-base doesn't collide. cosmopolitan handles this
  cleanly; copy their approach.

### Why this plan beats alternatives

| Approach                      | Cost | Completeness | Fragility |
|-------------------------------|------|--------------|-----------|
| auxv-synthesis (v5.5.25 try)  | —    | 0%           | breaks per glibc release |
| pure-cyrius /etc/passwd       | 1-2d | 95%          | zero — deterministic file parse |
| shadow + sigil crypt          | 1-2d | 95% of auth  | zero |
| fork unix_chkpwd              | 1d   | 100% of PAM  | linux-pam ABI (stable 15+ yr) |
| fork/exec getent              | 1d   | 100% incl NSS| getent ABI (stable) |
| foreign-dlopen                | 1-2w | 100% of libc | medium — needs TLS ordering care |

### `_rtld_global_ro` field offset reference (glibc 2.39, x86_64)

For future investigators who want to try the synthesis path again
anyway, here's the struct layout based on `sysdeps/generic/ldsodefs.h`:

```
+0x000  int    _dl_debug_mask
+0x008  char*  _dl_platform          ← auxv AT_PLATFORM
+0x010  size_t _dl_platformlen
+0x018  size_t _dl_pagesize          ← auxv AT_PAGESZ
+0x020  size_t _dl_minsigstacksize   ← auxv AT_MINSIGSTKSZ
+0x028  int    _dl_inhibit_cache
+0x030  struct r_scope_elem _dl_initial_searchlist (16 B)
+0x040  int    _dl_clktck             ← auxv AT_CLKTCK
+0x044  int    _dl_verbose
+0x048  int    _dl_debug_fd
+0x04c  int    _dl_lazy
+0x050  int    _dl_bind_not
+0x054  int    _dl_dynamic_weak
+0x058  int    _dl_fpu_control        ← auxv AT_FPUCW
+0x060  size_t _dl_hwcap              ← auxv AT_HWCAP
+0x068  void*  _dl_auxv               ← pointer to raw auxv
+0x070  void*  _dl_inhibit_rpath
+0x078  char*  _dl_origin_path
+0x080  size_t _dl_tls_static_size
+0x088  size_t _dl_tls_static_align
+0x090  size_t _dl_tls_static_surplus
+0x098  char*  _dl_profile
+0x0a0  char*  _dl_profile_output
+0x0a8  void*  _dl_init_all_dirs
+0x0b0  void*  _dl_sysinfo
+0x0b8  void*  _dl_sysinfo_dso        ← auxv AT_SYSINFO_EHDR
+0x0c0  void*  _dl_sysinfo_map
+0x0c8  size_t _dl_hwcap2             ← auxv AT_HWCAP2
+0x0d0  size_t _dl_hwcap3             ← auxv AT_HWCAP3
+0x0d8  size_t _dl_hwcap4             ← auxv AT_HWCAP4
+0x0e0  int    _dl_dso_sort_algo
+0x0e8..+0x140  function-pointer vtable (12 fn ptrs)
+0x140  _dl_audit + audit state
...
(offsets past +0x150 include embedded `struct cpu_features` +
other sub-structs; our v5.5.25 SIGFPE at +0x2a8 is inside one of
them. Exact layout drifts between glibc versions — this table is
a starting point, not an ABI.)
```

Reference: https://elixir.bootlin.com/glibc/latest/source/sysdeps/generic/ldsodefs.h

The actual auxv → GLRO mapping lives in
`sysdeps/unix/sysv/linux/dl-parse_auxv.h`:
https://elixir.bootlin.com/glibc/latest/source/sysdeps/unix/sysv/linux/dl-parse_auxv.h
