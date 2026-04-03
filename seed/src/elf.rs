use crate::{BASE_ADDR, ELF_HEADER_SIZE, CODE_OFFSET};

/// Emit a minimal static ELF64 binary.
/// 64-byte ELF header + 56-byte program header + code.
/// No sections, no symbol table, no dynamic linking.
pub fn emit_elf(code: &[u8], entry_offset: usize) -> Vec<u8> {
    let code_vaddr = BASE_ADDR + CODE_OFFSET;
    let entry_point = code_vaddr + entry_offset as u64;
    let file_size = CODE_OFFSET as usize + code.len();
    let mut elf = Vec::with_capacity(file_size);

    // ── ELF Header (64 bytes) ──
    elf.extend_from_slice(&[0x7F, b'E', b'L', b'F']); // e_ident[0..4] magic
    elf.push(2);                                         // e_ident[4] ELFCLASS64
    elf.push(1);                                         // e_ident[5] ELFDATA2LSB
    elf.push(1);                                         // e_ident[6] EV_CURRENT
    elf.push(0);                                         // e_ident[7] ELFOSABI_NONE
    elf.extend_from_slice(&[0; 8]);                      // e_ident[8..16] padding
    elf.extend_from_slice(&2u16.to_le_bytes());          // e_type: ET_EXEC
    elf.extend_from_slice(&0x3Eu16.to_le_bytes());       // e_machine: EM_X86_64
    elf.extend_from_slice(&1u32.to_le_bytes());          // e_version: EV_CURRENT
    elf.extend_from_slice(&entry_point.to_le_bytes());   // e_entry
    elf.extend_from_slice(&ELF_HEADER_SIZE.to_le_bytes()); // e_phoff
    elf.extend_from_slice(&0u64.to_le_bytes());          // e_shoff (no sections)
    elf.extend_from_slice(&0u32.to_le_bytes());          // e_flags
    elf.extend_from_slice(&64u16.to_le_bytes());         // e_ehsize
    elf.extend_from_slice(&56u16.to_le_bytes());         // e_phentsize
    elf.extend_from_slice(&1u16.to_le_bytes());          // e_phnum
    elf.extend_from_slice(&64u16.to_le_bytes());         // e_shentsize
    elf.extend_from_slice(&0u16.to_le_bytes());          // e_shnum
    elf.extend_from_slice(&0u16.to_le_bytes());          // e_shstrndx

    debug_assert_eq!(elf.len(), 64);

    // ── Program Header (56 bytes) ──
    elf.extend_from_slice(&1u32.to_le_bytes());          // p_type: PT_LOAD
    elf.extend_from_slice(&5u32.to_le_bytes());          // p_flags: PF_R | PF_X
    elf.extend_from_slice(&0u64.to_le_bytes());          // p_offset
    elf.extend_from_slice(&BASE_ADDR.to_le_bytes());     // p_vaddr
    elf.extend_from_slice(&BASE_ADDR.to_le_bytes());     // p_paddr
    elf.extend_from_slice(&(file_size as u64).to_le_bytes()); // p_filesz
    elf.extend_from_slice(&(file_size as u64).to_le_bytes()); // p_memsz
    elf.extend_from_slice(&0x1000u64.to_le_bytes());     // p_align

    debug_assert_eq!(elf.len(), 120);

    // ── Code ──
    elf.extend_from_slice(code);

    debug_assert_eq!(elf.len(), file_size);
    elf
}
