//! Cyrius Seed — Stage 0 Assembler Library
//!
//! Minimal two-pass assembler. Reads a simple assembly language,
//! emits static x86_64 ELF binaries. Zero external dependencies.
//!
//! Bootstrap chain: rustc → seed (this) → stage 1 → self-hosting

pub mod elf;
pub mod encode;
pub mod error;
pub mod parse;
pub mod token;

use std::collections::HashMap;

pub use elf::emit_elf;
pub use encode::{encode_inst, inst_size};
pub use error::{Result, SeedError};
pub use parse::{parse, Inst};
pub use token::{tokenize, Token};

pub const BASE_ADDR: u64 = 0x400000;
pub const ELF_HEADER_SIZE: u64 = 64;
pub const PHDR_SIZE: u64 = 56;
pub const CODE_OFFSET: u64 = ELF_HEADER_SIZE + PHDR_SIZE; // 120 bytes

/// Assemble source code into an ELF binary.
/// Returns the ELF bytes or an error with line information.
pub fn assemble(source: &str) -> Result<Vec<u8>> {
    let tokens = tokenize(source)?;
    let insts = parse(&tokens)?;

    // Pass 1: compute label offsets, check for duplicates
    let mut labels: HashMap<String, usize> = HashMap::new();
    let mut offset = 0usize;
    for inst in &insts {
        if let Inst::LabelDef { name, line } = inst {
            if labels.contains_key(name) {
                return Err(SeedError::DuplicateLabel {
                    name: name.clone(),
                    line: *line,
                });
            }
            labels.insert(name.clone(), offset);
        }
        offset += inst_size(inst);
    }

    // Validate: all label references resolve
    for inst in &insts {
        let (label, line) = match inst {
            Inst::Jmp { label, line } => (label, *line),
            Inst::Je { label, line } => (label, *line),
            Inst::Jne { label, line } => (label, *line),
            Inst::Jl { label, line } => (label, *line),
            Inst::Jg { label, line } => (label, *line),
            Inst::Jle { label, line } => (label, *line),
            Inst::Jge { label, line } => (label, *line),
            Inst::Ja { label, line } => (label, *line),
            Inst::Jae { label, line } => (label, *line),
            Inst::Jb { label, line } => (label, *line),
            Inst::Jbe { label, line } => (label, *line),
            Inst::Call { label, line } => (label, *line),
            Inst::MovRegLabel { label, line, .. } => (label, *line),
            _ => continue,
        };
        if !labels.contains_key(label) {
            return Err(SeedError::UndefinedLabel {
                name: label.clone(),
                line,
            });
        }
    }

    // Pass 2: encode
    let mut code = Vec::new();
    let mut offset = 0usize;
    for inst in &insts {
        let bytes = encode_inst(inst, offset, &labels)?;
        offset += bytes.len();
        code.extend_from_slice(&bytes);
    }

    let entry_offset = labels.get("_start").copied().unwrap_or(0);
    Ok(emit_elf(&code, entry_offset))
}
