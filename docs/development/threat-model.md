# Cyrius Threat Model

> **Scope**: Cyrius is a systems language compiler and toolchain.
> It generates native ELF binaries from source code.
> Zero external dependencies. Zero unsafe code (by construction — assembly up).

## Trust Boundaries

| Boundary | Trust Level |
|----------|-------------|
| 29KB seed binary (bootstrap/asm) | Root of trust — auditable, committed, byte-exact |
| Source code (src/, lib/, programs/) | Trusted — developer-controlled |
| User input (compiled programs) | Untrusted — may contain arbitrary code |
| Syscall interface (Linux kernel) | Trusted — OS provides memory isolation |
| Generated binaries | Untrusted until verified — self-hosting proves compiler correctness |

## Attack Surface

| Area | Risk | Mitigation |
|------|------|------------|
| **Buffer overflow in compiler** | Malicious input overflows tok_names, codebuf, or fixup table | Bounds checks on ADDTOK (65536), LEXID (65000), fixup (1024) |
| **Heap layout corruption** | Adjacent buffers overflow silently | Guard checks, documented HEAP MAP, P-1 hardening |
| **Preprocessor path traversal** | `include "../../../etc/passwd"` reads arbitrary files | Include only processes files relative to CWD; no symlink resolution |
| **Integer overflow in alloc** | Large allocation wraps to small size | brk return value checked; returns 0 on failure |
| **Code injection via inline asm** | `asm { ... }` emits arbitrary bytes | By design — asm is a power tool, not a vulnerability |
| **Denial of service** | Extremely large source files | Input buffer capped at 131KB; token array at 65536 |
| **Supply chain** | Compromised compiler binary | **Narrow-scope self-hosting verification**: the compiler must produce byte-identical output when recompiling its own source (3-step fixpoint `cc_a → cc_b → cc_c; b == c`; pre-v5 this was `cc3 == cc3`, now `cc5 → cc5b → cc5c`). This invariant is check.sh-enforced on every commit across all active targets. **Note on scope**: this mitigates trusting-trust attacks against the compiler's own codegen only. It does NOT address platform-loader tolerance of the emitted binary (a separate "broad-scope" property — see `docs/architecture/cyrius.md` §"Self-hosting: two scopes of byte-identity"). |
| **Bootstrap trust** | Trusting the committed 29KB seed | Diverse double compilation possible; seed is auditable |

## Known Limitations

| Limitation | Impact | Planned Fix |
|-----------|--------|-------------|
| No memory safety | Buffer overflows in user programs possible | Ownership/borrow checker (v1.0+) |
| No stack canaries | Stack smashing undetected | Compiler-inserted canaries (future) |
| No ASLR | Predictable memory layout | Polymorphic codegen (post-v1.0) |
| No sandboxing | Generated binaries have full syscall access | Sandbox-aware borrow checker (post-v1.0) |
| Fixed-size arrays | Compiler crashes on capacity overflow | Dynamic allocation or larger fixed sizes |

## Security Scanning

`cyrc vet` scans for dangerous patterns:
- Raw `syscall(59, ...)` (execve) outside process.cyr/agnosys
- Unbounded loops without break conditions
- Missing null checks on pointer arguments

`cyrc deny` enforces policy:
- No shell execution in library code
- No network syscalls in core libraries
- Trusted path validation for include directives

## Reporting

Security issues: security@agnos.dev
Response SLA: 48 hours
Disclosure: 90-day coordinated

## Design Principles

- Zero external dependencies — no supply chain to compromise
- Self-hosting verification after every compiler change
- Byte-exact reproducibility — same source always produces same binary
- Fixed heap layout is documented and auditable
- P-1 hardening before every feature release
- `cyrius audit` must pass before every commit
