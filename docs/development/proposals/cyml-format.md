# Proposal: CYML — Cyrius Markup Language

> **Status**: Proposal | **Date**: 2026-04-14
> **Author**: Robert MacCracken
> **Target**: Cyrius stdlib (`lib/cyml.cyr`)
> **Consumers**: vidya, memory systems, any structured-content-with-prose use case

---

## Problem

Three formats coexist in the AGNOS ecosystem, each solving half the problem:

**TOML** is used for structured config (`cyrius.toml`) and content databases (vidya's `concept.toml`, field notes). It handles typed fields well but forces long-form prose into triple-quoted strings — awkward escaping, no markdown rendering, backtick conflicts, unreadable diffs.

**Markdown** is used for documentation (`CLAUDE.md`, articles, docs). Agents read it natively (their dominant training format). Humans write it naturally. But it has no type system — a table in markdown is a drawing, not queryable data. Extracting structured fields requires parsing prose.

**YAML frontmatter** (markdown files with `---` delimited YAML headers) is used in the memory system. It's a workable hybrid but YAML has known problems: indentation-sensitive (fragile), implicit typing (the Norway problem: `NO` parses as `false`), flat structure only in practice.

No existing format cleanly combines typed structured headers with rich prose bodies in a way that's simultaneously machine-parseable, human-readable, and agent-native.

## Proposal

**CYML** (`.cyml`) — a file format that is TOML above the delimiter, markdown below it.

### Single-entry example

```
[meta]
name = "the_feel_of_the_language"
category = "cyrius"
tags = ["agent", "subjective"]
date = "2026-04-14"

---

Everything below the delimiter is markdown content.
Full prose. Code blocks. Lists. Headers. No escaping.

The TOML above is typed and queryable.
The markdown below is for humans and agents.
```

### Multi-entry example (vidya pattern)

```
[topic]
id = "compression"
title = "Compression"
tags = ["compression", "deflate", "lz4"]
related = ["algorithms", "binary_formats"]

[[entries]]
name = "lz4_for_speed"
type = "best_practice"

---

LZ4 decompresses at 3-5 GB/s with ~2:1 ratio. DEFLATE is what
zip/gzip/git use. Zstandard beats both on ratio at competitive
speed. Pick the algorithm for the use case, not the one you know.

[[entries]]
name = "deflate_bit_order"
type = "gotcha"

---

DEFLATE reads bits LSB-first within each byte. Most other formats
are MSB-first. Getting this wrong produces garbage that looks
almost-but-not-quite right — the most confusing class of bug.

```cyrius
// LSB-first (DEFLATE): read low bit first
bit = (byte >> bit_pos) & 1;
```
```

## Format Specification

### Structure

A `.cyml` file has two zones separated by a `---` delimiter:

1. **TOML zone** — everything above the first `---` (or above the first `---` after each `[[entries]]`)
2. **Markdown zone** — everything below the `---` until the next `[[entries]]` or EOF

### Parse rules

1. File starts in TOML mode.
2. `[[entries]]` on its own line starts a new entry's TOML header.
3. `---` on its own line (no leading/trailing content) switches from the current entry's TOML header to its markdown body.
4. The next `[[entries]]` or EOF ends the current entry's markdown body.
5. TOML blocks before the first `[[entries]]` are file-level metadata (e.g., `[topic]`, `[meta]`, `[file]`).
6. Leading/trailing whitespace on the markdown body is trimmed.
7. The TOML zone is parsed with the standard Cyrius TOML parser.
8. The markdown zone is stored as a raw string — no parsing, no transformation.

### File extension

`.cyml`

### Single-entry files

If a file has no `[[entries]]`, the entire TOML section is the header and everything below `---` is the body. This is the simple case — one header, one body.

### Multi-entry files

If a file has `[[entries]]`, each entry is a (TOML header, markdown body) pair. File-level metadata in `[table]` blocks before the first `[[entries]]` applies to the file as a whole.

### What the parser does NOT do

- No markdown parsing. The body is a raw string.
- No schema validation. The TOML header can contain any valid TOML.
- No templating. No variable substitution. No includes.
- No nested `.cyml` files.

## API

### Stdlib module: `lib/cyml.cyr`

```cyrius
// Parse a .cyml file into its components.
// Returns number of entries found, or negative error code.
// For single-entry files, returns 1.
// For multi-entry files, returns N.

fn cyml_parse(data, len, result)
// result is a pointer to a struct:
//   file_header_ptr, file_header_len    — file-level TOML (before first [[entries]])
//   entries_ptr                         — pointer to array of entry structs
//   entry_count                         — number of entries
//
// Each entry struct:
//   header_ptr, header_len              — entry TOML (the [[entries]] block)
//   body_ptr, body_len                  — markdown content (raw string)

// Convenience for single-entry files:
fn cyml_header(data, len)    // returns pointer to TOML section
fn cyml_body(data, len)      // returns pointer to markdown section
fn cyml_split(data, len, header_ptr, header_len_ptr, body_ptr, body_len_ptr)
```

### Implementation estimate

The parser is a linear scan:
1. Scan for `\n---\n` to find the first delimiter
2. Scan for `\n[[entries]]\n` to find entry boundaries
3. For each entry, scan for `\n---\n` to split header from body
4. Return pointers and lengths into the original buffer (zero-copy)

Estimated size: **80-120 lines** of Cyrius. No allocation needed for parsing — the result is pointers into the input buffer.

## Use Cases

### vidya (primary consumer)

Current `concept.toml` files use TOML with inline strings for prose:

```toml
[[best_practices]]
title = "Know your complexity class"
explanation = "An O(n^2) algorithm on 10M items will take hours..."

[[gotchas]]
title = "Off-by-one in binary search"
bad_example = "while lo < hi { mid = (lo + hi) / 2; ... }"
good_example = "while lo < hi { mid = lo + (hi - lo) / 2; ... }"
```

With cyml, the same content:

```
[[entries]]
name = "know_your_complexity_class"
type = "best_practice"

---

An O(n^2) algorithm on 10M items will take hours. A quick
complexity estimate tells you whether your approach is viable
before you write a line of code.

[[entries]]
name = "binary_search_off_by_one"
type = "gotcha"

---

Binary search is notoriously tricky. The most common bug:
wrong mid calculation, wrong boundary update, or wrong
termination condition.

```cyrius
// WRONG: overflow + infinite loop
while lo < hi { mid = (lo + hi) / 2; if arr[mid] < target { lo = mid } }

// CORRECT: safe midpoint, correct boundary
while lo < hi { mid = lo + (hi - lo) / 2; if arr[mid] < target { lo = mid + 1 } else { hi = mid } }
```
```

The prose is free. Code examples render naturally. No escaping. Diffs are clean.

### Field notes (vidya/content/cyrius/field_notes/)

Current field notes use `content = '''...'''` for multi-page entries. The `meta.toml` file has 540-line triple-quoted strings. With cyml, each section's prose is just markdown after `---`.

### Memory system (claude memory files)

Current: YAML frontmatter + markdown body. Could migrate to TOML frontmatter + markdown body — same shape, better typing, no YAML gotchas.

### CLAUDE.md

Stays as pure markdown. CLAUDE.md is a special case — it's read by Claude Code directly, not parsed by Cyrius tools. No migration needed.

## Migration Path

1. **Ship `lib/cyml.cyr`** in a Cyrius stdlib release (could be 5.x or earlier)
2. **vidya migrates first** — convert `concept.toml` files to `.cyml`, one topic at a time
3. **Field notes migrate** — convert `field_notes/*.toml` to `.cyml`
4. **Memory system evaluates** — optional, YAML frontmatter works fine for small files
5. **Other consumers adopt as needed** — any project with structured-content-with-prose

No breaking changes. TOML files continue to work. `.cyml` is additive.

## Alternatives Considered

**Keep TOML with triple-quoted strings.** Works but ugly. Backtick conflicts in code examples. Diffs are noisy. The format fights the content.

**Markdown with YAML frontmatter.** The memory system already uses this. YAML's implicit typing and indentation sensitivity are ongoing friction. TOML frontmatter would be better, but no standard exists for it.

**MDX (Markdown + JSX).** Web-specific. Adds React dependency concepts. Wrong ecosystem.

**Djot.** A better markdown spec. Still just prose — no structured header.

**Custom binary format.** Overkill. The content is text. The format should be text.

**TOML with `#ref` includes.** Cyrius already has `#ref` for TOML includes. This could be extended to reference external markdown files, but then every entry is two files (header + body) and the filesystem explodes.

## Decision Criteria

- **Parser complexity**: Must be implementable in <150 lines of Cyrius
- **Zero new dependencies**: Uses existing TOML parser
- **Agent readability**: Markdown body is the format agents read best
- **Human writability**: No escaping, no indentation rules, natural prose
- **Machine queryability**: TOML headers are typed, filterable, indexable
- **Migration cost**: Additive — doesn't break existing TOML usage

## Open Questions

1. **Should `cyml` be a stdlib module or a standalone crate?** Leaning stdlib — the parser is tiny and the format is foundational. Same as `lib/toml.cyr` being in stdlib.

2. **Should vidya's query API understand `.cyml` natively?** Probably yes — vidya already parses `concept.toml`. The cyml parser replaces the TOML triple-quote content extraction.

3. **Tooling**: Should `cyrius init` offer a `--cyml` flag for projects that want cyml content files? Low priority but natural extension.

---

*Proposed: 2026-04-14*
