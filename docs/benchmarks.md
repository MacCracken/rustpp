# Cyrius Benchmarks

> Generated: 2026-04-07 | Platform: x86_64 Linux | Version: 1.11.1

## Binary Size: Cyrius vs GNU Coreutils

| Program | Cyrius | GNU | Smaller by |
|---------|--------|-----|-----------|
| true | 168 B | 39,144 B | **233x** |
| false | 168 B | 39,144 B | **233x** |
| echo | 240 B | 43,240 B | **180x** |
| yes | 368 B | 43,240 B | **117x** |
| head | 600 B | 51,432 B | **85x** |
| seq | 840 B | 51,432 B | **61x** |
| nl | 1,280 B | 47,400 B | **37x** |
| cat | 4,536 B | 47,368 B | **10x** |
| tee | 4,584 B | 47,336 B | **10x** |
| basename | 4,856 B | 43,248 B | **8.9x** |
| grep | 5,496 B | 158,000 B | **28x** |
| wc | 5,816 B | 67,824 B | **11x** |
| tr | 8,880 B | 59,624 B | **6.7x** |
| uniq | 9,864 B | 51,432 B | **5.2x** |
| sort | 10,728 B | 125,424 B | **11x** |

**All 16 Cyrius CLI tools: 58 KB total** (vs ~953 KB for GNU equivalents — **16x smaller**)

### Why so small?

- No libc — direct syscalls only
- No dynamic linking overhead
- No locale, UTF-8, or i18n support
- No error message strings (beyond what's needed)
- Minimal ELF header (120 bytes)
- No section headers, no symbol tables

## Runtime Performance

| Test | Cyrius | GNU | Notes |
|------|--------|-----|-------|
| wc 1MB | <1ms | 21ms | **Cyrius 20x+ faster** |
| wc 10MB | <1ms | 207ms | **Cyrius 200x+ faster** |
| cat 1MB pipe | ~1ms | ~1ms | Near-identical (I/O bound) |

The wc advantage comes from zero-overhead processing — no locale, no UTF-8 decoding, no libc abstraction layers. Raw syscalls with block-buffered reads.

## Compile Speed

| Operation | Time |
|-----------|------|
| Compiler self-compile (233KB binary) | **~74ms** |
| Build any single program | **<5ms** |
| Full bootstrap (from 29KB seed) | **40ms** |
| Assembler throughput | 1.3M lines/sec |

The compiler is faster than the OS can spawn it. Process startup (fork+exec) dominates.

## Toolchain Size

| Component | Size |
|-----------|------|
| Bootstrap seed (bootstrap/asm) | 29 KB |
| Stage1f compiler | 12 KB |
| Assembler (asm) | 29 KB |
| Full compiler (cc3) | 233 KB |
| cyrius build tool | 59 KB |
| **Total toolchain** | **362 KB** |

The entire Cyrius toolchain fits in **362 KB**. GCC: ~100 MB. Clang/LLVM: ~500 MB. Rust: ~800 MB.

## Library Ecosystem

| Library | Functions | Purpose |
|---------|-----------|---------|
| string.cyr | 9 | strlen, streq, memcpy, memset, memchr, strchr |
| alloc.cyr | 4 | Bump allocator (brk-based) |
| str.cyr | 9 | Fat string type (data + len) |
| vec.cyr | 8 | Dynamic array with bounds checking |
| io.cyr | 9 | File I/O wrappers |
| fmt.cyr | 7 | Integer/hex/bool formatting |
| args.cyr | 3 | CLI argument parsing |
| fnptr.cyr | 3 | Indirect function calls |
| **agnostik** (6 modules) | 45+ | Shared types, security, agent lifecycle, audit, config |
| **agnosys** (1 module) | 30+ | Linux syscall bindings (50 syscalls) |
| **kybernet** (7 modules) | 25+ | PID 1 init system |

| thread.cyr | 10+ | Threads (clone+mmap), mutex (futex), MPSC channels |
| async.cyr | 5+ | Async primitives |
| freelist.cyr | 5+ | Freelist allocator (free + reuse, O(1) alloc/free) |
| math.cyr | 5+ | Extended math (f64_atan and more) |

**Total: 28 library modules, 200+ functions**

## Test Coverage

| Suite | Tests | Status |
|-------|-------|--------|
| Compiler (cc3) | 216 | All pass |
| Programs | 51 | All pass |
| aarch64 (cross) | 26 | All pass |
| **Total** | **267+26** | **0 failures** |

## Programs (46 total)

**CLI tools (19):** cat, echo, head, wc, grep, hexdump, tail, tr, uniq, sort, basename, cols, count, toupper, rot13, rev, nl, seq, tee, yes, true, false

**Algorithms (8):** fizzbuzz, primes, sieve, collatz, ackermann, gcd, brainfuck, life

**Data structures (4):** struct_list, alloctest, strtype, points

**Systems (3):** bitfield, asmtest, memset

**Library tests (2):** agnostik_test (54 assertions), kybernet_test (38 assertions)

**Kernel (3):** kernel_hello, isr_stub, agnos (58KB full kernel)

## Dependencies

- Linux x86_64
- /bin/sh (bootstrap only)
- **Nothing else**
