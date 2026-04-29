# stdlib syscall surface gaps — aarch64 portability (from agnosys)

**Source**: agnosys — AGNOS userspace primitives (drm, luks, security).
Repo: `/home/macro/Repos/agnosys`.
**Status**: not blocking the agnosys aarch64 portability fix — agnosys
self-contains by using portable wrappers where they exist (`sys_open`,
`sys_access`) and arch-conditional constant definitions where they
don't. This issue is the cyrius-side hygiene followup so the next
consumer doesn't have to redefine the same constants.
**Filed**: 2026-04-28 at v5.7.34 ship.

**Disposition (cyrius lang agent)**: TBD — three coherent stdlib
additions that share the same shape (Linux syscall, both arches,
existing-but-not-exposed). Bundle as one slot if claimed.

Each item lists: **agnosys sites**, **proposed stdlib surface**,
**why stdlib**, **priority**. Priorities: P1 (blocks port), P2
(removes consumer duplication), P3 (polish).

---

## P2-1. `sys_getdents64(fd, buf, count)` — directory enumeration

### Current agnosys
2 call sites in `src/drm.cyr` (DRM device discovery — walks
`/dev/dri/` to find `card*` and `renderD*` nodes).

The syscall numbers diverge between arches:
- aarch64: `SYS_GETDENTS64 = 61`
- x86_64: `SYS_GETDENTS64 = 217`

Cyrius stdlib does not expose either constant or a portable wrapper,
so agnosys redefines them locally arch-conditional. Every consumer
that walks a directory at the syscall level (vs. using
`fs::list_dir`) does the same.

### Proposed stdlib

```
# lib/syscalls.cyr — arch-conditional enum members
SYS_GETDENTS64 = 217   # x86_64
SYS_GETDENTS64 = 61    # aarch64

# lib/fs.cyr — portable wrapper
fn sys_getdents64(fd, buf, count)
    # returns bytes filled in buf, or -errno
    # buf is a sequence of `struct linux_dirent64`:
    #   u64 d_ino; s64 d_off; u16 d_reclen; u8 d_type; char d_name[];
```

### Why stdlib

Userspace tools that enumerate device nodes, scan procfs, or
implement their own readdir need this. `lib/fs.cyr` already has the
high-level dir-iteration surface (`dir_list`); the underlying syscall
should be exposed too — same way `sys_open` is exposed alongside
`fs::open`.

### Priority

**P2**. Doesn't block any consumer (agnosys can define locally), but
every kernel-adjacent project ends up with the same redefinition.

---

## P2-2. `sys_getrandom(buf, len, flags)` — secure random bytes

### Current agnosys
2 call sites in `src/luks.cyr` (LUKS volume key + nonce material).

The syscall numbers diverge:
- aarch64: `SYS_GETRANDOM = 278`
- x86_64: `SYS_GETRANDOM = 318`

Same situation as getdents64: cyrius stdlib has no portable wrapper,
so agnosys redefines arch-conditional locally.

### Proposed stdlib

```
# lib/syscalls.cyr — arch-conditional enum members
SYS_GETRANDOM = 318    # x86_64
SYS_GETRANDOM = 278    # aarch64

# lib/random.cyr (new file) — portable wrapper + flag constants
GRND_NONBLOCK = 0x0001
GRND_RANDOM   = 0x0002
GRND_INSECURE = 0x0004

fn sys_getrandom(buf, len, flags)
    # returns bytes filled, or -errno
fn random_bytes(buf, len)
    # convenience: blocks until kernel CSPRNG seeded, no flags
```

### Why stdlib

Crypto-adjacent code (sigil already calls into libssl for randomness
via TLS) eventually needs a libc-free path to kernel entropy. A LUKS
key derivation, a nonce, a session token — all of them want
`getrandom(2)` and not `/dev/urandom + open + read + close`. Sigil's
own future bare-metal mode will need this. AGNOS-resident code
without libssl has no other option.

### Priority

**P2**. agnosys is the first consumer; sigil bare-metal will be
second; any cyrius-native TLS implementation would be third.

---

## P2-3. `sys_landlock_*` — kernel sandboxing primitives

### Current agnosys
3 call sites in `src/security.cyr` — `landlock_create_ruleset`,
`landlock_add_rule`, `landlock_restrict_self` for unprivileged
sandboxing.

Unlike getdents64/getrandom, landlock syscalls are **same-numbered on
both arches** (444/445/446). The gap is just that cyrius stdlib's
aarch64 syscall enum doesn't list them, so the constants don't exist
when an agnosys file is built for aarch64 even though the syscall
itself is valid.

### Proposed stdlib

```
# lib/syscalls.cyr — both arches (same numbers)
SYS_LANDLOCK_CREATE_RULESET = 444
SYS_LANDLOCK_ADD_RULE       = 445
SYS_LANDLOCK_RESTRICT_SELF  = 446

# lib/security.cyr (new file) — portable wrappers + constants
LANDLOCK_ACCESS_FS_EXECUTE     = 0x01
LANDLOCK_ACCESS_FS_WRITE_FILE  = 0x02
LANDLOCK_ACCESS_FS_READ_FILE   = 0x04
LANDLOCK_ACCESS_FS_READ_DIR    = 0x08
# (... full set per linux/landlock.h)

struct landlock_ruleset_attr {
    handled_access_fs: u64;
    handled_access_net: u64;  # since Linux 6.7
    scoped: u64;              # since Linux 6.10
}

fn landlock_create_ruleset(attr_ptr, size, flags)
fn landlock_add_rule(ruleset_fd, rule_type, rule_attr, flags)
fn landlock_restrict_self(ruleset_fd, flags)
```

### Why stdlib

Landlock is the modern unprivileged-sandbox API on Linux — userspace
processes voluntarily restrict their own filesystem access. Every
cyrius-native daemon (sandhi, kybernet, agnosys workers) is a
candidate consumer. The syscall numbers are stable since 5.13;
flag and struct definitions track upstream `linux/landlock.h`.

### Priority

**P2**. agnosys is the first consumer. The landlock surface is also
the smallest of the three additions (3 syscalls, ~10 flag constants,
1 struct), so it's the easiest to land first as a proof point.

---

## Bundling note

These three items share the same diagnostic — cyrius stdlib's
`syscalls_aarch64_linux.cyr` (or wherever the per-arch enum lives) is
out of date relative to upstream Linux. If the lang agent wants to do
a single sweep, the audit method is:

```sh
# Compare cyrius's aarch64 enum against the kernel's canonical list
grep -E '^#define __NR_' \
  /usr/src/linux/arch/arm64/include/uapi/asm/unistd.h \
  | awk '{print $2, $3}' \
  | sort > /tmp/kernel-syscalls.txt
# vs lib/syscalls.cyr's aarch64 block
```

Other likely missing entries (untriaged):
- `SYS_OPENAT2` (437) — modern openat with `struct open_how`
- `SYS_PIDFD_OPEN` (434) / `SYS_PIDFD_SEND_SIGNAL` (424)
- `SYS_PROCESS_VM_READV` / `WRITEV` (270/271 x86_64; 270/271 aarch64)
- `SYS_BPF` (321 x86_64; 280 aarch64) — divergent

Don't expand scope into a full BPF / pidfd / openat2 surface in this
slot — those are each their own feature. The minimal bundle is just
"expose what agnosys needed" (getdents64 + getrandom + landlock_*) so
the precedent is set; future per-feature slots add the rest.

---

## "stdlib is the platform abstraction" principle

The general invariant this issue is preserving:

> Consumers should not need to know which arch they're running on to
> make a syscall that exists on both arches.

Cyrius stdlib already does this for the common surface (`sys_open`,
`sys_read`, `sys_close`, `sys_mmap`, `sys_execve`...). The gap is
that the surface stopped expanding around 2020-era kernel syscalls
(landlock is 5.13, getrandom is 3.17). When agnosys hits the gap,
it has to do arch dispatch the stdlib promised to handle. That
promise is the principle to keep — not the specific syscalls in
this issue.
