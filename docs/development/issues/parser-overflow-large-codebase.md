# Bug #32: Parser overflow at ~12K expanded lines

## Status: **Resolved in v3.3.17**

## Root cause
`tok_names` lived at `0x60000` and shared its upper half with `str_data` at
`0x68000`. When compiling shravan (~12K expanded lines, 565 functions,
~2500 variables) the packed identifier table grew past 32KB and clobbered
`str_data` — producing misleading parse errors on unrelated lines.

An adjacent bug (`LEXHEX`) read hex literals from the raw input buffer
(`S + p`) instead of the preprocessed buffer (`S + 0x44A000 + p`), which
masked the overflow for years because cc3's own source was small enough
that raw and preprocessed buffers overlapped.

## Fix (v3.3.17)
- Moved `str_data` from `0x68000` → `0x40000` (unused region).
- `tok_names` now has the full 64KB at `0x60000-0x70000`.
- Libro uses 26KB, self-compile uses 6KB, shravan fits with headroom.
- `LEXHEX` corrected to read from the preprocessed buffer.

See CHANGELOG.md `[3.3.17]` for full detail.

## Historical symptom (kept for reference)
Compiling shravan with AAC decoder added failed with:
```
error:XXXX: expected ')', got identifier 'F'
```
on an unrelated line. Adding ~300 lines of new code triggered the failure.
The error was not in the new code — removing unrelated functions elsewhere
made it compile. Classic silent-overflow signature.
