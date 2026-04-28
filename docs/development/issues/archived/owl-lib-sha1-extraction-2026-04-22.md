# Extract SHA-1 into `lib/sha1.cyr` (currently private to `lib/ws_server.cyr`)

**Discovered:** 2026-04-22 during `owl` M6 implementation (git integration / change gutter)
**Severity:** Low (feature exists and works; the request is for API extraction so downstream consumers don't vendor-copy it)
**Affects:** Cyrius stdlib layout 5.6.0 → 5.6.4 (current)

## Summary

SHA-1 is implemented in the vendored stdlib but is buried inside
`lib/ws_server.cyr` as the private-by-convention `_wss_sha1(data, len,
digest_out)`. It was added for the RFC 6455 websocket handshake only,
and the `_wss_` prefix signals "this is an implementation detail of
ws_server." The same algorithm is also re-implemented separately in
`majra/src/ws.cyr:29` as `fn sha1(data, len)`.

Consumers that need SHA-1 outside a websocket context today face a
choice between:

1. `include "lib/ws_server.cyr"` — pulls in `net`, `http_server`,
   `base64`, `tagged`, `string`, `fmt`, etc. transitive deps just to
   reach the hash. Heavy.
2. Vendor-copy the ~70 lines of SHA-1 into a local file. Creates
   duplication that has to be re-synchronized when anyone fixes a bug
   (and FIPS 180-4 SHA-1 is the kind of thing that shouldn't be
   re-implemented per consumer).

`lib/sigil.cyr` (the AGNOS trust module) deliberately does **not**
ship SHA-1 — sigil is for trust/signatures and SHA-1 is collision-broken
for that use case. That's the right call for sigil but leaves non-trust
consumers stranded when they need SHA-1 for legitimate compat reasons
(git object IDs, legacy hashes in third-party formats).

Request: promote the existing SHA-1 to `lib/sha1.cyr` as a first-class
stdlib module with a clear public API.

## Reproduction

The current surface:

```sh
$ grep -n "^fn sha1\|^fn _wss_sha1" /home/macro/.cyrius/versions/5.6.4/lib/ws_server.cyr
44:fn _wss_sha1(data, len, digest_out) {
```

Verify sigil does not carry it:

```sh
$ grep -n "sha1\|SHA1" /home/macro/.cyrius/versions/5.6.4/lib/sigil.cyr
(no output)
```

Verify the majra duplicate:

```sh
$ grep -n "^fn sha1" /home/macro/Repos/majra/src/ws.cyr
29:fn sha1(data, len) {
```

Two impls in the ecosystem; neither publicly reachable by a consumer
that doesn't want the transitive websocket tree.

## Root cause (not a bug — a layout gap)

SHA-1 was added inline in `lib/ws_server.cyr` at the time websockets
shipped, because no other consumer needed it. When `lib/sigil.cyr`
later added SHA-256 / SHA-512 / HMAC / HKDF / AES-GCM, SHA-1 was
excluded (correctly for a trust module). No third home was created for
it, so it stayed private to ws_server.

## Proposed fix

Create `lib/sha1.cyr`:

```cyrius
# lib/sha1.cyr — FIPS 180-4 SHA-1
# Included by: lib/ws_server.cyr, consumer git-compat tools.
# NOT a trust primitive — SHA-1 is collision-broken for signatures.
# For signatures and content integrity, use lib/sigil.cyr's SHA-256/512.

fn sha1_rotl32(x, n) { ... }

# Compute SHA-1 of `len` bytes at `data`, write 20-byte digest to `digest_out`.
fn sha1(data, len, digest_out) { ... }
```

Migrate:
- `lib/ws_server.cyr` `_wss_sha1` → re-route to the new `sha1(...)`.
- `majra/src/ws.cyr` `sha1(data, len)` → remove the local copy, include
  `lib/sha1.cyr`. (Out-of-tree change; track as a majra patch bump once
  the stdlib lands.)

Naming note: `sha1` as a public name is clean; callers who care about
the "this is not for signatures" fence can read the module header
comment or lint for `sha1` use in a sigil context.

Add to `cyrius deps`' known-stdlib list so `[deps].stdlib = ["sha1", ...]`
resolves.

## Consumer-side workaround (until fix lands)

`owl` is vendor-copying the SHA-1 routine into `src/sha1.cyr` with an
explicit provenance header citing `lib/ws_server.cyr` and this issue.
When `lib/sha1.cyr` ships, the local copy gets deleted and `cyrius.cyml
[deps].stdlib` adds `"sha1"`. One-commit migration per consumer.

## Reporting consumer context

- Consumer: `owl` (repo at `/home/macro/Repos/owl`), a Cyrius-native
  `cat`/`bat`-style file viewer for AGNOS. M6 adds git integration
  (change markers in the gutter) via `.git/index` parsing + SHA-1
  comparison. This is a temporary scaffold; the plan is to swap to
  `sit` (planned AGNOS git replacement) as a dep once SIT ships.
- Second consumer today: `majra` (already vendors its own copy).
- Near-future consumer: `sit` itself will need SHA-1 for compat with
  existing git repos during migration.
- Recommended minimum for the fix: whatever 5.6.x patch picks this
  up, or early 5.7.x — small-language-polish arc closing in 5.6.4
  suggests 5.6.5+ as the natural slot.

## Why this fits the 5.6.x polish arc

The 5.6.x line has been closing language-polish items: `#must_use`
(v5.6.3), `@unsafe` (v5.6.3), `#deprecated` (v5.6.4), `#else`/`#elif`/
`#ifndef` (v5.6.1). Stdlib hygiene — promoting a de-facto-needed
primitive to a named module — fits the same shape: small, additive,
no compiler change, unblocks consumers without a churning interface.
