//! Benchmarks for the Cyrius seed assembler.
//! Uses std::time only — zero external dependencies.

use cyrius_seed::elf::emit_elf;
use cyrius_seed::encode::encode_inst;
use cyrius_seed::{assemble, parse, tokenize};
use std::collections::HashMap;
use std::time::Instant;

const ITERATIONS: u32 = 10_000;
const WARMUP: u32 = 1_000;

fn bench<F: FnMut()>(name: &str, mut f: F) {
    // Warmup
    for _ in 0..WARMUP {
        f();
    }

    // Measure
    let start = Instant::now();
    for _ in 0..ITERATIONS {
        f();
    }
    let elapsed = start.elapsed();

    let per_iter = elapsed / ITERATIONS;
    let throughput = if per_iter.as_nanos() > 0 {
        format!(
            "{:.1} ops/sec",
            1_000_000_000.0 / per_iter.as_nanos() as f64
        )
    } else {
        "∞".to_string()
    };

    println!("{:40} {:>10?}/iter  ({})", name, per_iter, throughput);
}

fn bench_throughput<F: FnMut() -> usize>(name: &str, mut f: F) {
    // Warmup
    for _ in 0..WARMUP {
        f();
    }

    let start = Instant::now();
    let mut total_bytes = 0usize;
    for _ in 0..ITERATIONS {
        total_bytes += f();
    }
    let elapsed = start.elapsed();

    let per_iter = elapsed / ITERATIONS;
    let mb_per_sec = total_bytes as f64 / elapsed.as_secs_f64() / 1_048_576.0;
    println!(
        "{:40} {:>10?}/iter  ({:.1} MB/s)",
        name, per_iter, mb_per_sec
    );
}

const HELLO_SOURCE: &str = r#"
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
"#;

fn generate_large_source(n: usize) -> String {
    let mut source = String::with_capacity(n * 30);
    source.push_str("_start:\n");
    source.push_str("    xor rcx, rcx\n");
    for i in 0..n {
        source.push_str(&format!("    add rcx, {}\n", i % 100));
        source.push_str("    nop\n");
        if i % 10 == 0 {
            source.push_str(&format!("label_{}:\n", i));
        }
    }
    source.push_str("    mov rdi, rcx\n");
    source.push_str("    mov rax, 60\n");
    source.push_str("    syscall\n");
    source
}

fn generate_disp_source() -> String {
    let mut s = String::new();
    s.push_str("_start:\n");
    s.push_str("    push rbp\n");
    s.push_str("    mov rbp, rsp\n");
    s.push_str("    sub rsp, 128\n");
    for i in 0..16 {
        let off = i * 8;
        s.push_str(&format!("    mov rax, {}\n", i));
        s.push_str(&format!("    mov [rbp - {}], rax\n", off + 8));
    }
    for i in 0..16 {
        let off = i * 8;
        s.push_str(&format!("    mov rax, [rbp - {}]\n", off + 8));
    }
    s.push_str("    lea rcx, [rsp + 64]\n");
    s.push_str("    movzx rax, [rcx]\n");
    s.push_str("    mov rax, 84\n");
    s.push_str("    mov rcx, 2\n");
    s.push_str("    cqo\n");
    s.push_str("    idiv rcx\n");
    s.push_str("    mov rdi, rax\n");
    s.push_str("    mov rsp, rbp\n");
    s.push_str("    pop rbp\n");
    s.push_str("    mov rax, 60\n");
    s.push_str("    syscall\n");
    s
}

fn main() {
    println!("═══════════════════════════════════════════════════════════════════");
    println!(
        "  Cyrius Seed Benchmarks ({} iterations, {} warmup)",
        ITERATIONS, WARMUP
    );
    println!("═══════════════════════════════════════════════════════════════════");
    println!();

    // ── Tokenizer ──
    println!("── Tokenizer ──");
    bench("tokenize hello.cyr", || {
        let _ = tokenize(HELLO_SOURCE);
    });

    let large_100 = generate_large_source(100);
    bench("tokenize 100 instructions", || {
        let _ = tokenize(&large_100);
    });

    let large_1000 = generate_large_source(1000);
    bench("tokenize 1000 instructions", || {
        let _ = tokenize(&large_1000);
    });

    let large_10000 = generate_large_source(10000);
    bench("tokenize 10000 instructions", || {
        let _ = tokenize(&large_10000);
    });
    println!();

    // ── Parser ──
    println!("── Parser ──");
    let hello_tokens = tokenize(HELLO_SOURCE).unwrap();
    bench("parse hello.cyr", || {
        let _ = parse(&hello_tokens);
    });

    let tokens_100 = tokenize(&large_100).unwrap();
    bench("parse 100 instructions", || {
        let _ = parse(&tokens_100);
    });

    let tokens_1000 = tokenize(&large_1000).unwrap();
    bench("parse 1000 instructions", || {
        let _ = parse(&tokens_1000);
    });

    let tokens_10000 = tokenize(&large_10000).unwrap();
    bench("parse 10000 instructions", || {
        let _ = parse(&tokens_10000);
    });
    println!();

    // ── Encoder ──
    println!("── Encoder ──");
    let labels: HashMap<String, usize> = [("x".to_string(), 100)].into();
    let test_insts = vec![
        cyrius_seed::parse::Inst::MovRegImm {
            dst: 0,
            imm: 42,
            line: 0,
        },
        cyrius_seed::parse::Inst::AddRegReg {
            dst: 0,
            src: 3,
            line: 0,
        },
        cyrius_seed::parse::Inst::Jmp {
            label: "x".into(),
            line: 0,
        },
        cyrius_seed::parse::Inst::Syscall { line: 0 },
    ];
    bench("encode 4 mixed instructions", || {
        for inst in &test_insts {
            let _ = encode_inst(inst, 0, &labels);
        }
    });
    println!();

    // ── ELF emission ──
    println!("── ELF Emission ──");
    let small_code = vec![0x90; 100];
    bench_throughput("emit_elf 100 bytes code", || {
        let elf = emit_elf(&small_code, 0);
        elf.len()
    });

    let medium_code = vec![0x90; 10_000];
    bench_throughput("emit_elf 10KB code", || {
        let elf = emit_elf(&medium_code, 0);
        elf.len()
    });

    let large_code = vec![0x90; 100_000];
    bench_throughput("emit_elf 100KB code", || {
        let elf = emit_elf(&large_code, 0);
        elf.len()
    });
    println!();

    // ── Full pipeline ──
    println!("── Full Pipeline (tokenize → parse → encode → elf) ──");
    bench_throughput("assemble hello.cyr", || {
        let elf = assemble(HELLO_SOURCE).unwrap();
        elf.len()
    });

    bench_throughput("assemble 100 instructions", || {
        let elf = assemble(&large_100).unwrap();
        elf.len()
    });

    bench_throughput("assemble 1000 instructions", || {
        let elf = assemble(&large_1000).unwrap();
        elf.len()
    });

    bench_throughput("assemble 10000 instructions", || {
        let elf = assemble(&large_10000).unwrap();
        elf.len()
    });

    // ── New instructions (memory displacement, movzx, lea, cqo) ──
    println!("── New Instructions ──");
    let disp_source = generate_disp_source();
    bench_throughput("assemble mem-disp program", || {
        let elf = assemble(&disp_source).unwrap();
        elf.len()
    });

    let disp_tokens = tokenize(&disp_source).unwrap();
    bench("tokenize mem-disp (brackets)", || {
        let _ = tokenize(&disp_source);
    });
    bench("parse mem-disp instructions", || {
        let _ = parse(&disp_tokens);
    });

    let disp_labels: HashMap<String, usize> = [("x".to_string(), 100)].into();
    let disp_insts = vec![
        cyrius_seed::parse::Inst::MovRegMemDisp {
            dst: 0,
            base: 4,
            disp: 8,
            line: 0,
        },
        cyrius_seed::parse::Inst::MovMemDispReg {
            base: 5,
            disp: -16,
            src: 0,
            line: 0,
        },
        cyrius_seed::parse::Inst::MovzxRegMemDisp {
            dst: 0,
            base: 3,
            disp: 4,
            line: 0,
        },
        cyrius_seed::parse::Inst::LeaRegMemDisp {
            dst: 0,
            base: 4,
            disp: 32,
            line: 0,
        },
        cyrius_seed::parse::Inst::Cqo { line: 0 },
    ];
    bench("encode 5 new instructions", || {
        for inst in &disp_insts {
            let _ = encode_inst(inst, 0, &disp_labels);
        }
    });

    println!();
    println!("═══════════════════════════════════════════════════════════════════");

    // ── Summary stats ──
    let large_elf = assemble(&large_10000).unwrap();
    println!("  10K instruction source: {} bytes", large_10000.len());
    println!("  10K instruction binary: {} bytes", large_elf.len());
    println!(
        "  Compression ratio:      {:.1}x",
        large_10000.len() as f64 / large_elf.len() as f64
    );
    println!("═══════════════════════════════════════════════════════════════════");
}
