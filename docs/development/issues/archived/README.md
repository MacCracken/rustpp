# Archived Issues

Resolved issue reports. Kept for history — so the next agent can
grep a symptom and find the fix version without re-investigating.

**Filing a new issue?** See [`../README.md`](../README.md) — this
folder is history only; active items and the submission template
live one level up.

Active issues live in the parent `docs/development/issues/`
folder; move them down here when fix verification lands and
cross-reference the CHANGELOG entry that closed them.

## Index

| File | Brief | Resolved in |
|------|-------|-------------|
| [`libro-unblock.md`](./libro-unblock.md) | Libro release blocker from the v3.4.20 P(-1) review — three missing `include` directives in `src/main.cyr` + silent undefined-function stubs. Cyrius side kept the warning → error policy on undefined fns; libro shipped the fix and is now at 1.0.3 in the ecosystem. | v3.4.20 libro-side + Cyrius diagnostic improvements through v4.x. |
| [`parser-overflow-large-codebase.md`](./parser-overflow-large-codebase.md) | Bug #32: parser overflow at ~12 K expanded lines — preprocessed buffer cap caught real consumers (agnosys, agnostik) with 256 KB sources. | **v3.3.17** — preprocess_out expanded to 1 MB. |
| [`readfile-512kb-cap.md`](./readfile-512kb-cap.md) | READFILE calls in `src/frontend/lex.cyr` used a hardcoded 512 KB cap after the preprocess_out buffer had grown to 1 MB — silent truncation producing misleading parse errors on large include graphs. | **v4.8.4 retag** — READFILE caps raised to 1 MB, `PP_IFDEF_PASS` size guard added, directive detection moved off the capped S+0 mirror onto the mmap'd `tmp` buffer. |

## Archival conventions

- File header gains a `— RESOLVED` suffix and a status paragraph
  pointing at the fix version + commit / CHANGELOG section.
- File name is unchanged so external links (consumer bug reports,
  PR descriptions) keep working.
- If a resolved issue returns under a new manifestation, open a
  fresh issue in the parent folder and cross-reference this one.
  Don't resurrect archived files in place.
