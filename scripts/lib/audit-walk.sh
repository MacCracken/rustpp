#!/bin/sh
# audit-walk.sh — shared fmt/lint walkers for cyrius audit and scripts/check.sh
#
# Sourced by both `scripts/check.sh` (the cyrius-repo audit) and by the
# `scripts/cyrius` dispatcher's `audit` subcommand, so both paths have
# identical skip-symlink semantics and output shape. If this file is not
# present next to the caller (e.g. old/partial installs), the caller must
# fall back to its own inline implementation.
#
# Functions:
#   audit_fmt_walk CYRFMT DIR [DIR ...]
#       Run cyrfmt on every non-symlink *.cyr file in the given dirs.
#       Sets globals: AW_FMT_FAIL (0/1), AW_FMT_SKIPPED, AW_FMT_FILES
#
#   audit_lint_walk CYRLINT DIR [DIR ...]
#       Run cyrlint on every non-symlink *.cyr file in the given dirs.
#       Sets globals: AW_LINT_TOTAL (warning count), AW_LINT_SKIPPED
#
# Symlinked files are treated as dep files (they belong to upstream and may
# track a different formatter baseline) and are skipped in both walkers.

audit_fmt_walk() {
    _cyrfmt="$1"; shift
    AW_FMT_FAIL=0
    AW_FMT_SKIPPED=0
    AW_FMT_FILES=""
    for _dir in "$@"; do
        for _f in "$_dir"/*.cyr; do
            [ -f "$_f" ] || continue
            if [ -L "$_f" ]; then
                AW_FMT_SKIPPED=$((AW_FMT_SKIPPED + 1))
                continue
            fi
            "$_cyrfmt" "$_f" > /tmp/aw_fmt_$$ 2>/dev/null
            if ! diff -q "$_f" /tmp/aw_fmt_$$ > /dev/null 2>&1; then
                AW_FMT_FAIL=1
                AW_FMT_FILES="$AW_FMT_FILES $(basename "$_f")"
            fi
            rm -f /tmp/aw_fmt_$$
        done
    done
}

audit_lint_walk() {
    _cyrlint="$1"; shift
    AW_LINT_TOTAL=0
    AW_LINT_SKIPPED=0
    for _dir in "$@"; do
        for _f in "$_dir"/*.cyr; do
            [ -f "$_f" ] || continue
            if [ -L "$_f" ]; then
                AW_LINT_SKIPPED=$((AW_LINT_SKIPPED + 1))
                continue
            fi
            _w=$("$_cyrlint" "$_f" 2>&1 | tail -1 | grep -o '^[0-9]*' || echo 0)
            [ -z "$_w" ] && _w=0
            AW_LINT_TOTAL=$((AW_LINT_TOTAL + _w))
        done
    done
}
