# Language development notes

> Opinion piece from the outgoing agent. Read as orientation, not
> doctrine. The code + tests are authoritative; this file is for
> the "why this shape" questions that don't survive a grep.

## The 4.8.x trajectory worked

At 4.0.0 the compiler was already self-hosting and the stdlib was
credible. The temptation at every new minor is to grow the surface
area — add a tagged-union type, rewrite the IR, sketch a parser
generator. 4.8.x explicitly walked away from that. Every minor in
this cycle was either (a) closing a concrete consumer blocker or
(b) raising a measured perf ceiling. Nothing speculative.

The pattern that worked:

1. **Consumer reports a stopgap.** abaco's `ntheory::mod_mul`
   hand-rolls a double-and-add loop. bote hits a misleading parser
   error at ~525 KB compile units. These are real data points, not
   design daydreams.
2. **Triage answers whether it's stdlib surface.** The abaco
   math recommendation doc (`docs/issues/stdlib-math-recommendations-from-abaco.md`)
   is the template — each item accepts / modifies / declines with
   reasoning, and accepted items land in a numbered minor with
   pre-announced scope.
3. **Ship alphas in scope-disciplined chunks.** 4.8.4 and 4.8.5
   both ran 7-8 alphas, each alpha small enough that self-host
   byte-identical was the natural gate. When scope crept (4.8.5
   alpha3 tried the live libssl bridge but hit dynlib segfaults),
   I walked it back to interface-only and moved the implementation
   to its own planned minor. That's the shape — don't ship what
   you can't verify, don't over-promise what you can't finish.
4. **Benchmark the claim, or don't make it.** alpha7 of 4.8.4 and
   alpha2 of 4.8.5 both ended with benchmarks that locked in the
   "X× faster" shape. Without those, "register allocation"
   and "mulmod fast-path" are marketing words.

The close-out doctrine from `CLAUDE.md` ("closeout pass before
every minor/major bump") is load-bearing. Every minor I shipped
in this run used it as the gate, not as a ritual.

## What's genuinely hard about Cyrius

Not the language. The language is small (keywords countable on
two hands, grammar recursive-descent from the first commit). The
hard part is that the compiler compiles itself, which means every
change has two correctness proofs:

1. Does the new code do what it should?
2. Does it produce a byte-identical second-stage build?

(2) catches an enormous class of codegen drift you'd otherwise
ship. It's also the reason feature decisions should be
conservative — a neat-looking language extension that breaks
self-hosting costs a lot more than the feature earns.

The heap map (`src/main.cyr` header) is the other load-bearing
discipline. Every byte of compiler state has a named offset.
Every time a table needs to grow (fn_table 2048→4096 in 4.7.1,
tok_names 64→128 KB in 4.6.2, fn_regalloc add in 4.8.4-alpha4),
the heap map commits to the new layout and the code follows.
Skip that step, get subtle memory corruption. Every bug I
chased to a "misleading parser error" in the last two minors
traced back to an off-heap-map state overlap.

## Things that looked tempting and shouldn't land

- **Closures capturing variables.** Demand-gated per the roadmap;
  one vote (kavach). Adding them requires a real lifetime-
  analysis pass, and Cyrius's single-pass codegen would need to
  spill. Worth a minor when the second consumer shows up.
- **Generics / traits.** Same framing — one vote. The cost is
  not the syntax, it's the name-mangling table (every generic
  fn becomes N fns at instantiation time, blowing through the
  fn_table cap) and the parser pass to resolve the specialisations.
  When this lands it wants its own minor, not a drive-by.
- **Pure-Cyrius TLS implementation.** `lib/tls.cyr` carried a
  sigil-based scaffold pre-4.8.5 that always returned
  TLS_STATE_ERROR after ClientHello. Getting real crypto right
  is not a stdlib pass — it's a multi-minor effort plus a
  security audit. Shipping via `lib/dynlib.cyr` → libssl is
  the pragmatic path; the alpha3 interface scaffold set the API
  for that transition.
- **IR-based codegen to eliminate NOP padding.** The
  `#regalloc` peephole pads 7→3 byte rewrites with a 4-byte NOP
  so jump offsets stay anchored. Removing the padding requires
  a real layout pass (or some form of delayed emission), which
  means an IR. That's a 5.x-era concern, not a 4.8.x fix.

## Things that look small and aren't

- **Anything that touches the preprocessor.** bote's regression
  through the 4.8.4 retag traced to a 4.8.3 "look safer" cap that
  blinded the directive scanner on large compile units. Cyrius's
  preprocessor runs in three passes over one shared buffer — any
  cap raise or pointer redirect in one pass needs to match the
  others. When adding a new directive, test a ≥ 500 KB expanded
  unit deliberately.
- **Asm blocks that reference locals.** `[rbp-N]` offsets depend
  on param count AND local index AND (post-4.8.4) `#regalloc`
  state. The rbx-save slot at `[rbp-8]` in `#regalloc` fns shifts
  every user local by 8 bytes. Asm-block writers need to know
  which ABI they're in.
- **Compound assignment operators.** Shipped v3.10.3 and look
  like syntactic sugar, but `a[i] += x` needs to evaluate `a[i]`
  once, not twice. Cyrius's parser does the right thing for
  simple locals but gets careful with array subscripts; look at
  the existing patterns before adding a new compound form.

## Downstream pins — the silent risk

`docs/development/roadmap.md` has the candidate list. At the time
of writing, downstream pins look like:

- Ecosystem on 4.5.0 / 4.0.0 mostly.
- bote on 4.8.1 → blocked by the 4.8.4 retag until re-pinned.
- abaco on 4.8.3 → wants 4.8.5 for mulmod.

This fragmentation is only a problem if a security fix (like the
4.8.5-alpha3 CRLF hardening) doesn't actually propagate. Keep the
"v3.4.0 recommended minimum" language in `CLAUDE.md` current as
the floor rises.

## What the next agent should read before touching anything

1. `CLAUDE.md` — non-negotiables. Self-hosting gate, heap map
   discipline, two-step bootstrap, test-after-every-change.
2. `docs/development/roadmap.md` — what's shipped, what's next,
   what's deferred to 4.9 / 5.0. The 4.8.x items are almost all
   shipped; 4.8.6 (defmt) and 4.8.7 (f64_parse) are the pending
   committed work.
3. `docs/issues/stdlib-math-recommendations-from-abaco.md` — the
   triage template. Future consumer recommendation docs should
   use the same shape (per-item accept / modify / decline with
   reasoning + release assignment).
4. `CHANGELOG.md` — the source of truth. Every alpha, every beta,
   every GA carries its own entry with motivation + validation
   + roadmap delta. The `## [4.8.5]` GA entry is the template.
5. The latest `lib/u128.cyr` diff (asm block in `u128_divmod` +
   `u64_mulmod`). It's ~30 lines of code that illustrates the
   Cyrius asm-block idiom at its cleanest — worth studying
   before adding more asm-integrated stdlib helpers.

## On the 5.0 framing

The existing roadmap commits 5.0 to multi-platform only (Mach-O,
PE, RISC-V, bare-metal). Resist the urge to pile language
refinements onto the 5.0 theme — they slide to 5.x minors after
the platform cut. A narrow 5.0 keeps the auditable surface small
and the cut clean. Cyrius has already earned a pattern of hitting
minors that ship exactly what they said they would; 5.0 should
hold that line hardest.

---

*Written at the 4.8.5 handoff. Refresh or delete as the trajectory
drifts — this is an opinion, not a permanent artifact.*
