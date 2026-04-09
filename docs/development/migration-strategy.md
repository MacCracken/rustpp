# AGNOS Ecosystem Migration Strategy

> **107 Rust repos. ~980K lines. One language to replace them all.**
>
> This document tracks the Rust → Cyrius migration across the entire AGNOS ecosystem.
> For language development, see [roadmap.md](roadmap.md).
> For completed work, see [completed-phases.md](completed-phases.md).

---

## Overview

| Metric | Count |
|--------|-------|
| Total Rust repos | 107 |
| Total lines of Rust | ~980,000 |
| Already converted | 5 (wave 1) |
| Remaining | 102 |
| Repos depending on hisab | 37 |
| Repos using tokio (async) | 48 |
| Repos using serde | 90+ |

### Size Distribution

| Bracket | Repos | Strategy |
|---------|-------|----------|
| <1K lines | 18 | Direct port — minimal features needed |
| 1K–5K lines | 21 | Port with v1.0 features |
| 5K–15K lines | 51 | Need closures, iterators, generics |
| >15K lines | 17 | Need full Tier 2 + concurrency |

### Dependency Keystone

**hisab** (32K lines, math library) is the keystone — 37 repos depend on it.
Once hisab ports, a third of the ecosystem follows.

**bhava** (30K lines, emotion engine) — 8 direct dependents.
Both require: generics, operator overloading, const generics, derive macros.

---

## Migration Waves

### Wave 0 — Done

5 repos already converted in Cyrius (v0.9.0):

| Repo | Rust LOC | Cyrius LOC | Reduction |
|------|----------|------------|-----------|
| agnostik | ~2K | ~800 | 60% |
| agnosys | ~2K | ~600 | 70% |
| kybernet | 1,649 | 727 | 56% |
| nous | ~2K | ~500 | 75% |
| ark | ~4K | ~2K | 50% |

### Wave 1 — Small Repos (<1K lines)

18 repos, direct ports. No blocking language features.

| Repo | Lines | Notes |
|------|-------|-------|
| tanur | 924 | |
| abacus | 894 | |
| sutra | 829 | |
| nazar | 788 | |
| rahd | 521 | |
| taal | 453 | |
| kshetra | 426 | |
| natya | 399 | |
| shruti | 311 | |
| vinimaya | 269 | |
| mudra | 232 | |
| vidhana | 228 | |
| tazama | 0 | Skeleton |
| sutra-community | 0 | Skeleton |
| rasa | 0 | Skeleton |
| mneme | 0 | Skeleton |
| delta | 0 | Skeleton |
| aequi | 0 | Skeleton |

### Wave 2 — Medium Repos (1K–5K lines)

21 repos. Most need serde (JSON serialization). Subprocess bridge covers external deps.

| Repo | Lines | Key Deps |
|------|-------|----------|
| tara | 4,814 | hisab, serde |
| badal | 4,805 | hisab, serde |
| seema | 4,607 | tokio, serde |
| hisab-mimamsa | 4,519 | hisab, serde |
| brahmanda | 4,257 | hisab, serde |
| jnana | 4,130 | hisab, serde |
| selah | 4,096 | hisab, tokio, serde |
| shakti | 3,934 | serde |
| muharrir | 3,797 | serde |
| agnova | 3,656 | serde |
| prani | 3,527 | hisab, serde |
| ghurni | 3,054 | serde |
| vidya | 2,382 | serde |
| jalwa | 2,076 | tokio, serde |
| takumi | 2,034 | serde |
| aegis | 1,893 | serde |
| murti | 1,525 | tokio, serde |
| samay | 1,479 | serde |
| taswir | 1,329 | tokio, serde |
| ark | 4,363 | serde (already converted) |
| nous | 2,143 | serde (already converted) |

### Wave 3 — Keystone Libraries

Port the two libraries that unlock the rest:

| Repo | Lines | Dependents | Requires |
|------|-------|------------|----------|
| **hisab** | 31,795 | 37 repos | Generics, const generics, operator overloading, derive |
| **bhava** | 29,750 | 8 repos | Traits, iterators, closures, derive |

### Wave 4 — Hisab Dependents (5K–15K)

37 repos that depend on hisab. Port after hisab:

| Repo | Lines | Additional Deps |
|------|-------|----------------|
| vanaspati | 11,173 | hisab |
| goonj | 11,170 | hisab |
| naad | 10,503 | hisab |
| sankhya | 9,857 | hisab |
| ushma | 9,083 | hisab |
| svara | 8,785 | hisab |
| falak | 8,870 | hisab |
| dravya | 7,634 | hisab |
| pramana | 7,916 | hisab |
| nidhi | 7,180 | hisab |
| jivanu | 7,161 | hisab |
| kana | 7,015 | hisab |
| joshua | 6,657 | hisab, bhava |
| salai | 6,669 | hisab, bhava |
| bodh | 6,309 | hisab |
| pavan | 6,355 | hisab |
| sharira | 6,044 | hisab |
| sangha | 5,836 | hisab |
| jantu | 5,889 | hisab, bhava |

(Plus 18 more >10K lines: kiran, impetus, prakash, soorat, bijli, jyotish, khanij, pravash, kimiya, raasta, etc.)

### Wave 5 — Security + Infrastructure

| Repo | Lines | Requires |
|------|-------|----------|
| kavach | 25,935 | Ownership, sandbox borrow checker |
| phylax | 14,133 | Ownership |
| sigil | ~5K | Ownership |
| seema | 4,607 | tokio |
| majra | 12,969 | |
| nein | ~5K | |
| bote | ~5K | |
| t-ron | ~5K | |

### Wave 6 — AI + Platform

| Repo | Lines | Requires |
|------|-------|----------|
| ifran | 53,612 | Concurrency, generics |
| tarang | 33,438 | Concurrency |
| agnosai | 27,686 | Concurrency, bhava |
| agnoshi | 27,251 | Concurrency |
| aethersafha | 27,207 | Concurrency |
| hoosh | 21,833 | Concurrency, bhava |
| dhvani | 23,695 | Concurrency |
| raasta | 20,043 | hisab, tokio |
| kiran | 19,976 | hisab, bhava |
| ai-hwaccel | 17,335 | FFI, subprocess |
| stiva | 18,622 | |
| impetus | 18,414 | hisab |
| avatara | 18,804 | |

---

## Bridge Strategies

For repos with external dependencies that can't be ported:

### Subprocess (available now)

```cyrius
var args = vec_new();
vec_push(args, "/usr/bin/nvidia-smi");
vec_push(args, "--query-gpu=name");
var buf = alloc(4096);
var len = exec_capture(args, buf, 4096);
```

Covers: GPU detection, system tools, Python scripts, Node.js tools.

### C FFI Headers (available now)

```bash
cyrius header lib/mylib.cyr > mylib.h
```

Generates C prototypes. Other languages can see what functions exist.

### Shared Library (.so) — v1.1

Emit position-independent ELF shared objects. Enables `dlopen` from C/Python/Rust.

### Protocol Bridge — v1.1+

Cyrius services communicate via TCP/UDP (net.cyr). TypeScript/Python frontends
talk to Cyrius backends over HTTP or Unix domain sockets.

---

## Porting Patterns

### Rust → Cyrius Translation Guide

| Rust | Cyrius |
|------|--------|
| `fn foo(x: i64) -> i64` | `fn foo(x) { return ...; }` |
| `struct Point { x: f64, y: f64 }` | `struct Point { x; y; }` |
| `impl Point { fn sum(&self) }` | `impl Math for Point { fn sum(self) { } }` |
| `point.sum()` | `point.sum()` (same!) |
| `match result { Ok(v) => ..., Err(e) => ... }` | `match tag(result) { 0 => { var v = payload(result); } }` |
| `for i in 0..10` | `for i in 0..10` (same!) |
| `let f = \|x\| x * 2` | `var f = \|x\| x * 2;` |
| `vec![1, 2, 3]` | `var v = vec_new(); vec_push(v, 1); ...` |
| `String::from("hello")` | `var s: Str = str_from("hello");` |
| `s.len()` | `s.len()` (same!) |
| `HashMap::new()` | `map_new()` |
| `#[cfg(feature = "x")]` | `#ifdef X` |
| `mod math;` | `mod math;` (same!) |
| `use math::add;` | `use math.add;` |
| `pub fn` | `pub fn` (same!) |

### Per-Repo Workflow

1. Move Rust code to `rust-old/`
2. Create `src/`, `lib/`, `programs/` directories
3. Vendor Cyrius stdlib: `cyrius init --vendor`
4. Port module by module, test incrementally
5. Use subprocess bridge for external deps
6. Run `cyrius audit` before each commit

---

## Tracking

| Wave | Repos | Lines | Status |
|------|-------|-------|--------|
| 0 | 5 | ~12K | **Done** |
| 1 | 18 | ~6K | Ready to start |
| 2 | 21 | ~65K | Ready (serde = json.cyr) |
| 3 | 2 | ~62K | Needs generics + derive |
| 4 | 37 | ~300K | After wave 3 |
| 5 | 15 | ~80K | Needs ownership |
| 6 | 13 | ~350K | Needs concurrency |
| Remaining | ~10 | ~100K | After all features |
| **Total** | **107** | **~980K** | |

---

*This document is the source of truth for migration planning.*
*Language features are tracked in [roadmap.md](roadmap.md).*
*Completed ports are tracked in [completed-phases.md](completed-phases.md).*
