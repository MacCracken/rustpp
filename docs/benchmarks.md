# Cyrius Benchmarks

> **This page moved.** As of v5.8.31's documentation audit (2026-05-03),
> the canonical place for binary-size and runtime comparison numbers is
> [`docs/size-comparisons.md`](size-comparisons.md). The compiler's own
> internal performance benchmarks live at
> [`docs/development/benchmarks.md`](development/benchmarks.md).
>
> The original v3.4.15 / 2026-04-11 content of this page was preserved as
> [`docs/development/archive/2026-04-11-benchmarks.md`](development/archive/2026-04-11-benchmarks.md)
> for historical reference. The numbers there cite `cc3` / `Stage1f`
> (now retired) and a stdlib that has roughly doubled in size since,
> so don't quote them as current — go to `size-comparisons.md` for the
> v5.8.x numbers.

## What's where

| You want… | Read this |
|-----------|-----------|
| `exit42` binary size across languages (C / Rust / Go / Zig / Cyrius) on Linux ELF + Windows PE | [`docs/size-comparisons.md`](size-comparisons.md) |
| Cyrius compiler self-host time, codebuf throughput, peephole / regalloc / DCE per-pass cost | [`docs/development/benchmarks.md`](development/benchmarks.md) |
| Per-stdlib-fn microbenchmarks (`fixed_mul`, `sin_lookup`, `clock_gettime` floor) | [`docs/development/benchmarks.md`](development/benchmarks.md) |
| Toolchain disk footprint (cc5 + cyrius + cyrfmt + cyrlint + …) | [`docs/size-comparisons.md`](size-comparisons.md) §"Cyrius self-host context" |

## Why this stub exists

Earlier versions of this file (through v5.6.43) bundled binary-size
comparisons, compiler microbenchmarks, and stdlib counts into one
document. As the project grew, those numbers diverged in update cadence:

- **Binary-size comparisons** are stable per release (refreshed at
  every minor/major in `size-comparisons.md`).
- **Compiler microbenchmarks** track per-arc optimization work and
  live alongside the optimization-arc histories in
  `docs/development/benchmarks.md`.

Splitting the doc kept each surface easier to refresh on its own
cadence. This stub stays at `docs/benchmarks.md` so external links
(README, vidya entries, CI workflow's "Required docs exist" check
in `.github/workflows/ci.yml`) keep resolving.
