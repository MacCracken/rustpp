# Security Policy

## Reporting Vulnerabilities

Report security issues to: security@agnosticos.org

Do **not** open public issues for security vulnerabilities.

## Scope

Cyrius is a systems language compiler. Security-relevant areas:

- **Compiler correctness**: codegen bugs that produce wrong behavior
- **Bootstrap chain integrity**: the 29KB seed binary is the root of trust
- **Kernel code**: AGNOS kernel memory safety, interrupt handling, syscall validation
- **Build tool (cyrb)**: fork/exec security, path handling
- **Package manager (ark)**: package verification, database integrity

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.9.x | Yes |
| < 0.9 | No |

## Response

We aim to respond to security reports within 48 hours and provide fixes within 7 days for critical issues.
