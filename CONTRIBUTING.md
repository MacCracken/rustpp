# Contributing to Cyrius

## Development Process

1. **Bootstrap**: `sh bootstrap/bootstrap.sh`
2. **Build compiler**: `cat stage1/cc2.cyr | ./build/stage1f > ./build/cc2 && chmod +x ./build/cc2`
3. **Make changes** to compiler or libraries
4. **Test**: `sh stage1/test_cc.sh ./build/cc2 ./build/stage1f`
5. **Self-host verify**: new cc2 compiles itself byte-identical
6. **Program tests**: `sh stage1/programs/test_programs.sh ./build/cc2`

## Rules

- Every change must pass all 168 tests with 0 failures
- Self-hosting must remain byte-identical (cc2 == cc3)
- No external dependencies — the entire toolchain bootstraps from a 29KB binary
- One change at a time. Test after each change, not after the feature is "done"
- If 3 attempts fail: defer, document root cause, move on

## Code Style

- Functions: `PascalCase` for compiler internals, `snake_case` for libraries
- Comments: `#` prefix, explain *why* not *what*
- No unnecessary abstractions — three similar lines > one premature helper

## License

All contributions are licensed under GPL-3.0-only.
