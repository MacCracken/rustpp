use std::process::Command;
use std::fs;
use std::io::Write as _;

fn assemble_and_run(source: &str) -> (i32, String, String) {
    let elf = cyrius_seed::assemble(source).unwrap();

    // Use a truly unique temp file via the OS
    let dir = tempdir();
    let bin_path = dir.join("bin");

    {
        let mut f = fs::File::create(&bin_path).unwrap();
        f.write_all(&elf).unwrap();
        f.sync_all().unwrap();
    }

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&bin_path, fs::Permissions::from_mode(0o755)).unwrap();
    }

    let output = {
        let mut attempts = 0;
        loop {
            match Command::new(&bin_path).output() {
                Ok(out) => break out,
                Err(e) if e.raw_os_error() == Some(26) && attempts < 10 => {
                    // ETXTBSY — kernel race, retry
                    attempts += 1;
                    std::thread::sleep(std::time::Duration::from_millis(5));
                }
                Err(e) => panic!("failed to execute binary: {}", e),
            }
        }
    };

    let code = output.status.code().unwrap_or(-1);
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

    let _ = fs::remove_dir_all(&dir);

    (code, stdout, stderr)
}

fn tempdir() -> std::path::PathBuf {
    use std::sync::atomic::{AtomicU64, Ordering};
    static CTR: AtomicU64 = AtomicU64::new(0);
    let n = CTR.fetch_add(1, Ordering::SeqCst);
    let dir = std::env::temp_dir()
        .join(format!("cyrius_seed_test_{}_{}_{}", std::process::id(), n,
            std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos()));
    fs::create_dir_all(&dir).unwrap();
    dir
}

#[test]
fn run_exit_zero() {
    let (code, _, _) = assemble_and_run("
_start:
    mov rax, 60
    mov rdi, 0
    syscall
");
    assert_eq!(code, 0);
}

#[test]
fn run_exit_42() {
    let (code, _, _) = assemble_and_run("
_start:
    mov rax, 60
    mov rdi, 42
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_hello_world() {
    let (code, stdout, _) = assemble_and_run(r#"
_start:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, 14
    syscall
    mov rax, 60
    mov rdi, 0
    syscall
msg:
    db "Hello, Cyrius!"
"#);
    assert_eq!(code, 0);
    assert_eq!(stdout, "Hello, Cyrius!");
}

#[test]
fn run_hello_with_newline() {
    let (code, stdout, _) = assemble_and_run(r#"
_start:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, 7
    syscall
    mov rax, 60
    mov rdi, 0
    syscall
msg:
    db "hello\n\0"
"#);
    assert_eq!(code, 0);
    assert_eq!(stdout, "hello\n\0");
}

#[test]
fn run_arithmetic_exit_code() {
    // Compute 10 + 32 = 42, exit with that
    let (code, _, _) = assemble_and_run("
_start:
    mov rdi, 10
    add rdi, 32
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_sub_exit_code() {
    // 50 - 8 = 42
    let (code, _, _) = assemble_and_run("
_start:
    mov rdi, 50
    sub rdi, 8
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_xor_zero() {
    // xor rdi, rdi = 0
    let (code, _, _) = assemble_and_run("
_start:
    mov rdi, 99
    xor rdi, rdi
    mov rax, 60
    syscall
");
    assert_eq!(code, 0);
}

#[test]
fn run_inc_dec() {
    // 40 + 1 + 1 = 42
    let (code, _, _) = assemble_and_run("
_start:
    mov rdi, 40
    inc rdi
    inc rdi
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_loop_countdown() {
    // Count down from 10 to 0, accumulate in rdi
    // Final rdi = 10 (counted 10 iterations, adding 1 each time)
    let (code, _, _) = assemble_and_run("
_start:
    xor rdi, rdi
    mov rcx, 10
loop:
    inc rdi
    dec rcx
    cmp rcx, 0
    jne loop
    mov rax, 60
    syscall
");
    assert_eq!(code, 10);
}

#[test]
fn run_call_ret() {
    let (code, _, _) = assemble_and_run("
_start:
    call set_42
    mov rax, 60
    syscall
set_42:
    mov rdi, 42
    ret
");
    assert_eq!(code, 42);
}

#[test]
fn run_push_pop() {
    let (code, _, _) = assemble_and_run("
_start:
    mov rax, 42
    push rax
    mov rax, 0
    pop rdi
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_extended_registers() {
    // Use r8-r15
    let (code, _, _) = assemble_and_run("
_start:
    mov r8, 10
    mov r9, 20
    mov r10, 12
    mov rdi, r8
    add rdi, r10
    # rdi = 22
    push r9
    pop rax
    add rdi, rax
    # rdi = 42
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_conditional_jump_taken() {
    let (code, _, _) = assemble_and_run("
_start:
    mov rax, 1
    cmp rax, 1
    je equal
    mov rdi, 99
    mov rax, 60
    syscall
equal:
    mov rdi, 42
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_conditional_jump_not_taken() {
    let (code, _, _) = assemble_and_run("
_start:
    mov rax, 1
    cmp rax, 2
    je wrong
    mov rdi, 42
    mov rax, 60
    syscall
wrong:
    mov rdi, 99
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_jl_jg() {
    // 1 < 2, so jl should be taken
    let (code, _, _) = assemble_and_run("
_start:
    mov rax, 1
    cmp rax, 2
    jl less
    mov rdi, 99
    mov rax, 60
    syscall
less:
    mov rdi, 42
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_shift_ops() {
    // 1 << 5 = 32, 32 + 10 = 42
    let (code, _, _) = assemble_and_run("
_start:
    mov rdi, 1
    shl rdi, 5
    add rdi, 10
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_and_or() {
    // 0xFF & 0x2A = 0x2A = 42
    let (code, _, _) = assemble_and_run("
_start:
    mov rdi, 0xFF
    and rdi, 0x2A
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_nop_passthrough() {
    let (code, _, _) = assemble_and_run("
_start:
    nop
    nop
    nop
    mov rdi, 42
    mov rax, 60
    syscall
");
    assert_eq!(code, 42);
}

#[test]
fn run_multiple_strings() {
    let (code, stdout, _) = assemble_and_run(r#"
_start:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg1
    mov rdx, 3
    syscall
    mov rax, 1
    mov rdi, 1
    mov rsi, msg2
    mov rdx, 3
    syscall
    mov rax, 60
    mov rdi, 0
    syscall
msg1:
    db "AB\n"
msg2:
    db "CD\n"
"#);
    assert_eq!(code, 0);
    assert_eq!(stdout, "AB\nCD\n");
}
