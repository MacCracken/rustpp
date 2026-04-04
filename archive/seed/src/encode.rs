use crate::error::Result;
use crate::parse::Inst;
use crate::{BASE_ADDR, CODE_OFFSET};
use std::collections::HashMap;

/// REX prefix byte for 64-bit operations.
pub fn rex(w: bool, r: u8, b: u8) -> u8 {
    let mut val = 0x40;
    if w {
        val |= 0x08;
    }
    if r > 7 {
        val |= 0x04;
    }
    if b > 7 {
        val |= 0x01;
    }
    val
}

/// ModR/M byte.
pub fn modrm(mode: u8, reg: u8, rm: u8) -> u8 {
    (mode << 6) | ((reg & 7) << 3) | (rm & 7)
}

/// Does this register need special addressing as a memory base?
/// RBP(5)/R13(13) with mod=00 means RIP-relative — need mod=01 + disp8=0.
/// RSP(4)/R12(12) need a SIB byte.
fn mem_base_extra(reg: u8) -> usize {
    match reg & 7 {
        5 => 1, // RBP/R13: need disp8
        4 => 1, // RSP/R12: need SIB
        _ => 0,
    }
}

/// Compute the size of a memory operand with displacement.
/// REX + opcode + ModR/M + optional SIB + disp8 or disp32
fn mem_disp_size(base: u8, disp: i32) -> usize {
    let sib = if base & 7 == 4 { 1 } else { 0 }; // RSP/R12 need SIB
    if disp == 0 && (base & 7) != 5 {
        // No displacement needed (except RBP/R13 which always need disp8)
        3 + sib + mem_base_extra(base)
    } else if (-128..=127).contains(&disp) {
        3 + sib + 1 // mod=01 + disp8
    } else {
        3 + sib + 4 // mod=10 + disp32
    }
}

pub fn inst_size(inst: &Inst) -> usize {
    match inst {
        // mov reg, imm64 — always 10 bytes (REX.W + B8+rd + imm64)
        Inst::MovRegImm { .. } | Inst::MovRegLabel { .. } => 10,

        // mov reg, reg — 3 bytes (REX.W + opcode + ModR/M)
        Inst::MovRegReg { .. } => 3,

        // mov [reg], reg or mov reg, [reg] — 3 + possible SIB/disp
        Inst::MovMemReg { dst, .. } => 3 + mem_base_extra(*dst),
        Inst::MovRegMem { src, .. } => 3 + mem_base_extra(*src),

        // mov with displacement
        Inst::MovMemDispReg { base, disp, .. } => mem_disp_size(*base, *disp),
        Inst::MovRegMemDisp { base, disp, .. } => mem_disp_size(*base, *disp),

        // movzx reg, byte [reg] — 4 bytes base (REX + 0F B6 + ModR/M) + SIB/disp
        Inst::MovzxRegMem { src, .. } => 4 + mem_base_extra(*src),
        Inst::MovzxRegMemDisp { base, disp, .. } => mem_disp_size(*base, *disp) + 1, // +1 for 0F prefix

        // lea reg, [reg + disp] — same layout as mov reg, [reg + disp]
        Inst::LeaRegMemDisp { base, disp, .. } => mem_disp_size(*base, *disp),

        // Byte store: movb [reg], reg — opcode 88 + ModR/M
        // REX needed if src>=4 (to access sil/dil/spl/bpl) or any extended reg
        Inst::MovbMemReg { dst, src, .. } => {
            let need_rex = *src >= 4 || *dst > 7;
            (if need_rex { 3 } else { 2 }) + mem_base_extra(*dst)
        }
        Inst::MovbMemDispReg {
            base, disp, src, ..
        } => {
            let need_rex = *src >= 4 || *base > 7;
            let base_size = mem_disp_size(*base, *disp);
            if need_rex {
                base_size
            } else {
                base_size - 1
            }
        }

        // Sign-extend byte load: movsx reg, byte [mem] — REX.W + 0F BE + ModR/M
        Inst::MovsxRegMem { src, .. } => 4 + mem_base_extra(*src),
        Inst::MovsxRegMemDisp { base, disp, .. } => mem_disp_size(*base, *disp) + 1, // +1 for 0F prefix

        // ALU reg, reg — 3 bytes
        Inst::AddRegReg { .. }
        | Inst::SubRegReg { .. }
        | Inst::CmpRegReg { .. }
        | Inst::XorRegReg { .. }
        | Inst::AndRegReg { .. }
        | Inst::OrRegReg { .. }
        | Inst::TestRegReg { .. } => 3,

        // ALU reg, imm32 — REX.W + 81 + ModR/M + imm32 = 7 bytes
        // Special case: RAX short forms exist but we use the general form for simplicity
        Inst::AddRegImm { .. }
        | Inst::SubRegImm { .. }
        | Inst::CmpRegImm { .. }
        | Inst::XorRegImm { .. }
        | Inst::AndRegImm { .. }
        | Inst::OrRegImm { .. }
        | Inst::TestRegImm { .. } => 7,

        // Shift reg, imm8 — REX.W + C1 + ModR/M + imm8 = 4 bytes
        Inst::ShlRegImm { .. } | Inst::ShrRegImm { .. } | Inst::SarRegImm { .. } => 4,
        // Shift reg, cl — REX.W + D3 + ModR/M = 3 bytes
        Inst::ShlRegCl { .. } | Inst::ShrRegCl { .. } | Inst::SarRegCl { .. } => 3,

        // Unary: REX.W + F7 + ModR/M = 3 bytes
        Inst::Not { .. }
        | Inst::Neg { .. }
        | Inst::Mul { .. }
        | Inst::Div { .. }
        | Inst::IMul { .. }
        | Inst::IDiv { .. } => 3,

        // Inc/Dec: REX.W + FF + ModR/M = 3 bytes
        Inst::Inc { .. } | Inst::Dec { .. } => 3,

        // Conditional move: REX.W + 0F + cc + ModR/M = 4 bytes
        Inst::CmovCC { .. } => 4,
        // Set byte: (optional REX) + 0F + cc + ModR/M = 3 or 4 bytes
        Inst::SetCC { reg, .. } => {
            if *reg >= 4 {
                4
            } else {
                3
            }
        }
        // Register exchange: REX.W + 87 + ModR/M = 3 bytes
        Inst::Xchg { .. } => 3,

        // Jmp rel32 — 5 bytes
        Inst::Jmp { .. } | Inst::Call { .. } => 5,

        // Jcc rel32 — 6 bytes (0F + cc + rel32)
        Inst::Je { .. }
        | Inst::Jne { .. }
        | Inst::Jl { .. }
        | Inst::Jg { .. }
        | Inst::Jle { .. }
        | Inst::Jge { .. }
        | Inst::Ja { .. }
        | Inst::Jae { .. }
        | Inst::Jb { .. }
        | Inst::Jbe { .. } => 6,

        Inst::Ret { .. } => 1,
        Inst::Push { reg, .. } | Inst::Pop { reg, .. } => {
            if *reg > 7 {
                2
            } else {
                1
            }
        }
        Inst::Syscall { .. } => 2,
        Inst::Cqo { .. } => 2,      // REX.W + 0x99
        Inst::Cld { .. } => 1,      // FC
        Inst::RepMovsb { .. } => 2, // F3 A4
        Inst::RepStosb { .. } => 2, // F3 AA
        Inst::Leave { .. } => 1,    // C9
        Inst::Nop { .. } => 1,
        Inst::Int { .. } => 2, // CD + imm8

        Inst::Db(..) => 1,
        Inst::Dw(..) => 2,
        Inst::Dd(..) => 4,
        Inst::Dq(..) => 8,
        Inst::RawBytes(bytes, _) => bytes.len(),
        Inst::LabelDef { .. } => 0,
    }
}

/// Encode memory operand ModR/M (and SIB if needed) for [base_reg].
/// Returns the bytes to append after the opcode.
fn encode_mem_modrm(reg_field: u8, base: u8) -> Vec<u8> {
    encode_mem_modrm_disp(reg_field, base, 0)
}

/// Encode memory operand ModR/M with displacement.
/// Handles all special cases: RBP/R13 (needs explicit disp), RSP/R12 (needs SIB).
fn encode_mem_modrm_disp(reg_field: u8, base: u8, disp: i32) -> Vec<u8> {
    let mut out = Vec::new();
    let base_low = base & 7;
    let needs_sib = base_low == 4; // RSP/R12

    if disp == 0 && base_low != 5 {
        // mod=00, no displacement (RBP/R13 always need disp8)
        if needs_sib {
            out.push(modrm(0b00, reg_field, 0b100));
            out.push(0x24);
        } else {
            out.push(modrm(0b00, reg_field, base));
        }
    } else if (-128..=127).contains(&disp) {
        // mod=01, disp8
        if needs_sib {
            out.push(modrm(0b01, reg_field, 0b100));
            out.push(0x24);
        } else {
            out.push(modrm(0b01, reg_field, base));
        }
        out.push(disp as i8 as u8);
    } else {
        // mod=10, disp32
        if needs_sib {
            out.push(modrm(0b10, reg_field, 0b100));
            out.push(0x24);
        } else {
            out.push(modrm(0b10, reg_field, base));
        }
        out.extend_from_slice(&disp.to_le_bytes());
    }
    out
}

/// Encode ALU reg, imm32 with the given /r extension.
fn encode_alu_imm(dst: u8, imm: i32, ext: u8) -> Vec<u8> {
    let mut out = vec![rex(true, 0, dst), 0x81, modrm(0b11, ext, dst)];
    out.extend_from_slice(&imm.to_le_bytes());
    out
}

/// Encode a unary instruction (F7 /ext).
fn encode_unary_f7(reg: u8, ext: u8) -> Vec<u8> {
    vec![rex(true, 0, reg), 0xF7, modrm(0b11, ext, reg)]
}

/// Encode inc/dec (FF /ext).
fn encode_incdec(reg: u8, ext: u8) -> Vec<u8> {
    vec![rex(true, 0, reg), 0xFF, modrm(0b11, ext, reg)]
}

pub fn encode_inst(inst: &Inst, offset: usize, labels: &HashMap<String, usize>) -> Result<Vec<u8>> {
    let mut out = Vec::new();
    match inst {
        Inst::MovRegImm { dst, imm, .. } => {
            out.push(rex(true, 0, *dst));
            out.push(0xB8 + (*dst & 7));
            out.extend_from_slice(&(*imm as u64).to_le_bytes());
        }
        Inst::MovRegLabel { dst, label, .. } => {
            let target = labels[label];
            let addr = BASE_ADDR + CODE_OFFSET + target as u64;
            out.push(rex(true, 0, *dst));
            out.push(0xB8 + (*dst & 7));
            out.extend_from_slice(&addr.to_le_bytes());
        }
        Inst::MovRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst));
            out.push(0x89);
            out.push(modrm(0b11, *src, *dst));
        }
        Inst::MovMemReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst));
            out.push(0x89);
            out.extend(encode_mem_modrm(*src, *dst));
        }
        Inst::MovRegMem { dst, src, .. } => {
            out.push(rex(true, *dst, *src));
            out.push(0x8B);
            out.extend(encode_mem_modrm(*dst, *src));
        }
        Inst::MovMemDispReg {
            base, disp, src, ..
        } => {
            out.push(rex(true, *src, *base));
            out.push(0x89);
            out.extend(encode_mem_modrm_disp(*src, *base, *disp));
        }
        Inst::MovRegMemDisp {
            dst, base, disp, ..
        } => {
            out.push(rex(true, *dst, *base));
            out.push(0x8B);
            out.extend(encode_mem_modrm_disp(*dst, *base, *disp));
        }
        Inst::MovzxRegMem { dst, src, .. } => {
            // movzx r64, byte [reg] = REX.W + 0F B6 + ModR/M
            out.push(rex(true, *dst, *src));
            out.push(0x0F);
            out.push(0xB6);
            out.extend(encode_mem_modrm(*dst, *src));
        }
        Inst::MovzxRegMemDisp {
            dst, base, disp, ..
        } => {
            out.push(rex(true, *dst, *base));
            out.push(0x0F);
            out.push(0xB6);
            out.extend(encode_mem_modrm_disp(*dst, *base, *disp));
        }
        Inst::LeaRegMemDisp {
            dst, base, disp, ..
        } => {
            out.push(rex(true, *dst, *base));
            out.push(0x8D);
            out.extend(encode_mem_modrm_disp(*dst, *base, *disp));
        }
        // Byte store: movb [reg], reg — opcode 0x88
        // REX (without W) needed for extended regs or to access sil/dil/spl/bpl
        Inst::MovbMemReg { dst, src, .. } => {
            if *src >= 4 || *dst > 7 {
                out.push(rex(false, *src, *dst));
            }
            out.push(0x88);
            out.extend(encode_mem_modrm(*src, *dst));
        }
        Inst::MovbMemDispReg {
            base, disp, src, ..
        } => {
            if *src >= 4 || *base > 7 {
                out.push(rex(false, *src, *base));
            }
            out.push(0x88);
            out.extend(encode_mem_modrm_disp(*src, *base, *disp));
        }
        // Sign-extend byte load: movsx reg, byte [mem] — REX.W + 0F BE
        Inst::MovsxRegMem { dst, src, .. } => {
            out.push(rex(true, *dst, *src));
            out.push(0x0F);
            out.push(0xBE);
            out.extend(encode_mem_modrm(*dst, *src));
        }
        Inst::MovsxRegMemDisp {
            dst, base, disp, ..
        } => {
            out.push(rex(true, *dst, *base));
            out.push(0x0F);
            out.push(0xBE);
            out.extend(encode_mem_modrm_disp(*dst, *base, *disp));
        }

        // ALU reg, reg
        Inst::AddRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst));
            out.push(0x01);
            out.push(modrm(0b11, *src, *dst));
        }
        Inst::SubRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst));
            out.push(0x29);
            out.push(modrm(0b11, *src, *dst));
        }
        Inst::CmpRegReg { a, b, .. } => {
            out.push(rex(true, *b, *a));
            out.push(0x39);
            out.push(modrm(0b11, *b, *a));
        }
        Inst::XorRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst));
            out.push(0x31);
            out.push(modrm(0b11, *src, *dst));
        }
        Inst::AndRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst));
            out.push(0x21);
            out.push(modrm(0b11, *src, *dst));
        }
        Inst::OrRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst));
            out.push(0x09);
            out.push(modrm(0b11, *src, *dst));
        }
        Inst::TestRegReg { a, b, .. } => {
            out.push(rex(true, *b, *a));
            out.push(0x85);
            out.push(modrm(0b11, *b, *a));
        }

        // ALU reg, imm32
        Inst::AddRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 0),
        Inst::SubRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 5),
        Inst::CmpRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 7),
        Inst::XorRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 6),
        Inst::AndRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 4),
        Inst::OrRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 1),
        Inst::TestRegImm { dst, imm, .. } => {
            // F7 /0 + imm32
            out.push(rex(true, 0, *dst));
            out.push(0xF7);
            out.push(modrm(0b11, 0, *dst));
            out.extend_from_slice(&imm.to_le_bytes());
        }

        // Shifts
        Inst::ShlRegImm { dst, imm, .. } => {
            out.push(rex(true, 0, *dst));
            out.push(0xC1);
            out.push(modrm(0b11, 4, *dst));
            out.push(*imm);
        }
        Inst::ShrRegImm { dst, imm, .. } => {
            out.push(rex(true, 0, *dst));
            out.push(0xC1);
            out.push(modrm(0b11, 5, *dst));
            out.push(*imm);
        }
        Inst::SarRegImm { dst, imm, .. } => {
            out.push(rex(true, 0, *dst));
            out.push(0xC1);
            out.push(modrm(0b11, 7, *dst));
            out.push(*imm);
        }
        // Variable shifts (shift by CL)
        Inst::ShlRegCl { dst, .. } => {
            out.push(rex(true, 0, *dst));
            out.push(0xD3);
            out.push(modrm(0b11, 4, *dst));
        }
        Inst::ShrRegCl { dst, .. } => {
            out.push(rex(true, 0, *dst));
            out.push(0xD3);
            out.push(modrm(0b11, 5, *dst));
        }
        Inst::SarRegCl { dst, .. } => {
            out.push(rex(true, 0, *dst));
            out.push(0xD3);
            out.push(modrm(0b11, 7, *dst));
        }

        // Unary
        Inst::Not { reg, .. } => out = encode_unary_f7(*reg, 2),
        Inst::Neg { reg, .. } => out = encode_unary_f7(*reg, 3),
        Inst::Mul { reg, .. } => out = encode_unary_f7(*reg, 4),
        Inst::Div { reg, .. } => out = encode_unary_f7(*reg, 6),
        Inst::IMul { reg, .. } => out = encode_unary_f7(*reg, 5),
        Inst::IDiv { reg, .. } => out = encode_unary_f7(*reg, 7),
        Inst::Inc { reg, .. } => out = encode_incdec(*reg, 0),
        Inst::Dec { reg, .. } => out = encode_incdec(*reg, 1),

        // Conditional move: REX.W + 0F + (40+cc) + ModR/M(11, dst, src)
        Inst::CmovCC { cc, dst, src, .. } => {
            out.push(rex(true, *dst, *src));
            out.push(0x0F);
            out.push(0x40 | cc);
            out.push(modrm(0b11, *dst, *src));
        }
        // Set byte on condition: (REX if reg>=4) + 0F + (90+cc) + ModR/M(11, 0, reg)
        Inst::SetCC { cc, reg, .. } => {
            if *reg >= 4 {
                out.push(rex(false, 0, *reg));
            }
            out.push(0x0F);
            out.push(0x90 | cc);
            out.push(modrm(0b11, 0, *reg));
        }
        // Register exchange: REX.W + 87 + ModR/M(11, a, b)
        Inst::Xchg { a, b, .. } => {
            out.push(rex(true, *a, *b));
            out.push(0x87);
            out.push(modrm(0b11, *a, *b));
        }

        // Jumps
        Inst::Jmp { label, .. } => {
            let target = labels[label];
            let rel = target as i64 - (offset as i64 + 5);
            out.push(0xE9);
            out.extend_from_slice(&(rel as i32).to_le_bytes());
        }
        Inst::Je { label, .. } => {
            encode_jcc(&mut out, 0x84, labels[label], offset);
        }
        Inst::Jne { label, .. } => {
            encode_jcc(&mut out, 0x85, labels[label], offset);
        }
        Inst::Jl { label, .. } => {
            encode_jcc(&mut out, 0x8C, labels[label], offset);
        }
        Inst::Jg { label, .. } => {
            encode_jcc(&mut out, 0x8F, labels[label], offset);
        }
        Inst::Jle { label, .. } => {
            encode_jcc(&mut out, 0x8E, labels[label], offset);
        }
        Inst::Jge { label, .. } => {
            encode_jcc(&mut out, 0x8D, labels[label], offset);
        }
        // Unsigned conditional jumps
        Inst::Ja { label, .. } => {
            encode_jcc(&mut out, 0x87, labels[label], offset);
        }
        Inst::Jae { label, .. } => {
            encode_jcc(&mut out, 0x83, labels[label], offset);
        }
        Inst::Jb { label, .. } => {
            encode_jcc(&mut out, 0x82, labels[label], offset);
        }
        Inst::Jbe { label, .. } => {
            encode_jcc(&mut out, 0x86, labels[label], offset);
        }

        Inst::Call { label, .. } => {
            let target = labels[label];
            let rel = target as i64 - (offset as i64 + 5);
            out.push(0xE8);
            out.extend_from_slice(&(rel as i32).to_le_bytes());
        }
        Inst::Ret { .. } => out.push(0xC3),

        Inst::Push { reg, .. } => {
            if *reg > 7 {
                out.push(0x41);
            }
            out.push(0x50 + (*reg & 7));
        }
        Inst::Pop { reg, .. } => {
            if *reg > 7 {
                out.push(0x41);
            }
            out.push(0x58 + (*reg & 7));
        }

        Inst::Syscall { .. } => {
            out.push(0x0F);
            out.push(0x05);
        }
        Inst::Cqo { .. } => {
            out.push(0x48); // REX.W
            out.push(0x99);
        }
        Inst::Cld { .. } => out.push(0xFC),
        Inst::RepMovsb { .. } => {
            out.push(0xF3);
            out.push(0xA4);
        }
        Inst::RepStosb { .. } => {
            out.push(0xF3);
            out.push(0xAA);
        }
        Inst::Leave { .. } => out.push(0xC9),
        Inst::Nop { .. } => out.push(0x90),
        Inst::Int { vector, .. } => {
            out.push(0xCD);
            out.push(*vector);
        }

        Inst::Db(b, _) => out.push(*b),
        Inst::Dw(w, _) => out.extend_from_slice(&w.to_le_bytes()),
        Inst::Dd(d, _) => out.extend_from_slice(&d.to_le_bytes()),
        Inst::Dq(q, _) => out.extend_from_slice(&q.to_le_bytes()),
        Inst::RawBytes(bytes, _) => out.extend_from_slice(bytes),
        Inst::LabelDef { .. } => {}
    }
    Ok(out)
}

fn encode_jcc(out: &mut Vec<u8>, cc: u8, target: usize, offset: usize) {
    let rel = target as i64 - (offset as i64 + 6);
    out.push(0x0F);
    out.push(cc);
    out.extend_from_slice(&(rel as i32).to_le_bytes());
}
