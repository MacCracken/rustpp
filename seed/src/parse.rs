use crate::error::{Result, SeedError};
use crate::token::{reg_code, Token};

#[derive(Debug, Clone, PartialEq)]
pub enum Inst {
    // Data movement
    MovRegImm {
        dst: u8,
        imm: i64,
        line: usize,
    },
    MovRegLabel {
        dst: u8,
        label: String,
        line: usize,
    },
    MovRegReg {
        dst: u8,
        src: u8,
        line: usize,
    },
    MovMemReg {
        dst: u8,
        src: u8,
        line: usize,
    },
    MovRegMem {
        dst: u8,
        src: u8,
        line: usize,
    },
    MovMemDispReg {
        base: u8,
        disp: i32,
        src: u8,
        line: usize,
    },
    MovRegMemDisp {
        dst: u8,
        base: u8,
        disp: i32,
        line: usize,
    },
    MovzxRegMem {
        dst: u8,
        src: u8,
        line: usize,
    },
    MovzxRegMemDisp {
        dst: u8,
        base: u8,
        disp: i32,
        line: usize,
    },
    LeaRegMemDisp {
        dst: u8,
        base: u8,
        disp: i32,
        line: usize,
    },

    // Byte store: movb [reg], reg  (stores low 8 bits)
    MovbMemReg {
        dst: u8,
        src: u8,
        line: usize,
    },
    MovbMemDispReg {
        base: u8,
        disp: i32,
        src: u8,
        line: usize,
    },

    // Sign-extending byte load: movsx reg, [mem]
    MovsxRegMem {
        dst: u8,
        src: u8,
        line: usize,
    },
    MovsxRegMemDisp {
        dst: u8,
        base: u8,
        disp: i32,
        line: usize,
    },

    // Arithmetic — register, register
    AddRegReg {
        dst: u8,
        src: u8,
        line: usize,
    },
    SubRegReg {
        dst: u8,
        src: u8,
        line: usize,
    },
    CmpRegReg {
        a: u8,
        b: u8,
        line: usize,
    },
    XorRegReg {
        dst: u8,
        src: u8,
        line: usize,
    },
    AndRegReg {
        dst: u8,
        src: u8,
        line: usize,
    },
    OrRegReg {
        dst: u8,
        src: u8,
        line: usize,
    },
    TestRegReg {
        a: u8,
        b: u8,
        line: usize,
    },

    // Arithmetic — register, immediate
    AddRegImm {
        dst: u8,
        imm: i32,
        line: usize,
    },
    SubRegImm {
        dst: u8,
        imm: i32,
        line: usize,
    },
    CmpRegImm {
        dst: u8,
        imm: i32,
        line: usize,
    },
    XorRegImm {
        dst: u8,
        imm: i32,
        line: usize,
    },
    AndRegImm {
        dst: u8,
        imm: i32,
        line: usize,
    },
    OrRegImm {
        dst: u8,
        imm: i32,
        line: usize,
    },
    TestRegImm {
        dst: u8,
        imm: i32,
        line: usize,
    },

    // Shifts
    ShlRegImm {
        dst: u8,
        imm: u8,
        line: usize,
    },
    ShrRegImm {
        dst: u8,
        imm: u8,
        line: usize,
    },
    SarRegImm {
        dst: u8,
        imm: u8,
        line: usize,
    },
    // Variable shifts (shift by CL)
    ShlRegCl {
        dst: u8,
        line: usize,
    },
    ShrRegCl {
        dst: u8,
        line: usize,
    },
    SarRegCl {
        dst: u8,
        line: usize,
    },

    // Unary
    Not {
        reg: u8,
        line: usize,
    },
    Neg {
        reg: u8,
        line: usize,
    },
    Inc {
        reg: u8,
        line: usize,
    },
    Dec {
        reg: u8,
        line: usize,
    },
    Mul {
        reg: u8,
        line: usize,
    },
    Div {
        reg: u8,
        line: usize,
    },
    IMul {
        reg: u8,
        line: usize,
    },
    IDiv {
        reg: u8,
        line: usize,
    },

    // Control flow
    Jmp {
        label: String,
        line: usize,
    },
    Je {
        label: String,
        line: usize,
    },
    Jne {
        label: String,
        line: usize,
    },
    Jl {
        label: String,
        line: usize,
    },
    Jg {
        label: String,
        line: usize,
    },
    Jle {
        label: String,
        line: usize,
    },
    Jge {
        label: String,
        line: usize,
    },
    // Unsigned conditional jumps
    Ja {
        label: String,
        line: usize,
    },
    Jae {
        label: String,
        line: usize,
    },
    Jb {
        label: String,
        line: usize,
    },
    Jbe {
        label: String,
        line: usize,
    },

    // Conditional move: cmovcc dst, src (reg, reg)
    CmovCC {
        cc: u8,
        dst: u8,
        src: u8,
        line: usize,
    },

    // Set byte on condition: setcc reg (sets low byte to 0 or 1)
    SetCC {
        cc: u8,
        reg: u8,
        line: usize,
    },

    // Register exchange
    Xchg {
        a: u8,
        b: u8,
        line: usize,
    },

    Call {
        label: String,
        line: usize,
    },
    Ret {
        line: usize,
    },

    // Stack
    Push {
        reg: u8,
        line: usize,
    },
    Pop {
        reg: u8,
        line: usize,
    },

    // System
    Syscall {
        line: usize,
    },
    Cqo {
        line: usize,
    },
    Cld {
        line: usize,
    },
    RepMovsb {
        line: usize,
    },
    RepStosb {
        line: usize,
    },
    Leave {
        line: usize,
    },
    Nop {
        line: usize,
    },
    Int {
        vector: u8,
        line: usize,
    },

    // Data
    Db(u8, usize),
    Dw(u16, usize),
    Dd(u32, usize),
    Dq(u64, usize),
    RawBytes(Vec<u8>, usize),

    // Pseudo
    LabelDef {
        name: String,
        line: usize,
    },
}

fn expect_reg(tokens: &[Token], i: &mut usize) -> Result<(u8, usize)> {
    if *i >= tokens.len() {
        return Err(SeedError::UnexpectedEof {
            expected: "register".to_string(),
        });
    }
    match &tokens[*i] {
        Token::Register(name, line) => {
            let code = reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                name: name.clone(),
                line: *line,
            })?;
            *i += 1;
            Ok((code, *line))
        }
        other => Err(SeedError::UnexpectedToken {
            got: other.describe(),
            expected: "register".to_string(),
            line: other.line(),
        }),
    }
}

fn expect_label(tokens: &[Token], i: &mut usize) -> Result<(String, usize)> {
    if *i >= tokens.len() {
        return Err(SeedError::UnexpectedEof {
            expected: "label".to_string(),
        });
    }
    match &tokens[*i] {
        Token::Label(name, line) => {
            *i += 1;
            Ok((name.clone(), *line))
        }
        other => Err(SeedError::UnexpectedToken {
            got: other.describe(),
            expected: "label".to_string(),
            line: other.line(),
        }),
    }
}

fn expect_imm(tokens: &[Token], i: &mut usize) -> Result<(i64, usize)> {
    if *i >= tokens.len() {
        return Err(SeedError::UnexpectedEof {
            expected: "immediate".to_string(),
        });
    }
    match &tokens[*i] {
        Token::Immediate(val, line) => {
            *i += 1;
            Ok((*val, *line))
        }
        other => Err(SeedError::UnexpectedToken {
            got: other.describe(),
            expected: "immediate".to_string(),
            line: other.line(),
        }),
    }
}

fn peek_token(tokens: &[Token], i: usize) -> Option<&Token> {
    if i < tokens.len() {
        Some(&tokens[i])
    } else {
        None
    }
}

/// Parse a "reg, reg_or_imm_or_label" pair for two-operand instructions.
/// Returns (reg, Operand) where Operand is either a register code, immediate, or label.
enum Operand {
    Reg(u8),
    Imm(i64),
    Label(String),
    Mem(u8),
    MemDisp(u8, i32),
}

fn parse_two_operands(
    tokens: &[Token],
    i: &mut usize,
    inst_name: &str,
    line: usize,
) -> Result<(u8, Operand)> {
    if *i >= tokens.len() {
        return Err(SeedError::InvalidOperands {
            inst: inst_name.to_string(),
            line,
        });
    }

    // First operand: must be register (or mem for mov)
    let first = match &tokens[*i] {
        Token::Register(name, ln) => {
            let code = reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                name: name.clone(),
                line: *ln,
            })?;
            *i += 1;
            Operand::Reg(code)
        }
        Token::MemRegister(name, ln) => {
            let code = reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                name: name.clone(),
                line: *ln,
            })?;
            *i += 1;
            Operand::Mem(code)
        }
        Token::MemDisp(name, disp, ln) => {
            let code = reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                name: name.clone(),
                line: *ln,
            })?;
            *i += 1;
            Operand::MemDisp(code, *disp)
        }
        other => {
            return Err(SeedError::UnexpectedToken {
                got: other.describe(),
                expected: "register or memory".to_string(),
                line: other.line(),
            })
        }
    };

    if *i >= tokens.len() {
        return Err(SeedError::InvalidOperands {
            inst: inst_name.to_string(),
            line,
        });
    }

    // Second operand
    let second = match &tokens[*i] {
        Token::Register(name, ln) => {
            let code = reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                name: name.clone(),
                line: *ln,
            })?;
            *i += 1;
            Operand::Reg(code)
        }
        Token::Immediate(val, _) => {
            *i += 1;
            Operand::Imm(*val)
        }
        Token::Label(name, _) => {
            *i += 1;
            Operand::Label(name.clone())
        }
        Token::MemRegister(name, ln) => {
            let code = reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                name: name.clone(),
                line: *ln,
            })?;
            *i += 1;
            Operand::Mem(code)
        }
        Token::MemDisp(name, disp, ln) => {
            let code = reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                name: name.clone(),
                line: *ln,
            })?;
            *i += 1;
            Operand::MemDisp(code, *disp)
        }
        other => {
            return Err(SeedError::UnexpectedToken {
                got: other.describe(),
                expected: "register, immediate, or label".to_string(),
                line: other.line(),
            })
        }
    };

    // Unpack first operand as register code
    match first {
        Operand::Reg(code) => Ok((code, second)),
        Operand::Mem(code) => Ok((code, second)), // caller distinguishes via context
        Operand::MemDisp(code, _) => Ok((code, second)), // disp passed via first
        _ => Err(SeedError::InvalidOperands {
            inst: inst_name.to_string(),
            line,
        }),
    }
}

pub fn parse(tokens: &[Token]) -> Result<Vec<Inst>> {
    let mut insts = Vec::new();
    let mut i = 0;
    while i < tokens.len() {
        match &tokens[i] {
            Token::LabelDef(name, line) => {
                insts.push(Inst::LabelDef {
                    name: name.clone(),
                    line: *line,
                });
                i += 1;
            }
            Token::Newline(_) => {
                i += 1;
            }
            Token::Instruction(name, line) => {
                let line = *line;
                i += 1;
                match name.as_str() {
                    "mov" => {
                        let first = &tokens[i];
                        match first {
                            Token::Register(_, _) => {
                                let (dst, op) = parse_two_operands(tokens, &mut i, "mov", line)?;
                                match op {
                                    Operand::Imm(imm) => {
                                        insts.push(Inst::MovRegImm { dst, imm, line })
                                    }
                                    Operand::Reg(src) => {
                                        insts.push(Inst::MovRegReg { dst, src, line })
                                    }
                                    Operand::Label(l) => insts.push(Inst::MovRegLabel {
                                        dst,
                                        label: l,
                                        line,
                                    }),
                                    Operand::Mem(src) => {
                                        insts.push(Inst::MovRegMem { dst, src, line })
                                    }
                                    Operand::MemDisp(base, disp) => {
                                        insts.push(Inst::MovRegMemDisp {
                                            dst,
                                            base,
                                            disp,
                                            line,
                                        })
                                    }
                                }
                            }
                            Token::MemRegister(name, ln) => {
                                let dst =
                                    reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                                        name: name.clone(),
                                        line: *ln,
                                    })?;
                                i += 1;
                                let (src, _) = expect_reg(tokens, &mut i)?;
                                insts.push(Inst::MovMemReg { dst, src, line });
                            }
                            Token::MemDisp(name, disp, ln) => {
                                let base =
                                    reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                                        name: name.clone(),
                                        line: *ln,
                                    })?;
                                let disp = *disp;
                                i += 1;
                                let (src, _) = expect_reg(tokens, &mut i)?;
                                insts.push(Inst::MovMemDispReg {
                                    base,
                                    disp,
                                    src,
                                    line,
                                });
                            }
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "mov".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "add" => {
                        let (dst, op) = parse_two_operands(tokens, &mut i, "add", line)?;
                        match op {
                            Operand::Reg(src) => insts.push(Inst::AddRegReg { dst, src, line }),
                            Operand::Imm(imm) => insts.push(Inst::AddRegImm {
                                dst,
                                imm: imm as i32,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "add".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "sub" => {
                        let (dst, op) = parse_two_operands(tokens, &mut i, "sub", line)?;
                        match op {
                            Operand::Reg(src) => insts.push(Inst::SubRegReg { dst, src, line }),
                            Operand::Imm(imm) => insts.push(Inst::SubRegImm {
                                dst,
                                imm: imm as i32,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "sub".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "cmp" => {
                        let (a, op) = parse_two_operands(tokens, &mut i, "cmp", line)?;
                        match op {
                            Operand::Reg(b) => insts.push(Inst::CmpRegReg { a, b, line }),
                            Operand::Imm(imm) => insts.push(Inst::CmpRegImm {
                                dst: a,
                                imm: imm as i32,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "cmp".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "xor" => {
                        let (dst, op) = parse_two_operands(tokens, &mut i, "xor", line)?;
                        match op {
                            Operand::Reg(src) => insts.push(Inst::XorRegReg { dst, src, line }),
                            Operand::Imm(imm) => insts.push(Inst::XorRegImm {
                                dst,
                                imm: imm as i32,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "xor".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "and" => {
                        let (dst, op) = parse_two_operands(tokens, &mut i, "and", line)?;
                        match op {
                            Operand::Reg(src) => insts.push(Inst::AndRegReg { dst, src, line }),
                            Operand::Imm(imm) => insts.push(Inst::AndRegImm {
                                dst,
                                imm: imm as i32,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "and".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "or" => {
                        let (dst, op) = parse_two_operands(tokens, &mut i, "or", line)?;
                        match op {
                            Operand::Reg(src) => insts.push(Inst::OrRegReg { dst, src, line }),
                            Operand::Imm(imm) => insts.push(Inst::OrRegImm {
                                dst,
                                imm: imm as i32,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "or".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "test" => {
                        let (a, op) = parse_two_operands(tokens, &mut i, "test", line)?;
                        match op {
                            Operand::Reg(b) => insts.push(Inst::TestRegReg { a, b, line }),
                            Operand::Imm(imm) => insts.push(Inst::TestRegImm {
                                dst: a,
                                imm: imm as i32,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "test".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "shl" => {
                        let (dst, _) = expect_reg(tokens, &mut i)?;
                        if matches!(peek_token(tokens, i), Some(Token::Register(n, _)) if n == "rcx")
                        {
                            i += 1; // consume "rcx" (CL is implied)
                            insts.push(Inst::ShlRegCl { dst, line });
                        } else {
                            let (imm, _) = expect_imm(tokens, &mut i)?;
                            insts.push(Inst::ShlRegImm {
                                dst,
                                imm: imm as u8,
                                line,
                            });
                        }
                    }
                    "shr" => {
                        let (dst, _) = expect_reg(tokens, &mut i)?;
                        if matches!(peek_token(tokens, i), Some(Token::Register(n, _)) if n == "rcx")
                        {
                            i += 1;
                            insts.push(Inst::ShrRegCl { dst, line });
                        } else {
                            let (imm, _) = expect_imm(tokens, &mut i)?;
                            insts.push(Inst::ShrRegImm {
                                dst,
                                imm: imm as u8,
                                line,
                            });
                        }
                    }
                    "sar" => {
                        let (dst, _) = expect_reg(tokens, &mut i)?;
                        if matches!(peek_token(tokens, i), Some(Token::Register(n, _)) if n == "rcx")
                        {
                            i += 1;
                            insts.push(Inst::SarRegCl { dst, line });
                        } else {
                            let (imm, _) = expect_imm(tokens, &mut i)?;
                            insts.push(Inst::SarRegImm {
                                dst,
                                imm: imm as u8,
                                line,
                            });
                        }
                    }
                    "not" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Not { reg, line });
                    }
                    "neg" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Neg { reg, line });
                    }
                    "inc" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Inc { reg, line });
                    }
                    "dec" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Dec { reg, line });
                    }
                    "mul" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Mul { reg, line });
                    }
                    "div" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Div { reg, line });
                    }
                    "imul" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::IMul { reg, line });
                    }
                    "idiv" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::IDiv { reg, line });
                    }
                    "jmp" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jmp { label: l, line });
                    }
                    "je" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Je { label: l, line });
                    }
                    "jne" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jne { label: l, line });
                    }
                    "jl" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jl { label: l, line });
                    }
                    "jg" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jg { label: l, line });
                    }
                    "jle" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jle { label: l, line });
                    }
                    "jge" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jge { label: l, line });
                    }
                    "ja" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Ja { label: l, line });
                    }
                    "jae" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jae { label: l, line });
                    }
                    "jb" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jb { label: l, line });
                    }
                    "jbe" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Jbe { label: l, line });
                    }
                    "call" => {
                        let (l, _) = expect_label(tokens, &mut i)?;
                        insts.push(Inst::Call { label: l, line });
                    }
                    "ret" => insts.push(Inst::Ret { line }),
                    "push" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Push { reg, line });
                    }
                    "pop" => {
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Pop { reg, line });
                    }
                    // Conditional moves: cmovCC dst, src
                    "cmove" | "cmovne" | "cmovl" | "cmovg" | "cmovle" | "cmovge" | "cmova"
                    | "cmovae" | "cmovb" | "cmovbe" => {
                        let cc = match name.as_str() {
                            "cmove" => 0x04,
                            "cmovne" => 0x05,
                            "cmovl" => 0x0C,
                            "cmovg" => 0x0F,
                            "cmovle" => 0x0E,
                            "cmovge" => 0x0D,
                            "cmova" => 0x07,
                            "cmovae" => 0x03,
                            "cmovb" => 0x02,
                            "cmovbe" => 0x06,
                            _ => unreachable!(),
                        };
                        let (dst, _) = expect_reg(tokens, &mut i)?;
                        let (src, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::CmovCC { cc, dst, src, line });
                    }
                    // Set byte on condition: setCC reg
                    "sete" | "setne" | "setl" | "setg" | "setle" | "setge" | "seta" | "setae"
                    | "setb" | "setbe" => {
                        let cc = match name.as_str() {
                            "sete" => 0x04,
                            "setne" => 0x05,
                            "setl" => 0x0C,
                            "setg" => 0x0F,
                            "setle" => 0x0E,
                            "setge" => 0x0D,
                            "seta" => 0x07,
                            "setae" => 0x03,
                            "setb" => 0x02,
                            "setbe" => 0x06,
                            _ => unreachable!(),
                        };
                        let (reg, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::SetCC { cc, reg, line });
                    }
                    "xchg" => {
                        let (a, _) = expect_reg(tokens, &mut i)?;
                        let (b, _) = expect_reg(tokens, &mut i)?;
                        insts.push(Inst::Xchg { a, b, line });
                    }
                    "movzx" => {
                        let (dst, op) = parse_two_operands(tokens, &mut i, "movzx", line)?;
                        match op {
                            Operand::Mem(src) => insts.push(Inst::MovzxRegMem { dst, src, line }),
                            Operand::MemDisp(base, disp) => insts.push(Inst::MovzxRegMemDisp {
                                dst,
                                base,
                                disp,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "movzx".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "movb" => {
                        // movb [mem], reg — byte store
                        let first = &tokens[i];
                        match first {
                            Token::MemRegister(name, ln) => {
                                let dst =
                                    reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                                        name: name.clone(),
                                        line: *ln,
                                    })?;
                                i += 1;
                                let (src, _) = expect_reg(tokens, &mut i)?;
                                insts.push(Inst::MovbMemReg { dst, src, line });
                            }
                            Token::MemDisp(name, disp, ln) => {
                                let base =
                                    reg_code(name).ok_or_else(|| SeedError::UnknownRegister {
                                        name: name.clone(),
                                        line: *ln,
                                    })?;
                                let disp = *disp;
                                i += 1;
                                let (src, _) = expect_reg(tokens, &mut i)?;
                                insts.push(Inst::MovbMemDispReg {
                                    base,
                                    disp,
                                    src,
                                    line,
                                });
                            }
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "movb".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "movsx" => {
                        let (dst, op) = parse_two_operands(tokens, &mut i, "movsx", line)?;
                        match op {
                            Operand::Mem(src) => insts.push(Inst::MovsxRegMem { dst, src, line }),
                            Operand::MemDisp(base, disp) => insts.push(Inst::MovsxRegMemDisp {
                                dst,
                                base,
                                disp,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "movsx".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "lea" => {
                        let (dst, op) = parse_two_operands(tokens, &mut i, "lea", line)?;
                        match op {
                            Operand::MemDisp(base, disp) => insts.push(Inst::LeaRegMemDisp {
                                dst,
                                base,
                                disp,
                                line,
                            }),
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "lea".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "cqo" => insts.push(Inst::Cqo { line }),
                    "cld" => insts.push(Inst::Cld { line }),
                    "leave" => insts.push(Inst::Leave { line }),
                    "rep" => {
                        // rep movsb or rep stosb
                        if i >= tokens.len() {
                            return Err(SeedError::InvalidOperands {
                                inst: "rep".to_string(),
                                line,
                            });
                        }
                        match &tokens[i] {
                            Token::Instruction(sub, _) if sub == "movsb" => {
                                i += 1;
                                insts.push(Inst::RepMovsb { line });
                            }
                            Token::Label(sub, _) if sub == "movsb" => {
                                i += 1;
                                insts.push(Inst::RepMovsb { line });
                            }
                            Token::Instruction(sub, _) if sub == "stosb" => {
                                i += 1;
                                insts.push(Inst::RepStosb { line });
                            }
                            Token::Label(sub, _) if sub == "stosb" => {
                                i += 1;
                                insts.push(Inst::RepStosb { line });
                            }
                            _ => {
                                return Err(SeedError::InvalidOperands {
                                    inst: "rep".to_string(),
                                    line,
                                })
                            }
                        }
                    }
                    "syscall" => insts.push(Inst::Syscall { line }),
                    "nop" => insts.push(Inst::Nop { line }),
                    "int" => {
                        let (imm, _) = expect_imm(tokens, &mut i)?;
                        insts.push(Inst::Int {
                            vector: imm as u8,
                            line,
                        });
                    }
                    "db" => match peek_token(tokens, i) {
                        Some(Token::Immediate(v, _)) => {
                            insts.push(Inst::Db(*v as u8, line));
                            i += 1;
                        }
                        Some(Token::Bytes(b, _)) => {
                            insts.push(Inst::RawBytes(b.clone(), line));
                            i += 1;
                        }
                        _ => {
                            return Err(SeedError::InvalidOperands {
                                inst: "db".to_string(),
                                line,
                            })
                        }
                    },
                    "dw" => {
                        let (v, _) = expect_imm(tokens, &mut i)?;
                        insts.push(Inst::Dw(v as u16, line));
                    }
                    "dd" => {
                        let (v, _) = expect_imm(tokens, &mut i)?;
                        insts.push(Inst::Dd(v as u32, line));
                    }
                    "dq" => {
                        let (v, _) = expect_imm(tokens, &mut i)?;
                        insts.push(Inst::Dq(v as u64, line));
                    }
                    _ => {
                        return Err(SeedError::UnknownInstruction {
                            name: name.clone(),
                            line,
                        })
                    }
                }
            }
            other => {
                return Err(SeedError::UnexpectedToken {
                    got: other.describe(),
                    expected: "instruction or label".to_string(),
                    line: other.line(),
                });
            }
        }
        // Skip trailing newlines
        while i < tokens.len() && matches!(tokens[i], Token::Newline(_)) {
            i += 1;
        }
    }
    Ok(insts)
}
