# Cyrius Benchmarks

> Generated: 2026-04-04 | Platform: x86_64 Linux

## Binary Size: Cyrius vs GNU Coreutils

| Program | Cyrius | GNU | Smaller by |
|---------|--------|-----|-----------|
| true | 168 B | 39,144 B | **233x** |
| false | 168 B | 39,144 B | **233x** |
| echo | 240 B | 43,240 B | **180x** |
| yes | 368 B | 43,240 B | **117x** |
| head | 600 B | 51,432 B | **85x** |
| cat | 4,536 B | 47,368 B | **10x** |
| tee | 4,584 B | 47,336 B | **10x** |

**All 9 Cyrius programs combined: 17 KB** (vs ~300 KB for 7 GNU equivalents)

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
| cat 1MB pipe | 7ms | ~5ms | Near-identical |
| tr 1MB uppercase | 9ms | 6ms | Cyrius within 50% |
| wc 1MB analysis | 9ms | 22ms | **Cyrius 2.4x faster** |

With 4096-byte buffered I/O, Cyrius matches or beats GNU on I/O-bound tasks. The wc advantage comes from zero-overhead processing — no locale, no UTF-8 decoding, no libc abstraction layers. Raw syscalls with block-buffered reads.

Unbuffered (byte-by-byte) I/O is 85x slower — always buffer.

## Compile Speed

| Operation | Time |
|-----------|------|
| Build all 9 programs | 27ms total, 3ms each |
| Compiler self-compile (1960 lines) | 8ms |
| Full bootstrap (from 29KB seed) | 40ms |
| Assembler throughput | 1.3M lines/sec |

The compiler is faster than the OS can spawn it. Process startup (fork+exec) dominates at these sizes.

## Toolchain Size

| Component | Size |
|-----------|------|
| Bootstrap seed (bootstrap/asm) | 29 KB |
| Compiler (stage1f) | 12 KB |
| Assembler (asm) | 29 KB |
| Extended compiler (cc2) | 58 KB |
| **Total toolchain** | **128 KB** |

The entire Cyrius toolchain — bootstrap, compiler, assembler, extended compiler — fits in 128 KB. For comparison, GCC is ~100 MB installed, Clang/LLVM is ~500 MB.

## Test Coverage

| Suite | Tests | Status |
|-------|-------|--------|
| Compiler (cc2) | 80 | All pass |
| Assembler (asm) | 11 | All pass |
| Programs | 47 | All pass |
| **Total** | **138** | **0 failures** |

## Programs

19 CLI tools + 8 proof programs:

| Program | Size | Description |
|---------|------|-------------|
| true | 168 B | Exit 0 |
| false | 168 B | Exit 1 |
| echo | 240 B | Print string |
| yes | 368 B | Repeat "y" |
| head | 600 B | First N lines |
| seq | 840 B | Number sequence |
| nl | 1,248 B | Number lines |
| wc | 1,696 B | Count lines/words/bytes |
| sum | 2,176 B | Sum numbers from stdin |
| basename | 4,856 B | Strip directory from path |
| cat | 4,536 B | Copy stdin→stdout |
| tee | 4,584 B | Copy stdin→stdout+stderr |
| rev | 5,000 B | Reverse lines |
| cols | 5,280 B | Count max line width |
| grep | 5,496 B | Match pattern in lines |
| hexdump | 5,952 B | Hex dump of stdin |
| tr | 8,880 B | Character translation (buffered) |
| uniq | 9,864 B | Remove adjacent duplicates |
| tail | 66,592 B | Last 10 lines (64KB buffer) |

## Dependencies

- Linux x86_64
- /bin/sh
- **Nothing else**
