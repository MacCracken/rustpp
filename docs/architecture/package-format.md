# Cyrius Package Format

## Overview

Cyrius projects integrate with the AGNOS ecosystem via two files:

1. **`cyrius.toml`** — project manifest (like Cargo.toml), lives in the project repo
2. **zugot recipe** — build recipe for AGNOS (like PKGBUILD), lives in the zugot repo

## cyrius.toml — Project Manifest

```toml
[package]
name = "kybernet"
version = "0.9.0"
description = "PID 1 init system for AGNOS"
license = "GPL-3.0-only"
language = "cyrius"
entry = "src/main.cyr"
test = "src/test.cyr"

[build]
compiler = "cc2"           # cc2 or cc2_aarch64
output = "kybernet"        # binary name

[dependencies]
# Vendored stdlib in lib/ — no external deps
```

## .ark Package Format

Created by `cyrius package`, installed by `ark install`.

```
kybernet-0.9.0.ark (gzipped tar)
├── manifest.json          metadata
└── kybernet               compiled binary
```

## zugot Recipe (for AGNOS system builds)

Lives in the zugot repo (e.g., `zugot/base/kybernet.toml`):

```toml
[package]
name = "kybernet"
version = "0.9.0"
description = "PID 1 init system for AGNOS"
license = "GPL-3.0-only"
groups = ["base", "core", "init"]
release = 1
arch = "x86_64"

[source]
github_release = "MacCracken/kybernet"
release_asset = "kybernet-x86_64"
sha256 = ""  # TODO: fill after release

[depends]
runtime = []               # no runtime deps (static binary)
build = ["cyrius"]         # needs cc2 to build from source

[build]
configure = ""
make = "cat src/main.cyr | cc2 > build/kybernet && chmod +x build/kybernet"
check = "cat src/test.cyr | cc2 > /tmp/test && chmod +x /tmp/test && /tmp/test"
install = "install -Dm755 build/kybernet $PKG/usr/bin/kybernet"

[security]
hardening = ["pie", "fullrelro"]
```
