# Consolidate `cyrius-lsp` config as a user-scope Claude Code plugin

**Filed:** 2026-05-02 during agnosys LSP-availability check
**Status:** ✅ Implemented 2026-05-02 in sibling repo
[`MacCracken/cyrius-plugins`](https://github.com/MacCracken/cyrius-plugins)
(separate repo per "clean separation of tasks" — language stays in
`MacCracken/cyrius`, Claude Code wiring lives in `cyrius-plugins`).
Install: `/plugin marketplace add MacCracken/cyrius-plugins` →
`/plugin install cyrius-lsp@cyrius-plugins`. Per-repo `.lsp.json`
copies in `cyrius/` and `vidya/` are removed once the plugin is
verified working.
**Severity:** Low — ergonomic / DX; LSP works in repos that have `.lsp.json`, fails silently in those that don't
**Affects:** Every Cyrius-language project consumed via Claude Code

## Summary

Claude Code discovers LSP servers via a `.lsp.json` file at the project
root. Today, `cyrius-lsp` is wired up by **copying that file into every
Cyrius repo**:

```
$ find ~/Repos -maxdepth 2 -name .lsp.json
/home/macro/Repos/cyrius/.lsp.json
/home/macro/Repos/vidya/.lsp.json
```

Both copies are byte-identical:

```json
{
  "cyrius": {
    "command": "cyrius-lsp",
    "args": [],
    "extensionToLanguage": {
      ".cyr": "cyrius",
      ".tcyr": "cyrius",
      ".bcyr": "cyrius",
      ".fcyr": "cyrius",
      ".scyr": "cyrius",
      ".smcyr": "cyrius"
    }
  }
}
```

Repos without it (e.g. `agnosys` as of this filing) get
`No LSP server available for file type: .cyr` from the Claude Code LSP
tool — hover, goToDefinition, documentSymbol all unavailable. The
problem isn't that LSP is broken; it's that the config doesn't follow
the developer to the project.

This proposal: stop copying `.lsp.json` into each repo. Ship one
**user-scope Claude Code plugin** that registers `cyrius-lsp` for every
Cyrius file extension, install it once, and delete the per-repo copies.

## Reproduction

From `~/Repos/agnosys` (no `.lsp.json` at root), invoking the LSP tool
on any `.cyr` / `.bcyr` / `.fcyr` file returns:

```
No LSP server available for file type: .cyr
```

The binary itself is healthy:

```
$ ls -l ~/.cyrius/bin/cyrius-lsp
-rwxr-xr-x 1 macro macro 65456 May  2 13:25 /home/macro/.cyrius/bin/cyrius-lsp
$ ~/.cyrius/bin/cyrius-lsp --help
[cyrius-lsp] warning: cc5 not found — diagnostics disabled
```

The second line is a separate, latent bug — see *Open issue* below.

## Why this matters

- **New Cyrius repos start broken.** Anyone scaffolding a new project
  (or working in `agnosys`, `zugot`, downstream consumers) gets no
  LSP until they remember to copy `.lsp.json` from one of the older
  repos. There's no scaffolding step that does this today.
- **Drift is silent.** When the schema or extension list changes,
  every repo's copy needs an update. Today that means each project
  carries its own divergence risk; the byte-identical state of
  `cyrius/` and `vidya/` is luck, not enforcement.
- **`.lsp.json` isn't really project state.** It points at a
  user-installed binary (`~/.cyrius/bin/cyrius-lsp`) and a fixed list
  of extensions defined by the language. Nothing in it varies per
  project. It belongs at user scope, not in the repo.

## Recommendation

### Option A: User-scope plugin (preferred)

Ship a single plugin under the Cyrius toolchain dir and install it
once at user scope.

**Layout:**

```
~/.cyrius/plugins/cyrius-lsp/
├── .claude-plugin/
│   └── plugin.json
└── .lsp.json
```

**`.claude-plugin/plugin.json`**

```json
{
  "name": "cyrius-lsp",
  "version": "0.1.0",
  "description": "Cyrius language server for .cyr/.tcyr/.bcyr/.fcyr/.scyr/.smcyr"
}
```

**`.lsp.json`** (same six extensions as today, plus an `env` block to
fix the `cc5 not found` warning — see *Open issue*):

```json
{
  "cyrius": {
    "command": "/home/macro/.cyrius/bin/cyrius-lsp",
    "env": {
      "PATH": "/home/macro/.cyrius/bin:/usr/local/bin:/usr/bin:/bin"
    },
    "extensionToLanguage": {
      ".cyr": "cyrius",
      ".tcyr": "cyrius",
      ".bcyr": "cyrius",
      ".fcyr": "cyrius",
      ".scyr": "cyrius",
      ".smcyr": "cyrius"
    }
  }
}
```

**Install once, globally:**

```sh
claude plugin install ~/.cyrius/plugins/cyrius-lsp --scope user
```

**Then remove the per-repo copies:**

```sh
rm ~/Repos/cyrius/.lsp.json
rm ~/Repos/vidya/.lsp.json
```

After install, every project on the machine — including ones not yet
created — picks up the LSP automatically. Single edit point:
`~/.cyrius/plugins/cyrius-lsp/.lsp.json`.

### Option B: Status quo + scaffolding step

Keep `.lsp.json` in each repo, but make `cyrius-init.sh` (or whatever
project scaffold tool the toolchain ships) drop the canonical copy
into new repos. Solves "new repos start broken"; doesn't solve drift,
doesn't solve "agnosys is already broken today."

### Option C: Both

Ship the user-scope plugin (A) AND have `cyrius-init.sh` skip the
`.lsp.json` step entirely now that the user-scope plugin handles it.
Effectively just A + a scaffold cleanup, listed separately because it
touches `cyrius-init.sh`.

## Open issue: `cc5 not found`

`cyrius-lsp` shells out to `cc5` for diagnostics. Run from an
interactive shell, `~/.cyrius/bin` is on `PATH` and it works. Run
under Claude Code's LSP launcher, the inherited environment doesn't
have `~/.cyrius/bin` on `PATH`, so `cyrius-lsp` falls back to:

```
[cyrius-lsp] warning: cc5 not found — diagnostics disabled
```

The existing `.lsp.json` files in `cyrius/` and `vidya/` do **not**
set `env.PATH`, which means diagnostics may have been silently off in
those repos as well. The Option A snippet above adds the `env` block
to fix this for everyone going forward.

Worth a separate proposal: `cyrius-lsp` could probe its own argv[0]
location and prepend that directory to its child-process search path
internally, so the `env` workaround isn't required. Out of scope
here.

## Severity rationale

LOW — every contributor with a fresh Cyrius repo can copy a
`.lsp.json` from another repo. The cost is a recurring papercut (new
repos broken until manually fixed) and a silent-failure mode (missing
`cc5` on PATH disables diagnostics without a loud error). Both go
away once the plugin is installed at user scope.

## What we're doing in agnosys (and other consumers)

agnosys is currently the affected case — no `.lsp.json`, no LSP. If
Option A is accepted, agnosys never needs one; the user-scope plugin
covers it. If Option A is rejected, agnosys gets a copy of the
existing file as a one-line fix and we revisit consolidation later.
