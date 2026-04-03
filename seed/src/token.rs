use crate::error::{SeedError, Result};

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    Instruction(String, usize),   // (name, line)
    Register(String, usize),      // (name, line)
    Immediate(i64, usize),        // (value, line)
    Label(String, usize),         // (name, line)
    LabelDef(String, usize),      // (name, line)
    MemRegister(String, usize),   // ([reg], line)
    Bytes(Vec<u8>, usize),        // (data, line)
    Newline(usize),               // (line)
}

impl Token {
    pub fn line(&self) -> usize {
        match self {
            Token::Instruction(_, l) => *l,
            Token::Register(_, l) => *l,
            Token::Immediate(_, l) => *l,
            Token::Label(_, l) => *l,
            Token::LabelDef(_, l) => *l,
            Token::MemRegister(_, l) => *l,
            Token::Bytes(_, l) => *l,
            Token::Newline(l) => *l,
        }
    }

    pub fn describe(&self) -> String {
        match self {
            Token::Instruction(n, _) => format!("instruction '{}'", n),
            Token::Register(n, _) => format!("register '{}'", n),
            Token::Immediate(v, _) => format!("immediate {}", v),
            Token::Label(n, _) => format!("label '{}'", n),
            Token::LabelDef(n, _) => format!("label definition '{}:'", n),
            Token::MemRegister(n, _) => format!("memory '[{}]'", n),
            Token::Bytes(b, _) => format!("bytes ({} bytes)", b.len()),
            Token::Newline(_) => "newline".to_string(),
        }
    }
}

pub fn reg_code(name: &str) -> Option<u8> {
    match name {
        "rax" => Some(0),  "rcx" => Some(1),  "rdx" => Some(2),  "rbx" => Some(3),
        "rsp" => Some(4),  "rbp" => Some(5),  "rsi" => Some(6),  "rdi" => Some(7),
        "r8"  => Some(8),  "r9"  => Some(9),  "r10" => Some(10), "r11" => Some(11),
        "r12" => Some(12), "r13" => Some(13), "r14" => Some(14), "r15" => Some(15),
        _ => None,
    }
}

const INSTRUCTIONS: &[&str] = &[
    "mov", "add", "sub", "cmp", "jmp", "je", "jne", "jl", "jg", "jle", "jge",
    "call", "ret", "push", "pop", "syscall", "db", "dq", "dw", "dd",
    "xor", "and", "or", "not", "neg", "inc", "dec", "nop",
    "lea", "test", "shl", "shr", "mul", "div", "imul", "idiv",
    "movzx", "int",
];

fn is_instruction(name: &str) -> bool {
    INSTRUCTIONS.contains(&name)
}

fn parse_escape_string(chars: &[char], start: usize, line: usize) -> Result<(Vec<u8>, usize)> {
    let mut bytes = Vec::new();
    let mut i = start;
    while i < chars.len() && chars[i] != '"' {
        if chars[i] == '\\' {
            i += 1;
            if i >= chars.len() {
                return Err(SeedError::UnterminatedString { line });
            }
            match chars[i] {
                'n' => bytes.push(0x0A),
                'r' => bytes.push(0x0D),
                't' => bytes.push(0x09),
                '0' => bytes.push(0x00),
                '\\' => bytes.push(b'\\'),
                '"' => bytes.push(b'"'),
                'x' => {
                    // \xNN hex escape
                    if i + 2 >= chars.len() {
                        return Err(SeedError::InvalidEscape { ch: 'x', line });
                    }
                    let hi = chars[i + 1];
                    let lo = chars[i + 2];
                    let hex: String = [hi, lo].iter().collect();
                    let val = u8::from_str_radix(&hex, 16).map_err(|_| {
                        SeedError::InvalidEscape { ch: 'x', line }
                    })?;
                    bytes.push(val);
                    i += 2;
                }
                ch => return Err(SeedError::InvalidEscape { ch, line }),
            }
        } else {
            bytes.push(chars[i] as u8);
        }
        i += 1;
    }
    if i >= chars.len() || chars[i] != '"' {
        return Err(SeedError::UnterminatedString { line });
    }
    i += 1; // skip closing quote
    Ok((bytes, i))
}

pub fn tokenize(source: &str) -> Result<Vec<Token>> {
    let mut tokens = Vec::new();
    for (line_idx, line) in source.lines().enumerate() {
        let line_num = line_idx + 1;
        let line = line.trim();

        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        // Strip inline comments (but not inside strings)
        let effective = if let Some(pos) = find_comment(line) {
            line[..pos].trim()
        } else {
            line
        };
        if effective.is_empty() {
            continue;
        }
        // Label definition
        if effective.ends_with(':') && !effective.contains(' ') && !effective.contains('"') {
            tokens.push(Token::LabelDef(effective[..effective.len() - 1].to_string(), line_num));
            tokens.push(Token::Newline(line_num));
            continue;
        }

        let chars: Vec<char> = effective.chars().collect();
        let mut ci = 0;
        while ci < chars.len() {
            if chars[ci].is_whitespace() || chars[ci] == ',' {
                ci += 1;
                continue;
            }
            // Quoted string
            if chars[ci] == '"' {
                ci += 1;
                let (bytes, new_ci) = parse_escape_string(&chars, ci, line_num)?;
                ci = new_ci;
                tokens.push(Token::Bytes(bytes, line_num));
                continue;
            }
            // Collect a word
            let start = ci;
            while ci < chars.len() && !chars[ci].is_whitespace() && chars[ci] != ',' && chars[ci] != '"' {
                ci += 1;
            }
            let word: String = chars[start..ci].iter().collect();
            tokenize_word(&word, line_num, &mut tokens)?;
        }
        tokens.push(Token::Newline(line_num));
    }
    Ok(tokens)
}

fn find_comment(line: &str) -> Option<usize> {
    let mut in_string = false;
    for (i, ch) in line.chars().enumerate() {
        if ch == '"' {
            in_string = !in_string;
        } else if ch == '#' && !in_string {
            return Some(i);
        }
    }
    None
}

fn tokenize_word(word: &str, line: usize, tokens: &mut Vec<Token>) -> Result<()> {
    // Memory operand [reg]
    if word.starts_with('[') && word.ends_with(']') {
        let inner = &word[1..word.len() - 1];
        tokens.push(Token::MemRegister(inner.to_string(), line));
        return Ok(());
    }

    // Hex literal
    if word.starts_with("0x") || word.starts_with("0X") {
        let val = i64::from_str_radix(&word[2..], 16).map_err(|_| {
            SeedError::InvalidHexLiteral { value: word.to_string(), line }
        })?;
        tokens.push(Token::Immediate(val, line));
        return Ok(());
    }

    // Decimal literal
    if word.starts_with('-') || word.as_bytes().first().map_or(false, |b| b.is_ascii_digit()) {
        if let Ok(val) = word.parse::<i64>() {
            tokens.push(Token::Immediate(val, line));
            return Ok(());
        }
    }

    // Register
    if reg_code(word).is_some() {
        tokens.push(Token::Register(word.to_string(), line));
        return Ok(());
    }

    // Instruction or label
    let lower = word.to_lowercase();
    if is_instruction(&lower) {
        tokens.push(Token::Instruction(lower, line));
    } else {
        tokens.push(Token::Label(word.to_string(), line));
    }
    Ok(())
}
