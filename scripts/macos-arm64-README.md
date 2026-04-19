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

## Not yet available

Programs using `brk`-based allocation (`lib/alloc.cyr`) or file
locking (`lib/io.cyr:syscall(73)`) fail to compile with a clear
error. Tools like `cyrfmt`, `cyrlint`, `cyrdoc` fall into this
category and are therefore NOT included here. Full libSystem
imports — the path that would unlock `printf`, `pthread`, `fopen`,
and the rest — is a v5.4.x target.

## Cross-compiling on macOS

Install the Linux x86_64 tarball on a Linux host (or via Rosetta /
Lima / Docker on macOS) and run:

    CYRIUS_MACHO_ARM=1 build/cc5_aarch64 < my.cyr > my.macho
    chmod +x my.macho
    codesign -s - --force my.macho
    ./my.macho

See `smoke.macho` in this bundle for a working example.
