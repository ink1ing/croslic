use freeup_ram_rust::{cleanup_memory, get_cleanup_status};
use std::process;

fn main() {
    match cleanup_memory() {
        Ok((before, after, _freed_mb)) => {
            // 使用 BuhoCleaner 风格的状态描述
            let status = get_cleanup_status(&before, &after);
            println!("{}", status);
        }
        Err(e) => {
            eprintln!("Memory cleanup failed: {}", e);
            process::exit(1);
        }
    }
}
