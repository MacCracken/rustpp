# Process Notes — Phase 0 Build

> Observations from building rustc from source. These inform what Cyrius must fix.

## Date: 2026-04-03

### What We Did

1. Added rust-lang/rust as a shallow submodule at `upstream/`
2. Discovered cargo is a nested submodule — had to `git submodule update --init --depth 1 src/tools/cargo` separately
3. Installed `ninja` (missing build dep)
4. Created `bootstrap.toml` with `profile = "compiler"` and `change-id = "ignore"`
5. Ran `python3 x.py build` — completed in 5:19
6. Result: `rustc 1.96.0-dev` (stage 1)

### Problems Observed

#### 1. Nested Submodules
- rust-lang/rust contains 12+ submodules (cargo, LLVM, gcc, book, reference, etc.)
- Each must be initialized separately or with `--recursive` (which pulls everything)
- Shallow clones help but add complexity
- **Cyrius fix**: single repo. No submodules. The compiler, stdlib, and package manager live in one tree.

#### 2. Python Bootstrap
- The entire build orchestration runs through `x.py`, a Python script
- Python 3 is a hard requirement to build Rust
- `x.py` downloads a pre-built beta `rustc` from Rust CI to compile the real compiler
- "Building from source" is actually "building from source + a binary you downloaded"
- **Cyrius fix**: self-hosting bootstrap. The Cyrius compiler builds the Cyrius compiler. A minimal seed binary is the only external dependency, and that's a one-time cost.

#### 3. External Build Dependencies
- cmake and ninja required for LLVM (unless using CI-built LLVM)
- CI-built LLVM is the default — saves time but means you're trusting a binary from someone else's CI
- **Cyrius fix**: own the entire toolchain. No cmake, no ninja, no external LLVM binaries in the final state.

#### 4. Bootstrap Config Complexity
- `bootstrap.example.toml` is hundreds of lines
- Profiles (`compiler`, `library`, `tools`, etc.) help but the surface area is enormous
- `change-id` tracking for config schema changes is clever but adds friction
- **Cyrius fix**: minimal, opinionated defaults. One build command, no config file for the common case.

### What Worked Well

- CI-built LLVM made the build fast (5 min vs. 60+ min)
- `profile = "compiler"` gave sane defaults
- The stage 1 compiler works immediately
- 16 cores utilized well during compilation
