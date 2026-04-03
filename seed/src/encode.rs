use std::collections::HashMap;
use crate::parse::Inst;
use crate::error::Result;
use crate::{BASE_ADDR, CODE_OFFSET};

/// REX prefix byte for 64-bit operations.
pub fn rex(w: bool, r: u8, b: u8) -> u8 {
    let mut val = 0x40;
    if w { val |= 0x08; }
    if r > 7 { val |= 0x04; }
    if b > 7 { val |= 0x01; }
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

pub fn inst_size(inst: &Inst) -> usize {
    match inst {
        // mov reg, imm64 — always 10 bytes (REX.W + B8+rd + imm64)
        Inst::MovRegImm { .. } | Inst::MovRegLabel { .. } => 10,

        // mov reg, reg — 3 bytes (REX.W + opcode + ModR/M)
        Inst::MovRegReg { .. } => 3,

        // mov [reg], reg or mov reg, [reg] — 3 + possible SIB/disp
        Inst::MovMemReg { dst, .. } => 3 + mem_base_extra(*dst),
        Inst::MovRegMem { src, .. } => 3 + mem_base_extra(*src),

        // ALU reg, reg — 3 bytes
        Inst::AddRegReg { .. } | Inst::SubRegReg { .. } | Inst::CmpRegReg { .. } |
        Inst::XorRegReg { .. } | Inst::AndRegReg { .. } | Inst::OrRegReg { .. } |
        Inst::TestRegReg { .. } => 3,

        // ALU reg, imm32 — REX.W + 81 + ModR/M + imm32 = 7 bytes
        // Special case: RAX short forms exist but we use the general form for simplicity
        Inst::AddRegImm { .. } | Inst::SubRegImm { .. } | Inst::CmpRegImm { .. } |
        Inst::XorRegImm { .. } | Inst::AndRegImm { .. } | Inst::OrRegImm { .. } |
        Inst::TestRegImm { .. } => 7,

        // Shift reg, imm8 — REX.W + C1 + ModR/M + imm8 = 4 bytes
        Inst::ShlRegImm { .. } | Inst::ShrRegImm { .. } => 4,

        // Unary: REX.W + F7 + ModR/M = 3 bytes
        Inst::Not { .. } | Inst::Neg { .. } | Inst::Mul { .. } | Inst::Div { .. } |
        Inst::IMul { .. } | Inst::IDiv { .. } => 3,

        // Inc/Dec: REX.W + FF + ModR/M = 3 bytes
        Inst::Inc { .. } | Inst::Dec { .. } => 3,

        // Jmp rel32 — 5 bytes
        Inst::Jmp { .. } | Inst::Call { .. } => 5,

        // Jcc rel32 — 6 bytes (0F + cc + rel32)
        Inst::Je { .. } | Inst::Jne { .. } | Inst::Jl { .. } | Inst::Jg { .. } |
        Inst::Jle { .. } | Inst::Jge { .. } => 6,

        Inst::Ret { .. } => 1,
        Inst::Push { reg, .. } | Inst::Pop { reg, .. } => if *reg > 7 { 2 } else { 1 },
        Inst::Syscall { .. } => 2,
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
    let mut out = Vec::new();
    match base & 7 {
        5 => {
            // RBP/R13: mod=01 + disp8=0 to avoid RIP-relative
            out.push(modrm(0b01, reg_field, base));
            out.push(0x00); // disp8 = 0
        }
        4 => {
            // RSP/R12: need SIB
            out.push(modrm(0b00, reg_field, 0b100));
            out.push(0x24); // SIB: scale=0, index=RSP(none), base=RSP/R12
        }
        _ => {
            out.push(modrm(0b00, reg_field, base));
        }
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

        // ALU reg, reg
        Inst::AddRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst)); out.push(0x01); out.push(modrm(0b11, *src, *dst));
        }
        Inst::SubRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst)); out.push(0x29); out.push(modrm(0b11, *src, *dst));
        }
        Inst::CmpRegReg { a, b, .. } => {
            out.push(rex(true, *b, *a)); out.push(0x39); out.push(modrm(0b11, *b, *a));
        }
        Inst::XorRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst)); out.push(0x31); out.push(modrm(0b11, *src, *dst));
        }
        Inst::AndRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst)); out.push(0x21); out.push(modrm(0b11, *src, *dst));
        }
        Inst::OrRegReg { dst, src, .. } => {
            out.push(rex(true, *src, *dst)); out.push(0x09); out.push(modrm(0b11, *src, *dst));
        }
        Inst::TestRegReg { a, b, .. } => {
            out.push(rex(true, *b, *a)); out.push(0x85); out.push(modrm(0b11, *b, *a));
        }

        // ALU reg, imm32
        Inst::AddRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 0),
        Inst::SubRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 5),
        Inst::CmpRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 7),
        Inst::XorRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 6),
        Inst::AndRegImm { dst, imm, .. } => out = encode_alu_imm(*dst, *imm, 4),
        Inst::OrRegImm { dst, imm, .. }  => out = encode_alu_imm(*dst, *imm, 1),
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

        // Unary
        Inst::Not { reg, .. }  => out = encode_unary_f7(*reg, 2),
        Inst::Neg { reg, .. }  => out = encode_unary_f7(*reg, 3),
        Inst::Mul { reg, .. }  => out = encode_unary_f7(*reg, 4),
        Inst::Div { reg, .. }  => out = encode_unary_f7(*reg, 6),
        Inst::IMul { reg, .. } => out = encode_unary_f7(*reg, 5),
        Inst::IDiv { reg, .. } => out = encode_unary_f7(*reg, 7),
        Inst::Inc { reg, .. }  => out = encode_incdec(*reg, 0),
        Inst::Dec { reg, .. }  => out = encode_incdec(*reg, 1),

        // Jumps
        Inst::Jmp { label, .. } => {
            let target = labels[label];
            let rel = target as i64 - (offset as i64 + 5);
            out.push(0xE9);
            out.extend_from_slice(&(rel as i32).to_le_bytes());
        }
        Inst::Je { label, .. }  => { encode_jcc(&mut out, 0x84, labels[label], offset); }
        Inst::Jne { label, .. } => { encode_jcc(&mut out, 0x85, labels[label], offset); }
        Inst::Jl { label, .. }  => { encode_jcc(&mut out, 0x8C, labels[label], offset); }
        Inst::Jg { label, .. }  => { encode_jcc(&mut out, 0x8F, labels[label], offset); }
        Inst::Jle { label, .. } => { encode_jcc(&mut out, 0x8E, labels[label], offset); }
        Inst::Jge { label, .. } => { encode_jcc(&mut out, 0x8D, labels[label], offset); }

        Inst::Call { label, .. } => {
            let target = labels[label];
            let rel = target as i64 - (offset as i64 + 5);
            out.push(0xE8);
            out.extend_from_slice(&(rel as i32).to_le_bytes());
        }
        Inst::Ret { .. } => out.push(0xC3),

        Inst::Push { reg, .. } => {
            if *reg > 7 { out.push(0x41); }
            out.push(0x50 + (*reg & 7));
        }
        Inst::Pop { reg, .. } => {
            if *reg > 7 { out.push(0x41); }
            out.push(0x58 + (*reg & 7));
        }

        Inst::Syscall { .. } => { out.push(0x0F); out.push(0x05); }
        Inst::Nop { .. } => out.push(0x90),
        Inst::Int { vector, .. } => { out.push(0xCD); out.push(*vector); }

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
