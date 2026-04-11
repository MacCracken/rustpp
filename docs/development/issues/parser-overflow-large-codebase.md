# Bug #32: Parser overflow at ~12K expanded lines

## Status: Open (blocking shravan)

## Symptom
Compiling shravan (audio codec) with AAC decoder (~12K expanded lines, 565 functions,
~2500 variables) fails with:
```
error:XXXX: expected ')', got identifier 'F'
```
on an unrelated line. Adding ~300 lines of new code triggers the failure. The error
is not in the new code — removing unrelated functions elsewhere makes it compile.

## Reproduction
```bash
cd ../shravan
cyrius build src/main.cyr build/shravan
# with AAC decoder added to lib/aac.cyr
```

## Suspected cause: table overflow
One of the compiler's fixed-size tables overflows silently, corrupting adjacent memory.
Candidates:

| Table | Location | Size | Capacity | Notes |
|-------|----------|------|----------|-------|
| tok_names | 0x60000 | 64KB | ~6500 names | Packed identifier strings, dedup |
| var_noffs | 0x11A000 | 64KB | 8192 vars | Variable name offsets |
| fn_names | 0xC0000 | 16KB | 2048 fns | Function name offsets |
| fixup_tbl | 0xA0000 | 128KB | 8192 entries | Relocation fixups |
| preprocess_out | 0x44A000 | 512KB | ~12K lines | Expanded source buffer |
| input_buf | 0x00000 | 128KB | ~12K lines | Raw stdin input |

The most likely candidate is **tok_names** (64KB). With 565 functions + 2500 variables
plus stdlib names (~200+ functions from sigil, alloc, vec, hashmap, etc.), the packed
identifier table could exceed 64KB. When it overflows, it corrupts `str_data` at 0x68000
(nested in tok_names upper half) or `str_pos` at 0x70000.

## Fix approach
1. Check: does NPOS (name position counter) exceed 65536? Add overflow check + error.
2. If confirmed: expand tok_names from 64KB to 128KB, shift downstream regions.
3. Or: improve name dedup to reduce storage.

## Investigation steps
- [ ] Add overflow check in SNPOS / name registration
- [ ] Print NPOS at end of compilation for shravan
- [ ] Check other table usage (VCNT, FCNT, fixup count)
- [ ] Determine which table actually overflows
