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

## Layout (v2.6, consolidated from v0.9.5)

```
0x00000  input_buf      128KB    Source text
0x20000  codebuf        256KB    Generated machine code
0x60000  tok_names       64KB    Identifier strings (dedup)
0x8A000  struct tables    24KB   Field types, names, counts
0x8C100  compiler state   14KB   Counters, scalars, patches
0x98000  gvar_toks        8KB    1024 deferred global inits
0xA0000  fixup_tbl      128KB    8192 fixup entries × 16 bytes
0xC0000  fn tables        48KB   names, offsets, params, inline
0xCC000  struct_fnames    8KB    32×32 field name offsets
0xCE000  output_buf     256KB    ELF output
0x10E000 var tables     192KB    8192 vars (noffs, sizes, types)
0x13E000 tok_types        1MB    131072 token type slots
0x23E000 tok_values       1MB    131072 token value slots
0x33E000 tok_lines        1MB    131072 token line number slots
0x43E000 preprocess_out 512KB    Include expansion buffer
brk: 0x4BE000 (~4.7MB total)
```

## Consequences

- Fixed capacity limits (131072 tokens, 8192 vars, 1024 functions, 256 locals, 1024 globals)
- Buffer overflow bugs are silent corruption — always add bounds checks
- Relocating buffers requires two-step bootstrap (ADR documented in vidya)
- Adjacent buffers with no guard bytes are time bombs (tok_names overflow, v0.9.2)
- Heap consolidation (v2.1) saved 2MB by compacting scattered regions
