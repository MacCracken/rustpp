# Standard Library Reference

## Core Libraries

### string.cyr

Memory and string operations on null-terminated C strings.

| Function | Signature | Description |
|----------|-----------|-------------|
| `strlen` | `strlen(s) → len` | Length of null-terminated string |
| `streq` | `streq(a, b) → 0/1` | Compare two strings for equality |
| `memeq` | `memeq(a, b, n) → 0/1` | Compare n bytes |
| `memcpy` | `memcpy(dst, src, n)` | Copy n bytes |
| `memset` | `memset(dst, val, n)` | Fill n bytes with val |
| `memchr` | `memchr(s, c, n) → idx/-1` | Find byte in buffer |
| `strchr` | `strchr(s, c) → idx/-1` | Find byte in string |
| `print_num` | `print_num(n)` | Print decimal integer to stdout |
| `println` | `println(s)` | Print string + newline to stdout |

### alloc.cyr

Bump allocator using Linux brk syscall. Call `alloc_init()` before any allocation.

| Function | Signature | Description |
|----------|-----------|-------------|
| `alloc_init` | `alloc_init() → base` | Initialize heap (must call first) |
| `alloc` | `alloc(size) → ptr` | Allocate size bytes (8-byte aligned) |
| `alloc_reset` | `alloc_reset()` | Free all allocations (batch reset) |
| `alloc_used` | `alloc_used() → bytes` | Current allocation total |

### str.cyr

Fat string type: `{data: ptr, len: i64}`. Requires alloc.cyr + string.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `str_from` | `str_from(cstr) → Str` | Wrap C string as Str |
| `str_new` | `str_new(data, len) → Str` | Create from buffer + length |
| `str_len` | `str_len(s) → len` | Get length |
| `str_data` | `str_data(s) → ptr` | Get raw data pointer |
| `str_print` | `str_print(s)` | Print to stdout |
| `str_println` | `str_println(s)` | Print + newline |
| `str_eq` | `str_eq(a, b) → 0/1` | Compare two Str |
| `str_cat` | `str_cat(a, b) → Str` | Concatenate (allocates new) |
| `str_sub` | `str_sub(s, start, len) → Str` | Substring (shares data) |
| `str_clone` | `str_clone(s) → Str` | Deep copy |
| `str_contains` | `str_contains(s, needle) → 0/1` | Substring search |
| `str_starts_with` | `str_starts_with(s, prefix) → 0/1` | Prefix check |
| `str_ends_with` | `str_ends_with(s, suffix) → 0/1` | Suffix check |
| `str_index_of` | `str_index_of(s, byte) → idx/-1` | Find byte |
| `str_from_int` | `str_from_int(n) → Str` | Integer to string |
| `str_to_int` | `str_to_int(s) → n` | Parse string to integer |
| `str_trim` | `str_trim(s) → Str` | Strip whitespace |
| `str_split` | `str_split(s, sep) → vec` | Split by byte separator |
| `str_join` | `str_join(parts, sep) → Str` | Join vec of Str |
| `str_builder_new` | `str_builder_new() → sb` | Create string builder |
| `str_builder_add` | `str_builder_add(sb, str)` | Append Str |
| `str_builder_add_cstr` | `str_builder_add_cstr(sb, cstr)` | Append C string |
| `str_builder_add_int` | `str_builder_add_int(sb, n)` | Append integer |
| `str_builder_build` | `str_builder_build(sb) → Str` | Finalize to Str |

### vec.cyr

Dynamic array. Elements are i64. Requires alloc.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `vec_new` | `vec_new() → vec` | Create empty vec (cap=16) |
| `vec_len` | `vec_len(v) → len` | Current length |
| `vec_cap` | `vec_cap(v) → cap` | Current capacity |
| `vec_push` | `vec_push(v, val)` | Append (auto-grows) |
| `vec_pop` | `vec_pop(v) → val` | Remove + return last |
| `vec_get` | `vec_get(v, idx) → val` | Read at index (bounds-checked) |
| `vec_set` | `vec_set(v, idx, val)` | Write at index (bounds-checked) |
| `vec_find` | `vec_find(v, val) → idx/-1` | Linear search |
| `vec_remove` | `vec_remove(v, idx)` | Remove + shift left |

### io.cyr

File I/O wrappers around Linux syscalls.

| Function | Signature | Description |
|----------|-----------|-------------|
| `file_open` | `file_open(path, flags, mode) → fd` | Open file |
| `file_close` | `file_close(fd)` | Close file |
| `file_read` | `file_read(fd, buf, len) → n` | Read bytes |
| `file_write` | `file_write(fd, buf, len) → n` | Write bytes |
| `file_read_all` | `file_read_all(path, buf, max) → n` | Read entire file |
| `file_write_all` | `file_write_all(path, buf, len) → n` | Write entire file |
| `file_exists` | `file_exists(path) → 0/1` | Check if file exists |
| `print` | `print(msg, len)` | Write to stdout |
| `eprint` | `eprint(msg, len)` | Write to stderr |

### fmt.cyr

Formatting and printing utilities. Requires string.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `fmt_int` | `fmt_int(n)` | Print decimal to stdout |
| `fmt_hex` | `fmt_hex(n)` | Print hex (no prefix) |
| `fmt_hex0x` | `fmt_hex0x(n)` | Print hex with 0x prefix |
| `fmt_bool` | `fmt_bool(b)` | Print "true" or "false" |
| `fmt_pad` | `fmt_pad(n)` | Print n spaces |
| `fmt_byte` | `fmt_byte(b)` | Print byte as 2-digit hex |
| `fmt_int_buf` | `fmt_int_buf(n, buf) → len` | Integer to buffer |
| `fmt_hex_buf` | `fmt_hex_buf(n, buf) → len` | Hex to buffer |
| `fmt_sprintf` | `fmt_sprintf(buf, fmt, args) → len` | Printf-like (%d %x %s %%) |
| `fmt_printf` | `fmt_printf(fmt, args) → len` | Format + print to stdout |

### args.cyr

CLI argument parsing via /proc/self/cmdline. Requires string.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `args_init` | `args_init()` | Parse cmdline (call once) |
| `argc` | `argc() → count` | Number of arguments |
| `argv` | `argv(n) → cstr` | Get argument n (0-based) |

### fnptr.cyr

Indirect function calls via inline assembly.

| Function | Signature | Description |
|----------|-----------|-------------|
| `fncall0` | `fncall0(fp) → ret` | Call function pointer (0 args) |
| `fncall1` | `fncall1(fp, a) → ret` | Call with 1 arg |
| `fncall2` | `fncall2(fp, a, b) → ret` | Call with 2 args |

---

## Extended Libraries

### tagged.cyr

Tagged unions: Option, Result, Either. Requires alloc.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `tagged_new` | `tagged_new(tag, value) → ptr` | Create tagged value |
| `tag` | `tag(t) → tag` | Get discriminant |
| `payload` | `payload(t) → value` | Get payload |
| `None` | `None() → Option` | Create None |
| `Some` | `Some(val) → Option` | Create Some(val) |
| `is_none` | `is_none(opt) → 0/1` | Check if None |
| `is_some` | `is_some(opt) → 0/1` | Check if Some |
| `unwrap` | `unwrap(opt) → val` | Get value or abort |
| `unwrap_or` | `unwrap_or(opt, fallback) → val` | Get value or fallback |
| `Ok` | `Ok(val) → Result` | Create Ok(val) |
| `Err` | `Err(code) → Result` | Create Err(code) |
| `is_ok` | `is_ok(res) → 0/1` | Check if Ok |
| `is_err_result` | `is_err_result(res) → 0/1` | Check if Err |
| `result_unwrap` | `result_unwrap(res) → val` | Get value or abort |
| `result_unwrap_or` | `result_unwrap_or(res, fb) → val` | Get value or fallback |
| `option_print` | `option_print(opt)` | Print "Some(N)" or "None" |
| `result_print` | `result_print(res)` | Print "Ok(N)" or "Err(N)" |

### hashmap.cyr

Hash table with string keys and i64 values. FNV-1a hash, open addressing. Requires alloc.cyr + string.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `map_new` | `map_new() → map` | Create empty map (cap=16) |
| `map_set` | `map_set(m, key, val)` | Set key=value (overwrites) |
| `map_get` | `map_get(m, key) → val` | Get value (0 if missing) |
| `map_has` | `map_has(m, key) → 0/1` | Check if key exists |
| `map_delete` | `map_delete(m, key) → 0/1` | Remove key |
| `map_count` | `map_count(m) → n` | Number of entries |
| `map_keys` | `map_keys(m) → vec` | All keys as vec |
| `map_print` | `map_print(m)` | Print {key: val, ...} |

### assert.cyr

Test assertions. Requires string.cyr + fmt.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `assert` | `assert(cond, name)` | Pass if cond == 1 |
| `assert_eq` | `assert_eq(a, b, name)` | Pass if a == b (shows got/expected) |
| `assert_neq` | `assert_neq(a, b, name)` | Pass if a != b |
| `assert_gt` | `assert_gt(a, b, name)` | Pass if a > b |
| `assert_summary` | `assert_summary() → fails` | Print results, return fail count |

### callback.cyr

Functional patterns via function pointers. Requires fnptr.cyr + vec.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `for_each` | `for_each(vec, &fn)` | Apply fn(item) to each |
| `vec_filter` | `vec_filter(vec, &fn) → vec` | Keep items where fn(item)==1 |
| `vec_map` | `vec_map(vec, &fn) → vec` | Transform each with fn(item) |
| `vec_fold` | `vec_fold(vec, init, &fn) → val` | Accumulate with fn(acc, item) |
| `vec_any` | `vec_any(vec, &fn) → 0/1` | True if any fn(item)==1 |
| `vec_all` | `vec_all(vec, &fn) → 0/1` | True if all fn(item)==1 |
| `vec_find_by` | `vec_find_by(vec, &fn) → item` | First match (0 if none) |
| `fork_with_pre_exec` | `fork_with_pre_exec(cmd, argv, envp, &cb, data) → pid` | Fork + callback + exec |

### bench.cyr

Benchmarking with nanosecond precision. Requires fnptr.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `bench_new` | `bench_new(name) → bench` | Create benchmark |
| `bench_start` | `bench_start(b)` | Start timer |
| `bench_stop` | `bench_stop(b) → ns` | Stop timer, return elapsed |
| `bench_run` | `bench_run(b, &fn, n)` | Run fn n times |
| `bench_avg_ns` | `bench_avg_ns(b) → ns` | Average nanoseconds |
| `bench_min_ns` | `bench_min_ns(b) → ns` | Minimum |
| `bench_max_ns` | `bench_max_ns(b) → ns` | Maximum |
| `bench_report` | `bench_report(b)` | Print formatted report |
| `bench_report_all` | `bench_report_all(vec)` | Print all benchmarks |

### bounds.cyr

Opt-in runtime bounds checking. Aborts with error message on violation.

| Function | Signature | Description |
|----------|-----------|-------------|
| `checked_load64` | `checked_load64(buf, len, idx) → val` | Bounds-checked 64-bit read |
| `checked_store64` | `checked_store64(buf, len, idx, val)` | Bounds-checked 64-bit write |
| `checked_load8` | `checked_load8(buf, len, idx) → val` | Bounds-checked byte read |
| `checked_store8` | `checked_store8(buf, len, idx, val)` | Bounds-checked byte write |
| `checked_memcpy` | `checked_memcpy(dst, dlen, src, slen, n)` | Bounds-checked copy |

### trait.cyr

Vtable-based trait objects for polymorphic dispatch. Requires fnptr.cyr.

| Function | Signature | Description |
|----------|-----------|-------------|
| `trait_obj_new` | `trait_obj_new(vtable, data) → obj` | Create trait object |
| `trait_call0` | `trait_call0(obj, slot) → ret` | Call method (0 extra args) |
| `trait_call1` | `trait_call1(obj, slot, arg) → ret` | Call method (1 extra arg) |
| `display` | `display(obj)` | Print via Display trait |
| `to_string` | `to_string(obj) → Str` | String via Display trait |
| `int_as_display` | `int_as_display(n) → obj` | Wrap int as Display |
| `str_as_display` | `str_as_display(s) → obj` | Wrap Str as Display |

---

## System Libraries

### agnosys/syscalls.cyr

Linux x86_64 syscall bindings. 50 syscall numbers + 20+ wrappers.

See [agnosys documentation](cyrius-guide.md#agnos-system-libraries) for full API.

Key functions: `sys_open`, `sys_close`, `sys_read`, `sys_write`, `sys_fork`, `sys_execve`, `sys_pipe`, `sys_waitpid`, `sys_kill`, `sys_mount`, `sys_mkdir`, `sys_rmdir`, `sys_sigprocmask`, `sys_signalfd`, `sys_epoll_create`, `sys_epoll_ctl`, `sys_epoll_wait`, `sys_timerfd_create`.

Helper functions: `sigset_new`, `sigset_add`, `sigset_has`, `epoll_event_new`, `timerspec_new`, `WIFEXITED`, `WEXITSTATUS`, `WIFSIGNALED`, `WTERMSIG`, `is_err`, `err_code`.
