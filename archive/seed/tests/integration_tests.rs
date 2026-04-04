use std::fs;
use std::io::Write as _;
use std::process::Command;

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
    let dir = std::env::temp_dir().join(format!(
        "cyrius_seed_test_{}_{}_{}",
        std::process::id(),
        n,
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    dir
}

#[test]
fn run_exit_zero() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 60
    mov rdi, 0
    syscall
",
    );
    assert_eq!(code, 0);
}

#[test]
fn run_exit_42() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 60
    mov rdi, 42
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_hello_world() {
    let (code, stdout, _) = assemble_and_run(
        r#"
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
"#,
    );
    assert_eq!(code, 0);
    assert_eq!(stdout, "Hello, Cyrius!");
}

#[test]
fn run_hello_with_newline() {
    let (code, stdout, _) = assemble_and_run(
        r#"
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
"#,
    );
    assert_eq!(code, 0);
    assert_eq!(stdout, "hello\n\0");
}

#[test]
fn run_arithmetic_exit_code() {
    // Compute 10 + 32 = 42, exit with that
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rdi, 10
    add rdi, 32
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_sub_exit_code() {
    // 50 - 8 = 42
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rdi, 50
    sub rdi, 8
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_xor_zero() {
    // xor rdi, rdi = 0
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rdi, 99
    xor rdi, rdi
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 0);
}

#[test]
fn run_inc_dec() {
    // 40 + 1 + 1 = 42
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rdi, 40
    inc rdi
    inc rdi
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_loop_countdown() {
    // Count down from 10 to 0, accumulate in rdi
    // Final rdi = 10 (counted 10 iterations, adding 1 each time)
    let (code, _, _) = assemble_and_run(
        "
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
",
    );
    assert_eq!(code, 10);
}

#[test]
fn run_call_ret() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    call set_42
    mov rax, 60
    syscall
set_42:
    mov rdi, 42
    ret
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_push_pop() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 42
    push rax
    mov rax, 0
    pop rdi
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_extended_registers() {
    // Use r8-r15
    let (code, _, _) = assemble_and_run(
        "
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
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_conditional_jump_taken() {
    let (code, _, _) = assemble_and_run(
        "
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
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_conditional_jump_not_taken() {
    let (code, _, _) = assemble_and_run(
        "
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
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_jl_jg() {
    // 1 < 2, so jl should be taken
    let (code, _, _) = assemble_and_run(
        "
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
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_shift_ops() {
    // 1 << 5 = 32, 32 + 10 = 42
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rdi, 1
    shl rdi, 5
    add rdi, 10
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_and_or() {
    // 0xFF & 0x2A = 0x2A = 42
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rdi, 0xFF
    and rdi, 0x2A
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_nop_passthrough() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    nop
    nop
    nop
    mov rdi, 42
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_multiple_strings() {
    let (code, stdout, _) = assemble_and_run(
        r#"
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
"#,
    );
    assert_eq!(code, 0);
    assert_eq!(stdout, "AB\nCD\n");
}

// ═══════════════════════════════════════════════════════════════════════
// Memory displacement tests
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn run_mov_rsp_disp() {
    // Store 42 at [rsp - 8], read it back
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 16
    mov rax, 42
    mov [rsp + 8], rax
    mov rdi, [rsp + 8]
    add rsp, 16
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_mov_rbp_frame() {
    // Simulate a stack frame with RBP
    let (code, _, _) = assemble_and_run(
        "
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov rax, 42
    mov [rbp - 8], rax
    mov rdi, [rbp - 8]
    mov rsp, rbp
    pop rbp
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_mov_r15_disp() {
    // Use r15 with large displacement (disp32)
    let (code, _, _) = assemble_and_run(
        "
_start:
    # brk(0) to get heap
    mov rax, 12
    xor rdi, rdi
    syscall
    mov r15, rax
    # brk(r15 + 4096) to extend
    mov rdi, r15
    add rdi, 4096
    mov rax, 12
    syscall
    # store 42 at r15 + 0x100
    mov rax, 42
    mov [r15 + 0x100], rax
    # read it back
    mov rdi, [r15 + 0x100]
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_mov_negative_disp() {
    // Write at [rsp + 8], read back via [rsp + 8] after adjustment
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 32
    mov rax, 42
    mov [rsp + 24], rax
    # Move rbx to point at rsp+32, then read [rbx - 8] == [rsp + 24]
    mov rbx, rsp
    add rbx, 32
    mov rdi, [rbx - 8]
    add rsp, 32
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

// ═══════════════════════════════════════════════════════════════════════
// movzx tests
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn run_movzx_byte_load() {
    // Store a qword with value 0x2A (42) in low byte, read byte back
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 16
    mov rax, 0x0000FF2A
    mov [rsp], rax
    movzx rdi, [rsp]
    add rsp, 16
    mov rax, 60
    syscall
",
    );
    // movzx reads only the low byte (0x2A = 42)
    assert_eq!(code, 42);
}

#[test]
fn run_movzx_byte_disp() {
    // Read the second byte of a stored value
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 16
    mov rax, 0x002A00
    mov [rsp], rax
    movzx rdi, [rsp + 1]
    add rsp, 16
    mov rax, 60
    syscall
",
    );
    // Second byte of 0x002A00 in little-endian memory: [0x00, 0x2A, 0x00, ...] → byte at +1 = 0x2A
    assert_eq!(code, 42);
}

// ═══════════════════════════════════════════════════════════════════════
// lea tests
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn run_lea_address_compute() {
    // Use lea to compute rsp + 8, store value there, read back
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 16
    lea rcx, [rsp + 8]
    mov rax, 42
    mov [rcx], rax
    mov rdi, [rsp + 8]
    add rsp, 16
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

// ═══════════════════════════════════════════════════════════════════════
// cqo tests
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn run_cqo_signed_division() {
    // -10 / 3 = -3 → exit code 253 (unsigned byte)
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, -10
    mov rcx, 3
    cqo
    idiv rcx
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 253); // -3 as unsigned byte
}

#[test]
fn run_cqo_positive_division() {
    // 84 / 2 = 42
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 84
    mov rcx, 2
    cqo
    idiv rcx
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

// ═══════════════════════════════════════════════════════════════════════
// Tier 1+2 integration tests
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn run_movb_byte_store() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 16
    xor rax, rax
    mov [rsp], rax
    mov rax, 42
    movb [rsp], rax
    mov rdi, [rsp]
    add rsp, 16
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_movb_disp() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 16
    xor rax, rax
    mov [rsp], rax
    mov rax, 0x2A
    movb [rsp], rax
    mov rax, 0x01
    movb [rsp + 1], rax
    movzx rdi, [rsp]
    add rsp, 16
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_unsigned_branch_ja() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 200
    cmp rax, 100
    ja above
    mov rdi, 0
    mov rax, 60
    syscall
above:
    mov rdi, 42
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_unsigned_branch_jb() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 10
    cmp rax, 100
    jb below
    mov rdi, 0
    mov rax, 60
    syscall
below:
    mov rdi, 42
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_rep_movsb_memcpy() {
    let (code, stdout, _) = assemble_and_run(
        r#"
_start:
    sub rsp, 32
    mov rax, 0x0A6948
    mov [rsp], rax
    lea rsi, [rsp + 0]
    lea rdi, [rsp + 16]
    mov rcx, 3
    cld
    rep movsb
    mov rax, 1
    mov rdi, 1
    lea rsi, [rsp + 16]
    mov rdx, 3
    syscall
    add rsp, 32
    mov rax, 60
    xor rdi, rdi
    syscall
"#,
    );
    assert_eq!(code, 0);
    assert_eq!(stdout, "Hi\n");
}

#[test]
fn run_rep_stosb_memset() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 16
    mov rax, -1
    mov [rsp], rax
    lea rdi, [rsp + 0]
    xor rax, rax
    mov rcx, 8
    cld
    rep stosb
    mov rdi, [rsp]
    add rsp, 16
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 0);
}

#[test]
fn run_shl_cl_variable_shift() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 1
    mov rcx, 5
    shl rax, rcx
    add rax, 10
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_sar_preserves_sign() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, -64
    sar rax, 1
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 224); // -32 as u8
}

#[test]
fn run_movsx_sign_extend() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    sub rsp, 16
    mov rax, 0xFF
    movb [rsp], rax
    movsx rax, [rsp]
    neg rax
    mov rdi, rax
    add rsp, 16
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 1);
}

#[test]
fn run_leave_epilogue() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov rax, 42
    mov [rbp - 8], rax
    mov rdi, [rbp - 8]
    leave
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

// ═══════════════════════════════════════════════════════════════════════
// Tier 3 integration tests
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn run_cmove_taken() {
    // cmove: move if equal (ZF=1)
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 99
    mov rbx, 42
    cmp rax, 99
    cmove rax, rbx
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42);
}

#[test]
fn run_cmove_not_taken() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 42
    mov rbx, 99
    cmp rax, 99
    cmove rax, rbx
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42); // cmove not taken, rax stays 42
}

#[test]
fn run_sete_true() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    xor rax, rax
    mov rbx, 42
    cmp rbx, 42
    sete rax
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 1); // equal → 1
}

#[test]
fn run_sete_false() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    xor rax, rax
    mov rbx, 42
    cmp rbx, 99
    sete rax
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 0); // not equal → 0
}

#[test]
fn run_xchg_swap() {
    let (code, _, _) = assemble_and_run(
        "
_start:
    mov rax, 10
    mov rbx, 42
    xchg rax, rbx
    mov rdi, rax
    mov rax, 60
    syscall
",
    );
    assert_eq!(code, 42); // rax was 10, now 42 after swap
}
