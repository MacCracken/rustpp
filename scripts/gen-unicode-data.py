#!/usr/bin/env python3
# scripts/gen-unicode-data.py — build-time codegen for lib/unicode/* data tables.
#
# This is a one-shot generator that runs offline to refresh the Unicode tables
# baked into lib/unicode/. Its output (lib/unicode/_categories_data.cyr) is
# committed to the repo — users do NOT need to run this script. Re-run only
# when bumping to a new Unicode revision (current target: 17.0.0, released
# 2025-09-09).
#
# Why Python: this is a one-shot codegen tool, not part of the cyrius runtime
# or self-hosting chain. The cyrius project ethos ("own the toolchain") applies
# to the runtime + compiler — UCD parsing is offline build-machinery, the same
# category as the bash scripts in scripts/. A native cyrius UCD parser is not
# blocked by this script and could land in a later cycle if desired.
#
# Usage:
#   python3 scripts/gen-unicode-data.py
#
# Outputs:
#   lib/unicode/_categories_data.cyr — packed hex-pair encoded GeneralCategory
#   range table + range count + category-name table.
#
# Encoding format (per range, 14 ASCII hex chars):
#   bytes 0..2  start codepoint  (u24, big-endian — high byte first)
#   bytes 3..5  end   codepoint  (u24, big-endian, INCLUSIVE)
#   byte  6     general-category index (see GC_* enum in categories.cyr)
#
# Hex-pair encoding chosen because cyrius has no precedent for binary string
# literals (embedded NUL / high bytes); printable ASCII is lexer-safe and
# round-trips through `cyrius fmt` cleanly. Each byte costs 2 chars, so the
# blob is ~2x raw. For Unicode 17.0 GeneralCategory (~3500 ranges merged) the
# expanded form is ~50KB — comfortably below cc5's 8 MiB tok_values cap.

import re
import sys
import urllib.request

URL = "https://www.unicode.org/Public/17.0.0/ucd/extracted/DerivedGeneralCategory.txt"
URL_CASEFOLDING = "https://www.unicode.org/Public/17.0.0/ucd/CaseFolding.txt"
URL_UNICODEDATA = "https://www.unicode.org/Public/17.0.0/ucd/UnicodeData.txt"

# Order matches GeneralCategory enum in lib/unicode/categories.cyr.
# Index = enum value. 30 categories total per Unicode standard.
CAT_ORDER = [
    "Lu", "Ll", "Lt", "Lm", "Lo",        # Letter
    "Mn", "Mc", "Me",                    # Mark
    "Nd", "Nl", "No",                    # Number
    "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po",   # Punctuation
    "Sm", "Sc", "Sk", "So",              # Symbol
    "Zs", "Zl", "Zp",                    # Separator
    "Cc", "Cf", "Cs", "Co", "Cn",        # Other
]
CAT_IDX = {c: i for i, c in enumerate(CAT_ORDER)}


def fetch():
    print(f"fetching {URL}", file=sys.stderr)
    with urllib.request.urlopen(URL, timeout=30) as resp:
        return resp.read().decode("utf-8")


def parse(text):
    """Parse DerivedGeneralCategory.txt lines.

    Format examples:
        0030..0039    ; Nd # Nd  [10] DIGIT ZERO..DIGIT NINE
        0041..005A    ; Lu # L&  [26] LATIN CAPITAL LETTER A..LATIN CAPITAL LETTER Z
        00B5          ; Ll # L&       MICRO SIGN

    Skips aggregate categories (L, M, N, P, S, Z, C) — we want only the leaf
    2-char categories that map to enum entries.
    """
    rng = []
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        m = re.match(
            r"^([0-9A-Fa-f]+)(?:\.\.([0-9A-Fa-f]+))?\s*;\s*(\w+)\s*$", line
        )
        if not m:
            continue
        start = int(m.group(1), 16)
        end = int(m.group(2), 16) if m.group(2) else start
        cat = m.group(3)
        if cat not in CAT_IDX:
            continue  # aggregate (L, M, N, P, S, Z, C)
        rng.append((start, end, CAT_IDX[cat]))
    rng.sort()
    # Merge adjacent ranges sharing a category.
    merged = []
    for s, e, c in rng:
        if merged and merged[-1][1] + 1 == s and merged[-1][2] == c:
            merged[-1] = (merged[-1][0], e, c)
        else:
            merged.append([s, e, c])
    return merged


def emit_packed_hex(ranges):
    """Emit one big string: 14 hex chars per range, all concatenated.

    Returns (hex_blob, count).
    """
    chunks = []
    for s, e, c in ranges:
        if s > 0xFFFFFF or e > 0xFFFFFF:
            raise ValueError(f"codepoint > 24 bits: {s:x}..{e:x}")
        if c < 0 or c > 0xFF:
            raise ValueError(f"category index out of byte range: {c}")
        chunks.append(f"{s:06x}{e:06x}{c:02x}")
    return "".join(chunks), len(ranges)


def emit_cyrius_source(blob, count, category_text_count, source_url):
    """Emit lib/unicode/_categories_data.cyr."""
    # Chunk on a clean range boundary (each range is 14 hex chars) so the
    # cyrius-side dispatch can compute (piece_idx, offset_in_piece) from a
    # flat range index without crossing piece edges. 500 ranges per piece =
    # 7000 hex chars; safely under cc5's per-literal limits.
    RANGES_PER_PIECE = 500
    CHARS_PER_RANGE = 14
    CHUNK = RANGES_PER_PIECE * CHARS_PER_RANGE
    pieces = [blob[i : i + CHUNK] for i in range(0, len(blob), CHUNK)]

    out = []
    out.append("# lib/unicode/_categories_data.cyr — AUTO-GENERATED by")
    out.append("# `scripts/gen-unicode-data.py`. Do NOT edit by hand; the next")
    out.append("# regeneration will overwrite. Source of truth:")
    out.append(f"#   {source_url}")
    out.append(f"# Unicode 17.0.0 ({count} merged ranges; {category_text_count}")
    out.append("# total leaf categories). Encoding: 14 hex chars per range —")
    out.append("# 6 chars u24 start + 6 chars u24 end (inclusive) + 2 chars cat")
    out.append("# index. The category index aligns with the GeneralCategory")
    out.append("# enum in lib/unicode/categories.cyr (Lu=0, Ll=1, ..., Cn=29).")
    out.append("# Public surface lives in categories.cyr; this file is data.")
    out.append("")
    out.append(f"var _UNICODE_CAT_RANGE_COUNT = {count};")
    out.append(f"var _UNICODE_CAT_PIECE_COUNT = {len(pieces)};")
    out.append(f"var _UNICODE_CAT_RANGES_PER_PIECE = 500;")
    out.append("")
    for i, piece in enumerate(pieces):
        out.append(f'var _UNICODE_CAT_PIECE_{i} = "{piece}";')
    return "\n".join(out) + "\n"


# ── Case folding (v5.8.50) ────────────────────────────────────────────

def fetch_url(url):
    print(f"fetching {url}", file=sys.stderr)
    with urllib.request.urlopen(url, timeout=30) as resp:
        return resp.read().decode("utf-8")


def parse_simple_case(text):
    """Parse UnicodeData.txt → (uppercase_map, lowercase_map, titlecase_map).

    Each map is dict[cp, cp] for codepoints with a defined simple mapping.
    Codepoints whose mapping is empty (themselves) are NOT in the map —
    consumer-side `unicode_to_lower(cp)` returns cp unchanged on lookup
    miss.

    UnicodeData.txt fields (semicolon-separated, 0-indexed):
        0  codepoint
        12 simple uppercase mapping
        13 simple lowercase mapping
        14 simple titlecase mapping
    """
    upper = {}
    lower = {}
    title = {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        f = line.split(";")
        if len(f) < 15:
            continue
        try:
            cp = int(f[0], 16)
        except ValueError:
            continue
        if f[12]:
            upper[cp] = int(f[12], 16)
        if f[13]:
            lower[cp] = int(f[13], 16)
        if f[14]:
            title[cp] = int(f[14], 16)
    return upper, lower, title


def parse_full_fold(text):
    """Parse CaseFolding.txt → dict[cp, list[cp]].

    Includes 'C' (common, 1:1) and 'F' (full, 1:n) status entries; skips
    'S' (simple alt, redundant when F is present) and 'T' (Turkish-locale
    only — not applicable to general fold). All resulting lists have
    1, 2, or 3 codepoints.
    """
    fold = {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        # Strip trailing comment
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        f = [x.strip() for x in line.split(";")]
        if len(f) < 3:
            continue
        cp_str, status, mapping = f[0], f[1], f[2]
        if status not in ("C", "F"):
            continue
        try:
            cp = int(cp_str, 16)
        except ValueError:
            continue
        cps = [int(x, 16) for x in mapping.split()]
        fold[cp] = cps
    return fold


def emit_simple_table(mapping, label):
    """Encode a simple 1:1 case map as 12 hex chars per record:
    src(u24 BE, 6 chars) + dst(u24 BE, 6 chars). Sorted by src.

    Returns (hex_blob, count).
    """
    parts = []
    for src in sorted(mapping):
        dst = mapping[src]
        if src > 0xFFFFFF or dst > 0xFFFFFF:
            raise ValueError(f"{label}: cp > 24 bits {src:x}→{dst:x}")
        parts.append(f"{src:06x}{dst:06x}")
    return "".join(parts), len(mapping)


def emit_full_fold_table(fold):
    """Encode the full case fold as 26 hex chars per record:
    src(u24 BE, 6) + count(u8, 2) + cp1(u24 BE, 6) + cp2(u24 BE, 6) +
    cp3(u24 BE, 6). cp2 / cp3 are 0 when count < 3 / 2. Sorted by src.

    Returns (hex_blob, count).
    """
    parts = []
    for src in sorted(fold):
        cps = fold[src]
        n = len(cps)
        if n < 1 or n > 3:
            raise ValueError(f"full fold expansion not in [1,3]: {src:x} → {cps}")
        c1 = cps[0]
        c2 = cps[1] if n >= 2 else 0
        c3 = cps[2] if n >= 3 else 0
        for v in (src, c1, c2, c3):
            if v > 0xFFFFFF:
                raise ValueError(f"cp > 24 bits in full fold: {v:x}")
        parts.append(f"{src:06x}{n:02x}{c1:06x}{c2:06x}{c3:06x}")
    return "".join(parts), len(fold)


def emit_casefold_source(
    upper_blob, upper_count,
    lower_blob, lower_count,
    title_blob, title_count,
    fold_blob, fold_count,
    sources,
):
    """Emit lib/unicode/_casefold_data.cyr.

    Three simple tables (upper / lower / title) — 12 hex chars per record,
    chunked at 500 records (6000 chars/piece). One full-fold table —
    26 hex chars per record, chunked at 250 records (6500 chars/piece).
    """
    SIMPLE_PER_PIECE = 500
    SIMPLE_CHARS_PER_REC = 12
    FULL_PER_PIECE = 250
    FULL_CHARS_PER_REC = 26

    def chunk(blob, chars_per_rec, rec_per_piece):
        chunk_size = chars_per_rec * rec_per_piece
        return [blob[i : i + chunk_size] for i in range(0, len(blob), chunk_size)]

    upper_pieces = chunk(upper_blob, SIMPLE_CHARS_PER_REC, SIMPLE_PER_PIECE)
    lower_pieces = chunk(lower_blob, SIMPLE_CHARS_PER_REC, SIMPLE_PER_PIECE)
    title_pieces = chunk(title_blob, SIMPLE_CHARS_PER_REC, SIMPLE_PER_PIECE)
    fold_pieces = chunk(fold_blob, FULL_CHARS_PER_REC, FULL_PER_PIECE)

    out = []
    out.append("# lib/unicode/_casefold_data.cyr — AUTO-GENERATED by")
    out.append("# `scripts/gen-unicode-data.py`. Do NOT edit by hand; the next")
    out.append("# regeneration will overwrite. Sources of truth:")
    for s in sources:
        out.append(f"#   {s}")
    out.append("# Unicode 17.0.0. Four tables:")
    out.append("#   simple uppercase: 12 hex chars/rec (src u24 + dst u24)")
    out.append("#   simple lowercase: same")
    out.append("#   simple titlecase: same")
    out.append("#   full case fold:   26 hex chars/rec (src u24 + count u8 +")
    out.append("#                                       cp1/cp2/cp3 each u24)")
    out.append("# All tables sorted by src cp; consumer-side does binary search.")
    out.append("# Public surface lives in casefold.cyr; this file is data.")
    out.append("")
    out.append(f"var _UNICODE_UPPER_RECORD_COUNT = {upper_count};")
    out.append(f"var _UNICODE_UPPER_PIECE_COUNT = {len(upper_pieces)};")
    out.append(f"var _UNICODE_UPPER_RECORDS_PER_PIECE = {SIMPLE_PER_PIECE};")
    out.append("")
    for i, piece in enumerate(upper_pieces):
        out.append(f'var _UNICODE_UPPER_PIECE_{i} = "{piece}";')
    out.append("")
    out.append(f"var _UNICODE_LOWER_RECORD_COUNT = {lower_count};")
    out.append(f"var _UNICODE_LOWER_PIECE_COUNT = {len(lower_pieces)};")
    out.append(f"var _UNICODE_LOWER_RECORDS_PER_PIECE = {SIMPLE_PER_PIECE};")
    out.append("")
    for i, piece in enumerate(lower_pieces):
        out.append(f'var _UNICODE_LOWER_PIECE_{i} = "{piece}";')
    out.append("")
    out.append(f"var _UNICODE_TITLE_RECORD_COUNT = {title_count};")
    out.append(f"var _UNICODE_TITLE_PIECE_COUNT = {len(title_pieces)};")
    out.append(f"var _UNICODE_TITLE_RECORDS_PER_PIECE = {SIMPLE_PER_PIECE};")
    out.append("")
    for i, piece in enumerate(title_pieces):
        out.append(f'var _UNICODE_TITLE_PIECE_{i} = "{piece}";')
    out.append("")
    out.append(f"var _UNICODE_FOLD_RECORD_COUNT = {fold_count};")
    out.append(f"var _UNICODE_FOLD_PIECE_COUNT = {len(fold_pieces)};")
    out.append(f"var _UNICODE_FOLD_RECORDS_PER_PIECE = {FULL_PER_PIECE};")
    out.append("")
    for i, piece in enumerate(fold_pieces):
        out.append(f'var _UNICODE_FOLD_PIECE_{i} = "{piece}";')
    return "\n".join(out) + "\n"


def main():
    # Categories (v5.8.49)
    cat_text = fetch()
    ranges = parse(cat_text)
    blob, count = emit_packed_hex(ranges)
    print(f"categories: merged {count} ranges; blob = {len(blob)} hex chars", file=sys.stderr)
    cat_path = "lib/unicode/_categories_data.cyr"
    cat_src = emit_cyrius_source(blob, count, len(CAT_ORDER), URL)
    with open(cat_path, "w") as f:
        f.write(cat_src)
    print(f"wrote {cat_path}", file=sys.stderr)

    # Case folding (v5.8.50)
    ud_text = fetch_url(URL_UNICODEDATA)
    cf_text = fetch_url(URL_CASEFOLDING)
    upper, lower, title = parse_simple_case(ud_text)
    fold = parse_full_fold(cf_text)
    upper_blob, upper_n = emit_simple_table(upper, "upper")
    lower_blob, lower_n = emit_simple_table(lower, "lower")
    title_blob, title_n = emit_simple_table(title, "title")
    fold_blob, fold_n = emit_full_fold_table(fold)
    print(
        f"casefold: upper={upper_n} lower={lower_n} title={title_n} fold={fold_n}",
        file=sys.stderr,
    )
    cf_path = "lib/unicode/_casefold_data.cyr"
    cf_src = emit_casefold_source(
        upper_blob, upper_n,
        lower_blob, lower_n,
        title_blob, title_n,
        fold_blob, fold_n,
        sources=[URL_UNICODEDATA, URL_CASEFOLDING],
    )
    with open(cf_path, "w") as f:
        f.write(cf_src)
    print(f"wrote {cf_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
