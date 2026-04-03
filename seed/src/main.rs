use std::env;
use std::fs;
use std::io::Write;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("usage: cyrius-seed <input.cyr> <output>");
        process::exit(1);
    }
    let input_path = &args[1];
    let output_path = &args[2];

    let source = fs::read_to_string(input_path).unwrap_or_else(|e| {
        eprintln!("error: cannot read {}: {}", input_path, e);
        process::exit(1);
    });

    let elf = cyrius_seed::assemble(&source).unwrap_or_else(|e| {
        eprintln!("error: {}", e);
        process::exit(1);
    });

    let mut out = fs::File::create(output_path).unwrap_or_else(|e| {
        eprintln!("error: cannot create {}: {}", output_path, e);
        process::exit(1);
    });
    out.write_all(&elf).unwrap_or_else(|e| {
        eprintln!("error: write failed: {}", e);
        process::exit(1);
    });

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let perms = std::fs::Permissions::from_mode(0o755);
        std::fs::set_permissions(output_path, perms).ok();
    }

    let code_size = elf.len() - 120; // ELF header + phdr = 120
    eprintln!(
        "cyrius-seed: {} -> {} ({} bytes code, {} bytes total)",
        input_path,
        output_path,
        code_size,
        elf.len()
    );
}
