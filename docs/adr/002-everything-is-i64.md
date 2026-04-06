# ADR-002: Everything is i64

**Status**: Accepted
**Date**: 2026-03-25
**Context**: Needed a type model for a self-hosting compiler bootstrapped from assembly.

## Decision

All values are 64-bit integers. No separate float, bool, char, or pointer types at the machine level. Type annotations exist for documentation and future checking but do not affect code generation.

## Rationale

- **Simplicity**: One register width, one storage size, one calling convention
- **Bootstrap**: Assembly deals in machine words — mapping 1:1 eliminates abstraction
- **Floats**: Added in v0.9.2 as bit-pattern reinterpretation (SSE2 builtins on i64 values)
- **Pointers**: Just integers — address arithmetic works naturally
- **Structs**: Contiguous i64 fields at fixed offsets

## Consequences

- No type errors at compile time (values are untyped bits)
- Float operations require explicit `f64_from`/`f64_to` — no implicit conversion
- No method dispatch based on type — convention-based naming (`Point_scale`)
- Generics Phase 2 will add compile-time checks without changing codegen
