# cc3 READFILE 512KB Cap in Include Processing — RESOLVED

**Status: RESOLVED.** READFILE calls at `src/frontend/lex.cyr:1243`
and `:1478` now use `1048576 - op`, matching the 1 MB preprocess_out
buffer. The 4.8.4 post-GA retag added a `PP_IFDEF_PASS` size guard
that emits a clear *"expanded source exceeds 1 MB"* error on
overflow instead of silently truncating; the companion fix
(directive detection reads from the mmap'd `tmp` buffer so the
S+0 cap doesn't blind the scan) resolved the "expected '=', got
..." misleading-error class this issue was tracking. Entry kept
for history — downstream projects on ≥ 4.8.4 retagged don't need
to work around this anymore.

---

**Discovered:** 2026-04-11 during argonaut libro 1.0.2 integration
**Severity:** Medium — workaround exists but limits large projects
**Affects:** cc3 3.5.0 (and likely all cc3 versions since the 1MB buffer expansion in v3.4.5)

## Summary

The preprocessor's include-file read calls in `src/frontend/lex.cyr` use a hardcoded 512KB limit (`524288 - op`) even though the preprocess output buffer was expanded to 1MB in v3.4.5. This means include processing silently truncates when the cumulative expanded source exceeds 512KB, producing "expected '=', got ..." or "expected '}', got end of file" errors.

## Root Cause

Two READFILE calls in lex.cyr pass `524288 - op` as the max read size:

- **Line 1061:** `var nr = READFILE(fname, out + op, 524288 - op);`
- **Line 1209:** `var nr = READFILE(fname, out + op, 524288 - op);`

When `op` (current output position) exceeds 524288, the read size becomes negative or zero, and subsequent includes are silently dropped. The final size check at line 1080 correctly uses `1048576` (1MB), but the per-include reads never reach that point.

## Fix

Change both lines from `524288 - op` to `1048576 - op`:

```
# Line 1061
var nr = READFILE(fname, out + op, 1048576 - op);

# Line 1209
var nr = READFILE(fname, out + op, 1048576 - op);
```

This matches the buffer allocation at `0x44A000 preprocess_out [1048576]` and the final size check at line 1080.

## Impact

- **argonaut** (v0.97.0): Cannot include all 19 libro modules (~600KB expanded). Workaround: include only 7 core modules.
- **Any project** with >512KB of expanded source after include processing will hit this silently.
- The v3.4.20 changelog noted the stale cap was fixed, but only the final check was updated — the per-include reads were missed.

## Reproduction

```sh
# Create a project with >512KB of includes
# When piped to cc3, the expanded source truncates silently
cat large_project.cyr | ./build/cc3 2>&1
# Error: "expected '=', got fn" or "expected '}', got end of file"
```

## Related

- v3.4.20: Fixed stale preprocess_out cap (512KB → 1MB) — same class of bug
- v3.4.19: Silent stdin truncation
- v3.3.17: LEXHEX raw-vs-preprocessed buffer mismatch
- General pattern: fixed-size buffers in cc3 with stale caps across multiple locations
