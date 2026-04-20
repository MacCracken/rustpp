# Cyrius — Apple Silicon (arm64 Mach-O)

This tarball ships the Apple Silicon stdlib (including
`syscalls_macos.cyr` and `alloc_macos.cyr`) plus a `smoke.macho`
binary proving the cross-compile toolchain produces valid arm64
Mach-O output.

## Current scope

Apple Silicon Cyrius programs support the BSD SVC whitelist:
`read`, `write`, `open`, `close`, `mmap`, `mprotect`, `munmap`,
`exit`. PIE-safe addressing (adrp+add), strings, globals, and
multi-page `__TEXT` all work. This covers syscall-only programs
(agent probes, simple CLI tools written against raw syscalls).

## libSystem import status

v5.5.11 (2026-04-20) proved the classic-bind path end-to-end with a
hand-emitted probe: `programs/macho_libsystem_probe.cyr` calls
`libSystem._exit(42)` via a `__got` slot resolved by dyld, verified
on Apple Silicon (`ssh ecb`).

v5.5.12 grafted the probe layout into `EMITMACHO_ARM64` — every
compiled arm64 Mach-O now ships `__DATA_CONST` + `__got` +
`LC_DYLD_INFO_ONLY` classic binds for `libSystem._exit`. `nm`
shows `U _exit`; `otool -l` shows the new segment. Infrastructure
is live; specific syscall numbers are still svc-based until the
reroute patches land (below).

Remaining for full toolchain shipping:

| Patch | Scope |
|-------|-------|
| v5.5.13 | First `__got` reroute — `syscall(60, N)` → `libSystem._exit` via `adrp x16, __got@PAGE; ldr x16, [x16]; br x16`. |
| v5.5.14 | Multi-symbol imports — grow `__got` to N slots; add `_write`, `_read`, `_malloc`, `_fopen`, `_pthread_create`. Table-driven like `syscall_pe_tbl`. |
| v5.5.15 | `cyrfmt`/`cyrlint`/`cyrdoc`/`cyrc` cross-compiled + verified on `ssh ecb`. |

Programs still using `brk`-based allocation (`lib/alloc.cyr`) or
file locking (`lib/io.cyr:syscall(73)`) fail to compile with a
clear error today. v5.5.15 closes the gap.

## Cross-compiling on macOS

Install the Linux x86_64 tarball on a Linux host (or via Rosetta /
Lima / Docker on macOS) and run:

    CYRIUS_MACHO_ARM=1 build/cc5_aarch64 < my.cyr > my.macho
    chmod +x my.macho
    codesign -s - --force my.macho
    ./my.macho

See `smoke.macho` in this bundle for a working example.
