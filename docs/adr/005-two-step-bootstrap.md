# ADR-005: Two-Step Bootstrap for Compiler Changes

**Status**: Accepted
**Date**: 2026-04-05
**Context**: Heap layout changes break the bootstrap chain because the committed cc3 binary uses old offsets.

## Decision

Any compiler change that modifies heap offsets, token array sizes, or buffer locations requires a two-step (or three-step) bootstrap:

1. Old cc3 compiles new source → cc3 (has new layout, may differ from cc3)
2. cc3 compiles same source → cc4 (must equal cc3)
3. Verify cc3 == cc4 (byte-identical self-hosting)
4. Copy cc3 to build/cc3

## Rationale

- The old cc3 can compile the new source because it only uses ITS OWN offsets during compilation
- The GENERATED binary (cc3) has the new offsets
- cc3 compiling itself (cc4) must match cc3 — this proves correctness
- If cc3 != cc4, there's a real bug (not just bootstrap divergence)

## When Required

- Expanding token arrays (32K → 64K)
- Relocating var_noffs, var_sizes, or any named buffer
- Changing brk limit
- Adding block scoping (changes local variable indexing)

## Consequences

- Every heap change requires explicit verification
- The committed build/cc3 must always be the SECOND-generation binary
- Multi-backend changes (aarch64) must sync ALL offset references
