# cyrius init --language=none — scaffold gaps & output drift

**Discovered:** 2026-04-22 during `owl` bootstrap (first Cyrius consumer project; `cat`/`bat`-style file viewer for AGNOS)
**Severity:** Low (ergonomic papercuts; no correctness impact on the compiler, but a fresh scaffold fails `cyrius test` out of the box and generated docs point at the wrong manifest filename)
**Affects:** `cyrius-init.sh` 5.6.0 (`/home/macro/.cyrius/versions/5.6.0/bin/cyrius-init.sh`)

## Summary

Five drift/gap issues in `cyrius-init.sh` surfaced back-to-back on first use. In both a fresh empty dir and a docs-only existing repo, the scaffold completes successfully but:

1. `src/test.cyr` is announced as created but never written, while `cyrius.cyml [build].test` and the generated CI workflow both reference it — a fresh scaffold cannot `cyrius test`.
2. Generated `CLAUDE.md` (and the boilerplate comment in `src/main.cyr`) references `cyrius.toml` in the same breath as `cyrius.cyml`.
3. `--dry-run` lists four files (`CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `docs/development/` content) that a real `--language=none` run never creates.
4. `cyrius.cyml [package].description` is always written as an empty string; no flag, prompt, or placeholder.
5. The "directory already exists" error hint suggests the same command that just failed.

All five reproduce in an empty dir, so none are owl-specific.

## Reproduction

Baseline for issues 1–4:

```sh
mkdir /tmp/example-new && cd /tmp/example-new
/home/macro/.cyrius/versions/5.6.0/bin/cyrius-init.sh --language=none --agent=claude .
```

Baseline for issue 5:

```sh
mkdir -p /tmp/example-existing && cd /tmp && \
  /home/macro/.cyrius/versions/5.6.0/bin/cyrius-init.sh --language=none example-existing
```

### Issue 1 — `src/test.cyr` advertised but not written

Success output (from `cyrius-init.sh:647`):

```
  src/main.cyr — entry point
  src/test.cyr — test file
```

Actual:

```sh
$ ls src
main.cyr
```

`cyrius.cyml` is generated with (`cyrius-init.sh:261`):

```toml
[build]
entry = "src/main.cyr"
test = "src/test.cyr"
```

And `.github/workflows/ci.yml` (`cyrius-init.sh:383`):

```yaml
        run: cyrius test src/test.cyr
```

So on a zero-edit fresh scaffold, both local `cyrius test` and CI fail with ENOENT on `src/test.cyr`.

### Issue 2 — `cyrius.toml` vs `cyrius.cyml` drift in generated files

The generator writes `cyrius.cyml` (correct) but generated *documentation* and *source comments* reference the deprecated `cyrius.toml` form:

`CLAUDE.md` (`--agent=claude` preset, `cyrius-init.sh:531`):

```
- Dependencies declared in `cyrius.toml`
- Toolchain pinned in `cyrius.cyml [package].cyrius`
```

Two lines apart, two different filenames. Other presets hit the same (`cyrius-init.sh:462`, `565`).

`src/main.cyr` header (`cyrius-init.sh:272`, also `288`, `305`):

```
# Stdlib auto-included via cyrius.toml
```

Every new project ships with a wrong-filename comment at the top of its entry point.

### Issue 3 — `--dry-run` output doesn't match a real run

```sh
$ /home/macro/.cyrius/versions/5.6.0/bin/cyrius-init.sh --dry-run --language=none --agent=claude owl
Dry run: cyrius init owl

Would create (skip if exists in in-place mode):
  owl/
  owl/src/main.cyr
  owl/src/test.cyr            # ← never created (see Issue 1)
  owl/cyrius.cyml
  owl/VERSION            (0.1.0)
  owl/.gitignore
  owl/LICENSE            (GPL-3.0-only)
  owl/README.md
  owl/CHANGELOG.md
  owl/CONTRIBUTING.md          # ← never created under --language=none
  owl/SECURITY.md              # ← never created under --language=none
  owl/CODE_OF_CONDUCT.md       # ← never created under --language=none
  owl/CLAUDE.md          (agent preset: claude)
  ...
  owl/docs/development/        # ← empty dir (no content)
```

`grep -n 'write_if_absent' cyrius-init.sh` confirms there are no writers for `CONTRIBUTING.md` / `SECURITY.md` / `CODE_OF_CONDUCT.md`. The dry-run `echo` block at `cyrius-init.sh:95–128` is a hand-maintained list that has drifted from reality.

### Issue 4 — empty `description = ""`

Heredoc at `cyrius-init.sh:250–261` emits:

```toml
[package]
name = "example-new"
version = "0.1.0"
description = ""
license = "GPL-3.0-only"
```

No `--description` flag, no prompt, no derivation. Silently ships an empty manifest field that downstream (`cyrius publish`, `cyrius distlib`, ecosystem listings) has to handle or complain about later.

### Issue 5 — "already exists" hint is a false lead

```sh
$ /home/macro/.cyrius/versions/5.6.0/bin/cyrius-init.sh --language=none owl
ERROR: directory 'owl' already exists
  hint: use 'cyrius init --language=none owl' to scaffold in-place
```

The suggested command is the same command that just failed. In-place mode is triggered only by `NAME="."` (`cyrius-init.sh:89–93`); the comment there explicitly rejects auto-interpreting an existing `NAME` as in-place, so the behavior is intentional — the *hint* is the wrong part. Correct form is:

```sh
cd owl && /home/macro/.cyrius/versions/5.6.0/bin/cyrius-init.sh --language=none .
```

(Also: the `cbt` front-end only forwards two args to `cyrius-init.sh` — `cbt/cyrius.cyr:299` calls `cmd_init_args(argv(2), argv(3))` — so `cyrius init --language=none --agent=claude owl` via the front-end silently drops later args and reprints usage. Consumers have to invoke the script directly for any three-flag-or-more combination. Out of scope for this issue but mentioning for context; if the issues here get fixed, the cbt dispatcher cap will be the next thing consumers hit.)

## Root cause (speculation — all in `cyrius-init.sh` alone)

- **Issue 1**: missing `write_if_absent "$NAME/src/test.cyr" << EOF ... EOF` block adjacent to the `src/main.cyr` writer at `cyrius-init.sh:270`.
- **Issue 2**: literal string `cyrius.toml` in heredocs at lines 272, 288, 305, 462, 531, 565 (the source detection fallback at 592/596 correctly handles both names — this is stale boilerplate text).
- **Issue 3**: hand-maintained `echo` block at `cyrius-init.sh:95–128` drifted from the writer calls below.
- **Issue 4**: no codepath reads or derives a description; heredoc at `:250` hardcodes `description = ""`.
- **Issue 5**: hint text at `cyrius-init.sh:132`.

## Proposed fix

- **1**: either add the `src/test.cyr` writer (a stub `fn main() { return 0; } var r = main(); syscall(SYS_EXIT, r);` is enough for `cyrius test` to pass), **or** drop `test = "src/test.cyr"` from the generated `cyrius.cyml` and the `cyrius test src/test.cyr` line from `.github/workflows/ci.yml` so `cyrius test` picks up `tests/*.tcyr` naturally. Pick one.
- **2**: global-replace `cyrius.toml` → `cyrius.cyml` in the heredocs listed above. Audit all four `--agent=*` branches.
- **3**: generate the dry-run listing from the same writer-table the real path uses (loop over a declared `FILES=(...)` array, emit each either as "would write" or as the real heredoc), or at minimum gate each dry-run line on `$LANGUAGE`.
- **4**: add `--description=<str>`; when absent, default to something obviously temporary like `"<name> — TODO"` rather than empty string.
- **5**: change the hint at `:132` to `cd "$NAME" && cyrius init --language=none .` when `$NAME != "."`.

## Consumer-side workaround

- **1**: `touch src/test.cyr` post-init — or hand-edit `cyrius.cyml` to drop the `test =` line.
- **2**: post-init `sed -i 's/cyrius\.toml/cyrius.cyml/g' CLAUDE.md src/main.cyr`.
- **3**: trust the success summary (lines 641–647), ignore the dry-run listing.
- **4**: hand-edit `cyrius.cyml [package].description` post-init.
- **5**: always `cd <dir> && ... init --language=none .` when scaffolding into an existing dir. Do not invoke via the `cyrius` front-end when using ≥3 flags — call the script directly at `/home/macro/.cyrius/versions/<ver>/bin/cyrius-init.sh`.

## Reporting consumer context

- Consumer: `owl` (repo at `/home/macro/Repos/owl`), a Cyrius-native `cat`/`bat`-style file viewer for AGNOS.
- Cyrius version in use: 5.6.0 (also the version pinned in the generated `cyrius.cyml`).
- Recommended minimum for the fix: whatever release picks up these patches — none of the five require compiler changes, so a patch release to `cyrius-init.sh` is sufficient.
