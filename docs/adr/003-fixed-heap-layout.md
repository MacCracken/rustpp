# ADR-003: Fixed Heap Layout over Dynamic Allocation

**Status**: Accepted
**Date**: 2026-03-28
**Context**: The compiler needs storage for tokens, names, variables, functions, and code.

## Decision

Use fixed-offset heap arrays allocated via a single `brk` syscall. No malloc, no free, no dynamic resizing within a compilation run.

## Rationale

- **Determinism**: Same input always produces same memory layout
- **No allocator needed**: The compiler itself has no alloc library dependency
- **Speed**: Direct offset calculation, no pointer chasing
- **Auditability**: Every buffer has a known address documented in the HEAP MAP

## Layout (v0.9.5)

```
0x00000  input_buf      131KB    Source text
0x20000  codebuf        192KB    Generated machine code
0x50000  tok_names       64KB    Identifier strings
0x60000  var_noffs/sizes  4KB    Variable metadata
0x8A000  fixup_tbl       16KB   Address fixup entries
0x8C000  compiler state   20KB   Counters, function/struct tables
0xA2000  tok_types       512KB   Token type array (65536 slots)
0x122000 tok_values      512KB   Token value array
0x1A2000 tok_lines       512KB   Token line numbers
0x222000 preprocess_out  256KB   Include expansion buffer
brk: 0x262000 (~2.4MB total)
```

## Consequences

- Fixed capacity limits (65536 tokens, 256 vars, 256 functions, 64 locals)
- Buffer overflow bugs are silent corruption — always add bounds checks
- Relocating buffers requires two-step bootstrap (ADR documented in vidya)
- Adjacent buffers with no guard bytes are time bombs (tok_names overflow, v0.9.2)
