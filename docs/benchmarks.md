# Cyrius Benchmarks

> Generated: 2026-04-11 | Platform: x86_64 Linux | Version: 3.4.15

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
| Compiler self-compile (250KB binary) | **~74ms** |
| Build any single program | **<5ms** |
| Full bootstrap (from 29KB seed) | **40ms** |
| Assembler throughput | 1.3M lines/sec |

The compiler is faster than the OS can spawn it. Process startup (fork+exec) dominates.

## Compiler Microbenchmarks

Measured with `bench_batch_start`/`bench_batch_stop` (batch_size >= 1000) to
avoid clock_gettime overhead. Per-iteration timings for hot paths:

| Operation | Time | Notes |
|-----------|------|-------|
| fixed_mul | 6 ns | 16.16 fixed-point multiply |
| fixed_div | 5 ns | |
| asr (arithmetic shift right) | 5 ns | |
| sin_lookup | 7 ns | |
| clock_gettime (framework floor) | ~120 ns | Use batch mode for sub-µs ops |
| Direct function call | ~3 ns | |
| Inline (token replay) | ~2 ns | |

## Toolchain Size

| Component | Size |
|-----------|------|
| Bootstrap seed (bootstrap/asm) | 29 KB |
| Stage1f compiler | 12 KB |
| Assembler (asm) | 29 KB |
| Full compiler (cc3) | 250 KB |
| cyrius build tool | 59 KB |
| **Total toolchain** | **~380 KB** |

The entire Cyrius toolchain fits in well under half a megabyte. GCC: ~100 MB. Clang/LLVM: ~500 MB. Rust: ~800 MB.

## Standard Library

**40 stdlib modules + 5 deps**, 200+ functions.

| Category | Modules |
|----------|---------|
| Core | string, fmt, alloc, io, vec, str, args, fnptr |
| Types | tagged, hashmap, hashmap_fast, trait, assert, bounds |
| System | syscalls, callback, process, bench |
| Concurrency | thread, async, freelist |
| Data | json, toml, csv, base64, regex, math, matrix, bigint |
| Network | net, http, ws, tls |
| Filesystem | fs |
| Audio | audio (ALSA PCM) |
| Logging | log |
| Time | chrono |
| Knowledge | vidya |
| Interop | mmap, dynlib |
| Tracing (dep) | sakshi, sakshi_full |
| Database (dep) | patra |
| Security (dep) | sigil |
| Hardware (dep) | yukti |

## Test Coverage

| Suite | Tests | Status |
|-------|-------|--------|
| Compiler (.tcyr) | 32 suites, **442 assertions** | All pass |
| Fuzz harnesses (.fcyr) | 4 | Clean |
| aarch64 (cross) | 26 | All pass |
| Heap map audit | 48 regions | 0 overlaps |
| Self-hosting | two-step | Byte-identical |

## Programs (57 total)

**CLI tools (19):** cat, echo, head, wc, grep, hexdump, tail, tr, uniq, sort, basename, cols, count, toupper, rot13, rev, nl, seq, tee, yes, true, false

**Algorithms (8):** fizzbuzz, primes, sieve, collatz, ackermann, gcd, brainfuck, life

**Data structures (4):** struct_list, alloctest, strtype, points

**Systems (3):** bitfield, asmtest, memset

**Kernel (3):** kernel_hello, isr_stub, agnos (58KB full kernel)

## Dependencies

- Linux x86_64 (or aarch64 for the cross target)
- /bin/sh (bootstrap only)
- **Nothing else**
