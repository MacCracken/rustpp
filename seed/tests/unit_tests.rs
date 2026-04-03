use cyrius_seed::*;
use cyrius_seed::token::{Token, tokenize, reg_code};
use cyrius_seed::parse::{Inst, parse};
use cyrius_seed::encode::{inst_size, encode_inst, rex, modrm};
use cyrius_seed::elf::emit_elf;
use cyrius_seed::error::SeedError;
use std::collections::HashMap;

// ═══════════════════════════════════════════════════════════════════════
// Register codes
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn reg_code_standard() {
    assert_eq!(reg_code("rax"), Some(0));
    assert_eq!(reg_code("rcx"), Some(1));
    assert_eq!(reg_code("rdx"), Some(2));
    assert_eq!(reg_code("rbx"), Some(3));
    assert_eq!(reg_code("rsp"), Some(4));
    assert_eq!(reg_code("rbp"), Some(5));
    assert_eq!(reg_code("rsi"), Some(6));
    assert_eq!(reg_code("rdi"), Some(7));
}

#[test]
fn reg_code_extended() {
    for i in 8..=15 {
        assert_eq!(reg_code(&format!("r{}", i)), Some(i));
    }
}

#[test]
fn reg_code_invalid() {
    assert_eq!(reg_code("eax"), None);
    assert_eq!(reg_code("r16"), None);
    assert_eq!(reg_code(""), None);
    assert_eq!(reg_code("RAX"), None); // case sensitive
}

// ═══════════════════════════════════════════════════════════════════════
// REX and ModR/M helpers
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn rex_basic() {
    assert_eq!(rex(true, 0, 0), 0x48);   // REX.W
    assert_eq!(rex(false, 0, 0), 0x40);  // plain REX
    assert_eq!(rex(true, 8, 0), 0x4C);   // REX.WR
    assert_eq!(rex(true, 0, 8), 0x49);   // REX.WB
    assert_eq!(rex(true, 8, 8), 0x4D);   // REX.WRB
}

#[test]
fn modrm_modes() {
    // mod=11 (register), reg=0 (rax), rm=1 (rcx)
    assert_eq!(modrm(0b11, 0, 1), 0b11_000_001);
    // mod=00 (memory), reg=3 (rbx), rm=5 (rbp)
    assert_eq!(modrm(0b00, 3, 5), 0b00_011_101);
}

// ═══════════════════════════════════════════════════════════════════════
// Tokenizer
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn tokenize_empty() {
    let tokens = tokenize("").unwrap();
    assert!(tokens.is_empty());
}

#[test]
fn tokenize_comments_only() {
    let tokens = tokenize("# this is a comment\n# another one").unwrap();
    assert!(tokens.is_empty());
}

#[test]
fn tokenize_label_def() {
    let tokens = tokenize("_start:").unwrap();
    assert!(matches!(&tokens[0], Token::LabelDef(name, 1) if name == "_start"));
}

#[test]
fn tokenize_mov_reg_imm() {
    let tokens = tokenize("mov rax, 42").unwrap();
    assert!(matches!(&tokens[0], Token::Instruction(n, _) if n == "mov"));
    assert!(matches!(&tokens[1], Token::Register(n, _) if n == "rax"));
    assert!(matches!(&tokens[2], Token::Immediate(42, _)));
}

#[test]
fn tokenize_hex_literal() {
    let tokens = tokenize("mov rax, 0xFF").unwrap();
    assert!(matches!(&tokens[2], Token::Immediate(255, _)));
}

#[test]
fn tokenize_negative_literal() {
    let tokens = tokenize("mov rax, -1").unwrap();
    assert!(matches!(&tokens[2], Token::Immediate(-1, _)));
}

#[test]
fn tokenize_string_with_escapes() {
    let tokens = tokenize(r#"db "hello\n\t\0\\\x41""#).unwrap();
    match &tokens[1] {
        Token::Bytes(bytes, _) => {
            assert_eq!(bytes, &[b'h', b'e', b'l', b'l', b'o', 0x0A, 0x09, 0x00, b'\\', 0x41]);
        }
        other => panic!("expected Bytes, got {:?}", other),
    }
}

#[test]
fn tokenize_string_with_spaces() {
    let tokens = tokenize(r#"db "Hello, Cyrius!""#).unwrap();
    match &tokens[1] {
        Token::Bytes(bytes, _) => {
            assert_eq!(bytes, b"Hello, Cyrius!");
        }
        other => panic!("expected Bytes, got {:?}", other),
    }
}

#[test]
fn tokenize_mem_operand() {
    let tokens = tokenize("mov [rax], rbx").unwrap();
    assert!(matches!(&tokens[1], Token::MemRegister(n, _) if n == "rax"));
}

#[test]
fn tokenize_inline_comment() {
    let tokens = tokenize("mov rax, 1 # write syscall").unwrap();
    // Should have: Instruction, Register, Immediate, Newline
    assert_eq!(tokens.len(), 4);
}

#[test]
fn tokenize_label_reference() {
    let tokens = tokenize("jmp loop_start").unwrap();
    assert!(matches!(&tokens[1], Token::Label(n, _) if n == "loop_start"));
}

#[test]
fn tokenize_all_instructions() {
    let source = "mov add sub cmp jmp je jne jl jg jle jge call ret push pop syscall \
                   db dq dw dd xor and or not neg inc dec nop lea test shl shr mul div imul idiv movzx int";
    let tokens = tokenize(source).unwrap();
    let inst_count = tokens.iter().filter(|t| matches!(t, Token::Instruction(..))).count();
    assert_eq!(inst_count, 38);
}

#[test]
fn tokenize_error_bad_hex() {
    let err = tokenize("mov rax, 0xZZ").unwrap_err();
    assert!(matches!(err, SeedError::InvalidHexLiteral { .. }));
}

#[test]
fn tokenize_error_unterminated_string() {
    let err = tokenize(r#"db "unterminated"#).unwrap_err();
    assert!(matches!(err, SeedError::UnterminatedString { .. }));
}

#[test]
fn tokenize_error_bad_escape() {
    let err = tokenize(r#"db "bad\q""#).unwrap_err();
    assert!(matches!(err, SeedError::InvalidEscape { ch: 'q', .. }));
}

#[test]
fn tokenize_line_numbers() {
    let tokens = tokenize("nop\nnop\nnop").unwrap();
    // Three nops on lines 1, 2, 3
    let lines: Vec<usize> = tokens.iter()
        .filter(|t| matches!(t, Token::Instruction(..)))
        .map(|t| t.line())
        .collect();
    assert_eq!(lines, vec![1, 2, 3]);
}

// ═══════════════════════════════════════════════════════════════════════
// Parser
// ═══════════════════════════════════════════════════════════════════════

fn parse_source(src: &str) -> Vec<Inst> {
    let tokens = tokenize(src).unwrap();
    parse(&tokens).unwrap()
}

#[test]
fn parse_mov_variants() {
    let insts = parse_source("mov rax, 42\nmov rbx, rcx\nmov [rax], rbx\nmov rax, [rbx]\nmov rsi, msg");
    assert!(matches!(insts[0], Inst::MovRegImm { dst: 0, imm: 42, .. }));
    assert!(matches!(insts[1], Inst::MovRegReg { dst: 3, src: 1, .. }));
    assert!(matches!(insts[2], Inst::MovMemReg { dst: 0, src: 3, .. }));
    assert!(matches!(insts[3], Inst::MovRegMem { dst: 0, src: 3, .. }));
    assert!(matches!(&insts[4], Inst::MovRegLabel { dst: 6, label, .. } if label == "msg"));
}

#[test]
fn parse_alu_reg_reg() {
    let insts = parse_source("add rax, rbx\nsub rcx, rdx\nxor rsi, rdi\nand r8, r9\nor r10, r11");
    assert!(matches!(insts[0], Inst::AddRegReg { dst: 0, src: 3, .. }));
    assert!(matches!(insts[1], Inst::SubRegReg { dst: 1, src: 2, .. }));
    assert!(matches!(insts[2], Inst::XorRegReg { dst: 6, src: 7, .. }));
    assert!(matches!(insts[3], Inst::AndRegReg { dst: 8, src: 9, .. }));
    assert!(matches!(insts[4], Inst::OrRegReg { dst: 10, src: 11, .. }));
}

#[test]
fn parse_alu_reg_imm() {
    let insts = parse_source("add rax, 10\nsub rbx, 20\ncmp rcx, 0\nxor rdx, 0xFF");
    assert!(matches!(insts[0], Inst::AddRegImm { dst: 0, imm: 10, .. }));
    assert!(matches!(insts[1], Inst::SubRegImm { dst: 3, imm: 20, .. }));
    assert!(matches!(insts[2], Inst::CmpRegImm { dst: 1, imm: 0, .. }));
    assert!(matches!(insts[3], Inst::XorRegImm { dst: 2, imm: 255, .. }));
}

#[test]
fn parse_shifts() {
    let insts = parse_source("shl rax, 4\nshr rbx, 8");
    assert!(matches!(insts[0], Inst::ShlRegImm { dst: 0, imm: 4, .. }));
    assert!(matches!(insts[1], Inst::ShrRegImm { dst: 3, imm: 8, .. }));
}

#[test]
fn parse_unary() {
    let insts = parse_source("not rax\nneg rbx\ninc rcx\ndec rdx\nmul rsi\ndiv rdi");
    assert!(matches!(insts[0], Inst::Not { reg: 0, .. }));
    assert!(matches!(insts[1], Inst::Neg { reg: 3, .. }));
    assert!(matches!(insts[2], Inst::Inc { reg: 1, .. }));
    assert!(matches!(insts[3], Inst::Dec { reg: 2, .. }));
    assert!(matches!(insts[4], Inst::Mul { reg: 6, .. }));
    assert!(matches!(insts[5], Inst::Div { reg: 7, .. }));
}

#[test]
fn parse_jumps() {
    let insts = parse_source("jmp foo\nje bar\njne baz\njl a\njg b\njle c\njge d\ncall e");
    assert!(matches!(&insts[0], Inst::Jmp { label, .. } if label == "foo"));
    assert!(matches!(&insts[1], Inst::Je { label, .. } if label == "bar"));
    assert!(matches!(&insts[2], Inst::Jne { label, .. } if label == "baz"));
    assert!(matches!(&insts[3], Inst::Jl { label, .. } if label == "a"));
    assert!(matches!(&insts[4], Inst::Jg { label, .. } if label == "b"));
    assert!(matches!(&insts[5], Inst::Jle { label, .. } if label == "c"));
    assert!(matches!(&insts[6], Inst::Jge { label, .. } if label == "d"));
    assert!(matches!(&insts[7], Inst::Call { label, .. } if label == "e"));
}

#[test]
fn parse_data_directives() {
    let insts = parse_source("db 0x41\ndw 0x1234\ndd 0x12345678\ndq 0x123456789ABCDEF0");
    assert!(matches!(insts[0], Inst::Db(0x41, _)));
    assert!(matches!(insts[1], Inst::Dw(0x1234, _)));
    assert!(matches!(insts[2], Inst::Dd(0x12345678, _)));
    assert!(matches!(insts[3], Inst::Dq(0x123456789ABCDEF0, _)));
}

#[test]
fn parse_db_string() {
    let insts = parse_source(r#"db "ABC""#);
    assert!(matches!(&insts[0], Inst::RawBytes(b, _) if b == &[0x41, 0x42, 0x43]));
}

#[test]
fn parse_misc() {
    let insts = parse_source("ret\nsyscall\nnop\nint 0x80\npush rax\npop rbx");
    assert!(matches!(insts[0], Inst::Ret { .. }));
    assert!(matches!(insts[1], Inst::Syscall { .. }));
    assert!(matches!(insts[2], Inst::Nop { .. }));
    assert!(matches!(insts[3], Inst::Int { vector: 0x80, .. }));
    assert!(matches!(insts[4], Inst::Push { reg: 0, .. }));
    assert!(matches!(insts[5], Inst::Pop { reg: 3, .. }));
}

#[test]
fn parse_error_unknown_instruction() {
    let tokens = tokenize("badinst rax").unwrap();
    // "badinst" becomes a Label token, which the parser rejects
    let err = parse(&tokens).unwrap_err();
    assert!(matches!(err, SeedError::UnexpectedToken { .. }));
}

#[test]
fn parse_error_missing_operand() {
    let tokens = tokenize("push").unwrap();
    let err = parse(&tokens).unwrap_err();
    assert!(matches!(err, SeedError::UnexpectedToken { .. } | SeedError::UnexpectedEof { .. }));
}

// ═══════════════════════════════════════════════════════════════════════
// Encoding — instruction sizes
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn size_mov_reg_imm() {
    assert_eq!(inst_size(&Inst::MovRegImm { dst: 0, imm: 0, line: 0 }), 10);
    assert_eq!(inst_size(&Inst::MovRegImm { dst: 15, imm: 0, line: 0 }), 10);
}

#[test]
fn size_mov_reg_reg() {
    assert_eq!(inst_size(&Inst::MovRegReg { dst: 0, src: 1, line: 0 }), 3);
}

#[test]
fn size_mem_normal() {
    // Normal registers: 3 bytes
    assert_eq!(inst_size(&Inst::MovMemReg { dst: 0, src: 1, line: 0 }), 3);
    assert_eq!(inst_size(&Inst::MovRegMem { dst: 0, src: 1, line: 0 }), 3);
}

#[test]
fn size_mem_rsp() {
    // RSP as base: needs SIB = +1
    assert_eq!(inst_size(&Inst::MovMemReg { dst: 4, src: 1, line: 0 }), 4);
    assert_eq!(inst_size(&Inst::MovRegMem { dst: 0, src: 4, line: 0 }), 4);
}

#[test]
fn size_mem_rbp() {
    // RBP as base: needs disp8 = +1
    assert_eq!(inst_size(&Inst::MovMemReg { dst: 5, src: 1, line: 0 }), 4);
    assert_eq!(inst_size(&Inst::MovRegMem { dst: 0, src: 5, line: 0 }), 4);
}

#[test]
fn size_mem_r12() {
    // R12 as base: needs SIB = +1
    assert_eq!(inst_size(&Inst::MovMemReg { dst: 12, src: 1, line: 0 }), 4);
}

#[test]
fn size_mem_r13() {
    // R13 as base: needs disp8 = +1
    assert_eq!(inst_size(&Inst::MovMemReg { dst: 13, src: 1, line: 0 }), 4);
}

#[test]
fn size_alu_imm() {
    assert_eq!(inst_size(&Inst::AddRegImm { dst: 0, imm: 1, line: 0 }), 7);
    assert_eq!(inst_size(&Inst::SubRegImm { dst: 0, imm: 1, line: 0 }), 7);
}

#[test]
fn size_shifts() {
    assert_eq!(inst_size(&Inst::ShlRegImm { dst: 0, imm: 1, line: 0 }), 4);
    assert_eq!(inst_size(&Inst::ShrRegImm { dst: 0, imm: 1, line: 0 }), 4);
}

#[test]
fn size_unary() {
    assert_eq!(inst_size(&Inst::Not { reg: 0, line: 0 }), 3);
    assert_eq!(inst_size(&Inst::Inc { reg: 0, line: 0 }), 3);
}

#[test]
fn size_jumps() {
    assert_eq!(inst_size(&Inst::Jmp { label: "x".into(), line: 0 }), 5);
    assert_eq!(inst_size(&Inst::Je { label: "x".into(), line: 0 }), 6);
    assert_eq!(inst_size(&Inst::Call { label: "x".into(), line: 0 }), 5);
}

#[test]
fn size_push_pop() {
    assert_eq!(inst_size(&Inst::Push { reg: 0, line: 0 }), 1);  // rax
    assert_eq!(inst_size(&Inst::Push { reg: 8, line: 0 }), 2);  // r8 needs REX
    assert_eq!(inst_size(&Inst::Pop { reg: 7, line: 0 }), 1);
    assert_eq!(inst_size(&Inst::Pop { reg: 15, line: 0 }), 2);
}

#[test]
fn size_data() {
    assert_eq!(inst_size(&Inst::Db(0, 0)), 1);
    assert_eq!(inst_size(&Inst::Dw(0, 0)), 2);
    assert_eq!(inst_size(&Inst::Dd(0, 0)), 4);
    assert_eq!(inst_size(&Inst::Dq(0, 0)), 8);
    assert_eq!(inst_size(&Inst::RawBytes(vec![1, 2, 3], 0)), 3);
    assert_eq!(inst_size(&Inst::LabelDef { name: "x".into(), line: 0 }), 0);
}

// ═══════════════════════════════════════════════════════════════════════
// Encoding — byte-level verification
// ═══════════════════════════════════════════════════════════════════════

fn enc(inst: &Inst) -> Vec<u8> {
    encode_inst(inst, 0, &HashMap::new()).unwrap()
}

fn enc_at(inst: &Inst, offset: usize, labels: &HashMap<String, usize>) -> Vec<u8> {
    encode_inst(inst, offset, labels).unwrap()
}

#[test]
fn encode_mov_rax_imm() {
    let bytes = enc(&Inst::MovRegImm { dst: 0, imm: 0x42, line: 0 });
    assert_eq!(bytes[0], 0x48); // REX.W
    assert_eq!(bytes[1], 0xB8); // B8 + rax
    assert_eq!(bytes[2], 0x42); // imm64 little-endian
    assert_eq!(bytes.len(), 10);
}

#[test]
fn encode_mov_r15_imm() {
    let bytes = enc(&Inst::MovRegImm { dst: 15, imm: 1, line: 0 });
    assert_eq!(bytes[0], 0x49); // REX.WB
    assert_eq!(bytes[1], 0xB8 + 7); // B8 + (r15 & 7)
    assert_eq!(bytes.len(), 10);
}

#[test]
fn encode_mov_reg_reg() {
    // mov rbx, rcx → REX.W 89 ModRM(11, rcx, rbx)
    let bytes = enc(&Inst::MovRegReg { dst: 3, src: 1, line: 0 });
    assert_eq!(bytes, vec![0x48, 0x89, modrm(0b11, 1, 3)]);
}

#[test]
fn encode_mov_mem_rbp() {
    // mov [rbp], rax → REX.W 89 ModRM(01, rax, rbp) 0x00
    let bytes = enc(&Inst::MovMemReg { dst: 5, src: 0, line: 0 });
    assert_eq!(bytes, vec![0x48, 0x89, modrm(0b01, 0, 5), 0x00]);
}

#[test]
fn encode_mov_mem_rsp() {
    // mov [rsp], rax → REX.W 89 ModRM(00, rax, 100) SIB(0x24)
    let bytes = enc(&Inst::MovMemReg { dst: 4, src: 0, line: 0 });
    assert_eq!(bytes, vec![0x48, 0x89, modrm(0b00, 0, 4), 0x24]);
}

#[test]
fn encode_add_reg_reg() {
    let bytes = enc(&Inst::AddRegReg { dst: 0, src: 3, line: 0 });
    assert_eq!(bytes, vec![0x48, 0x01, modrm(0b11, 3, 0)]);
}

#[test]
fn encode_add_reg_imm() {
    let bytes = enc(&Inst::AddRegImm { dst: 0, imm: 0x10, line: 0 });
    assert_eq!(bytes[0], 0x48); // REX.W
    assert_eq!(bytes[1], 0x81); // opcode
    assert_eq!(bytes[2], modrm(0b11, 0, 0)); // /0 for add
    assert_eq!(&bytes[3..7], &0x10i32.to_le_bytes());
}

#[test]
fn encode_xor_reg_reg() {
    let bytes = enc(&Inst::XorRegReg { dst: 0, src: 0, line: 0 });
    assert_eq!(bytes, vec![0x48, 0x31, modrm(0b11, 0, 0)]);
}

#[test]
fn encode_shl() {
    let bytes = enc(&Inst::ShlRegImm { dst: 0, imm: 4, line: 0 });
    assert_eq!(bytes, vec![0x48, 0xC1, modrm(0b11, 4, 0), 4]);
}

#[test]
fn encode_not() {
    let bytes = enc(&Inst::Not { reg: 3, line: 0 });
    assert_eq!(bytes, vec![0x48, 0xF7, modrm(0b11, 2, 3)]);
}

#[test]
fn encode_inc() {
    let bytes = enc(&Inst::Inc { reg: 1, line: 0 });
    assert_eq!(bytes, vec![0x48, 0xFF, modrm(0b11, 0, 1)]);
}

#[test]
fn encode_syscall() {
    assert_eq!(enc(&Inst::Syscall { line: 0 }), vec![0x0F, 0x05]);
}

#[test]
fn encode_ret() {
    assert_eq!(enc(&Inst::Ret { line: 0 }), vec![0xC3]);
}

#[test]
fn encode_nop() {
    assert_eq!(enc(&Inst::Nop { line: 0 }), vec![0x90]);
}

#[test]
fn encode_int() {
    assert_eq!(enc(&Inst::Int { vector: 0x80, line: 0 }), vec![0xCD, 0x80]);
}

#[test]
fn encode_push_pop() {
    assert_eq!(enc(&Inst::Push { reg: 0, line: 0 }), vec![0x50]);
    assert_eq!(enc(&Inst::Push { reg: 7, line: 0 }), vec![0x57]);
    assert_eq!(enc(&Inst::Push { reg: 8, line: 0 }), vec![0x41, 0x50]);
    assert_eq!(enc(&Inst::Pop { reg: 0, line: 0 }), vec![0x58]);
    assert_eq!(enc(&Inst::Pop { reg: 15, line: 0 }), vec![0x41, 0x5F]);
}

#[test]
fn encode_jmp_forward() {
    let mut labels = HashMap::new();
    labels.insert("target".to_string(), 10usize);
    // At offset 0, jmp to offset 10: rel = 10 - 5 = 5
    let bytes = enc_at(&Inst::Jmp { label: "target".into(), line: 0 }, 0, &labels);
    assert_eq!(bytes[0], 0xE9);
    assert_eq!(&bytes[1..5], &5i32.to_le_bytes());
}

#[test]
fn encode_jmp_backward() {
    let mut labels = HashMap::new();
    labels.insert("loop".to_string(), 0usize);
    // At offset 10, jmp to offset 0: rel = 0 - 15 = -15
    let bytes = enc_at(&Inst::Jmp { label: "loop".into(), line: 0 }, 10, &labels);
    assert_eq!(bytes[0], 0xE9);
    assert_eq!(&bytes[1..5], &(-15i32).to_le_bytes());
}

#[test]
fn encode_je() {
    let mut labels = HashMap::new();
    labels.insert("eq".to_string(), 20usize);
    // At offset 0, je to 20: rel = 20 - 6 = 14
    let bytes = enc_at(&Inst::Je { label: "eq".into(), line: 0 }, 0, &labels);
    assert_eq!(bytes[0], 0x0F);
    assert_eq!(bytes[1], 0x84);
    assert_eq!(&bytes[2..6], &14i32.to_le_bytes());
}

#[test]
fn encode_call_ret_pair() {
    let mut labels = HashMap::new();
    labels.insert("func".to_string(), 20usize);
    let call_bytes = enc_at(&Inst::Call { label: "func".into(), line: 0 }, 0, &labels);
    assert_eq!(call_bytes[0], 0xE8);
    let ret_bytes = enc(&Inst::Ret { line: 0 });
    assert_eq!(ret_bytes, vec![0xC3]);
}

#[test]
fn encode_data() {
    assert_eq!(enc(&Inst::Db(0x41, 0)), vec![0x41]);
    assert_eq!(enc(&Inst::Dw(0x1234, 0)), vec![0x34, 0x12]);
    assert_eq!(enc(&Inst::Dd(0x12345678, 0)), vec![0x78, 0x56, 0x34, 0x12]);
    assert_eq!(enc(&Inst::Dq(0x0102030405060708, 0)),
        vec![0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]);
    assert_eq!(enc(&Inst::RawBytes(vec![1, 2, 3], 0)), vec![1, 2, 3]);
}

// ═══════════════════════════════════════════════════════════════════════
// Encoding — size consistency
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn inst_size_matches_encode_size() {
    let labels: HashMap<String, usize> = [("x".to_string(), 100)].into();

    let test_insts = vec![
        Inst::MovRegImm { dst: 0, imm: 42, line: 0 },
        Inst::MovRegImm { dst: 15, imm: -1, line: 0 },
        Inst::MovRegLabel { dst: 0, label: "x".into(), line: 0 },
        Inst::MovRegReg { dst: 0, src: 15, line: 0 },
        Inst::MovMemReg { dst: 0, src: 1, line: 0 },
        Inst::MovMemReg { dst: 4, src: 1, line: 0 },  // RSP
        Inst::MovMemReg { dst: 5, src: 1, line: 0 },  // RBP
        Inst::MovMemReg { dst: 12, src: 1, line: 0 }, // R12
        Inst::MovMemReg { dst: 13, src: 1, line: 0 }, // R13
        Inst::MovRegMem { dst: 0, src: 1, line: 0 },
        Inst::MovRegMem { dst: 0, src: 4, line: 0 },
        Inst::MovRegMem { dst: 0, src: 5, line: 0 },
        Inst::AddRegReg { dst: 0, src: 1, line: 0 },
        Inst::AddRegImm { dst: 0, imm: 100, line: 0 },
        Inst::SubRegReg { dst: 0, src: 1, line: 0 },
        Inst::SubRegImm { dst: 0, imm: 100, line: 0 },
        Inst::CmpRegReg { a: 0, b: 1, line: 0 },
        Inst::CmpRegImm { dst: 0, imm: 0, line: 0 },
        Inst::XorRegReg { dst: 0, src: 0, line: 0 },
        Inst::XorRegImm { dst: 0, imm: 0xFF, line: 0 },
        Inst::AndRegReg { dst: 0, src: 1, line: 0 },
        Inst::AndRegImm { dst: 0, imm: 0xFF, line: 0 },
        Inst::OrRegReg { dst: 0, src: 1, line: 0 },
        Inst::OrRegImm { dst: 0, imm: 0xFF, line: 0 },
        Inst::TestRegReg { a: 0, b: 1, line: 0 },
        Inst::TestRegImm { dst: 0, imm: 1, line: 0 },
        Inst::ShlRegImm { dst: 0, imm: 4, line: 0 },
        Inst::ShrRegImm { dst: 0, imm: 8, line: 0 },
        Inst::Not { reg: 0, line: 0 },
        Inst::Neg { reg: 0, line: 0 },
        Inst::Inc { reg: 0, line: 0 },
        Inst::Dec { reg: 0, line: 0 },
        Inst::Mul { reg: 1, line: 0 },
        Inst::Div { reg: 1, line: 0 },
        Inst::IMul { reg: 1, line: 0 },
        Inst::IDiv { reg: 1, line: 0 },
        Inst::Jmp { label: "x".into(), line: 0 },
        Inst::Je { label: "x".into(), line: 0 },
        Inst::Jne { label: "x".into(), line: 0 },
        Inst::Jl { label: "x".into(), line: 0 },
        Inst::Jg { label: "x".into(), line: 0 },
        Inst::Jle { label: "x".into(), line: 0 },
        Inst::Jge { label: "x".into(), line: 0 },
        Inst::Call { label: "x".into(), line: 0 },
        Inst::Ret { line: 0 },
        Inst::Push { reg: 0, line: 0 },
        Inst::Push { reg: 8, line: 0 },
        Inst::Pop { reg: 0, line: 0 },
        Inst::Pop { reg: 15, line: 0 },
        Inst::Syscall { line: 0 },
        Inst::Nop { line: 0 },
        Inst::Int { vector: 3, line: 0 },
        Inst::Db(0x41, 0),
        Inst::Dw(0x1234, 0),
        Inst::Dd(0x12345678, 0),
        Inst::Dq(0, 0),
        Inst::RawBytes(vec![1, 2, 3, 4, 5], 0),
        Inst::LabelDef { name: "x".into(), line: 0 },
    ];

    for inst in &test_insts {
        let predicted = inst_size(inst);
        let actual = encode_inst(inst, 50, &labels).unwrap().len();
        assert_eq!(predicted, actual,
            "size mismatch for {:?}: predicted {}, actual {}", inst, predicted, actual);
    }
}

// ═══════════════════════════════════════════════════════════════════════
// ELF
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn elf_magic() {
    let elf = emit_elf(&[], 0);
    assert_eq!(&elf[0..4], &[0x7F, b'E', b'L', b'F']);
}

#[test]
fn elf_class_and_encoding() {
    let elf = emit_elf(&[], 0);
    assert_eq!(elf[4], 2); // 64-bit
    assert_eq!(elf[5], 1); // little-endian
}

#[test]
fn elf_header_size() {
    let elf = emit_elf(&[], 0);
    assert_eq!(elf.len(), 120); // 64 header + 56 phdr + 0 code
}

#[test]
fn elf_entry_point() {
    let elf = emit_elf(&[0x90], 0); // nop at offset 0
    let entry = u64::from_le_bytes(elf[24..32].try_into().unwrap());
    assert_eq!(entry, 0x400078); // BASE_ADDR + CODE_OFFSET
}

#[test]
fn elf_entry_point_with_offset() {
    let elf = emit_elf(&[0x90; 10], 5);
    let entry = u64::from_le_bytes(elf[24..32].try_into().unwrap());
    assert_eq!(entry, 0x400078 + 5);
}

#[test]
fn elf_code_at_end() {
    let code = vec![0x0F, 0x05, 0xC3]; // syscall; ret
    let elf = emit_elf(&code, 0);
    assert_eq!(&elf[120..], &code);
}

// ═══════════════════════════════════════════════════════════════════════
// Full pipeline — assemble()
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn assemble_hello() {
    let source = r#"
_start:
    mov rax, 1
    mov rdi, 1
    mov rsi, msg
    mov rdx, 6
    syscall
    mov rax, 60
    mov rdi, 0
    syscall
msg:
    db "hello\n"
"#;
    let elf = assemble(source).unwrap();
    // Must be valid ELF
    assert_eq!(&elf[0..4], &[0x7F, b'E', b'L', b'F']);
    // Code section must be > 0
    assert!(elf.len() > 120);
}

#[test]
fn assemble_exit_code() {
    let source = "
_start:
    mov rax, 60
    mov rdi, 42
    syscall
";
    let elf = assemble(source).unwrap();
    assert!(elf.len() > 120);
}

#[test]
fn assemble_with_loop() {
    let source = "
_start:
    mov rcx, 10
loop:
    dec rcx
    cmp rcx, 0
    jne loop
    mov rax, 60
    mov rdi, 0
    syscall
";
    let elf = assemble(source).unwrap();
    assert!(elf.len() > 120);
}

#[test]
fn assemble_with_call() {
    let source = "
_start:
    call myfunction
    mov rax, 60
    mov rdi, 0
    syscall
myfunction:
    nop
    ret
";
    let elf = assemble(source).unwrap();
    assert!(elf.len() > 120);
}

#[test]
fn assemble_all_jumps() {
    let source = "
_start:
    cmp rax, rbx
    je eq
    jne ne
    jl lt
    jg gt
    jle le
    jge ge
    jmp end
eq:
ne:
lt:
gt:
le:
ge:
end:
    mov rax, 60
    mov rdi, 0
    syscall
";
    let elf = assemble(source).unwrap();
    assert!(elf.len() > 120);
}

#[test]
fn assemble_arithmetic() {
    let source = "
_start:
    mov rax, 10
    mov rbx, 20
    add rax, rbx
    sub rax, 5
    xor rcx, rcx
    or rcx, 0xFF
    and rcx, 0x0F
    shl rcx, 4
    shr rcx, 2
    inc rax
    dec rax
    not rbx
    neg rbx
    mov rax, 60
    mov rdi, 0
    syscall
";
    let elf = assemble(source).unwrap();
    assert!(elf.len() > 120);
}

#[test]
fn assemble_extended_registers() {
    let source = "
_start:
    mov r8, 1
    mov r9, 2
    mov r10, r11
    add r12, r13
    push r14
    pop r15
    mov rax, 60
    mov rdi, 0
    syscall
";
    let elf = assemble(source).unwrap();
    assert!(elf.len() > 120);
}

// ═══════════════════════════════════════════════════════════════════════
// Error validation
// ═══════════════════════════════════════════════════════════════════════

#[test]
fn error_duplicate_label() {
    let err = assemble("foo:\nfoo:\nnop").unwrap_err();
    match err {
        SeedError::DuplicateLabel { name, line } => {
            assert_eq!(name, "foo");
            assert_eq!(line, 2);
        }
        other => panic!("expected DuplicateLabel, got {:?}", other),
    }
}

#[test]
fn error_undefined_label() {
    let err = assemble("_start:\njmp nonexistent").unwrap_err();
    match err {
        SeedError::UndefinedLabel { name, .. } => assert_eq!(name, "nonexistent"),
        other => panic!("expected UndefinedLabel, got {:?}", other),
    }
}

#[test]
fn error_undefined_label_in_mov() {
    let err = assemble("_start:\nmov rax, nonexistent").unwrap_err();
    assert!(matches!(err, SeedError::UndefinedLabel { .. }));
}
