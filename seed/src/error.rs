use std::fmt;

pub type Result<T> = std::result::Result<T, SeedError>;

#[derive(Debug, Clone, PartialEq)]
pub enum SeedError {
    // Tokenizer errors
    InvalidHexLiteral { value: String, line: usize },
    UnterminatedString { line: usize },
    InvalidEscape { ch: char, line: usize },

    // Parser errors
    UnexpectedToken { got: String, expected: String, line: usize },
    UnexpectedEof { expected: String },
    InvalidOperands { inst: String, line: usize },
    UnknownInstruction { name: String, line: usize },
    UnknownRegister { name: String, line: usize },

    // Assembler errors
    DuplicateLabel { name: String, line: usize },
    UndefinedLabel { name: String, line: usize },
}

impl fmt::Display for SeedError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidHexLiteral { value, line } =>
                write!(f, "line {}: invalid hex literal: {}", line, value),
            Self::UnterminatedString { line } =>
                write!(f, "line {}: unterminated string literal", line),
            Self::InvalidEscape { ch, line } =>
                write!(f, "line {}: invalid escape sequence: \\{}", line, ch),
            Self::UnexpectedToken { got, expected, line } =>
                write!(f, "line {}: expected {}, got {}", line, expected, got),
            Self::UnexpectedEof { expected } =>
                write!(f, "unexpected end of input, expected {}", expected),
            Self::InvalidOperands { inst, line } =>
                write!(f, "line {}: invalid operands for '{}'", line, inst),
            Self::UnknownInstruction { name, line } =>
                write!(f, "line {}: unknown instruction: {}", line, name),
            Self::UnknownRegister { name, line } =>
                write!(f, "line {}: unknown register: {}", line, name),
            Self::DuplicateLabel { name, line } =>
                write!(f, "line {}: duplicate label: {}", line, name),
            Self::UndefinedLabel { name, line } =>
                write!(f, "line {}: undefined label: {}", line, name),
        }
    }
}

impl std::error::Error for SeedError {}
