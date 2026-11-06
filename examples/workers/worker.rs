// tinyeval worker in Rust. Put it at src/bin/worker.rs, and in your eval file:
//   worker cargo run -q --bin worker
// Set up your app's clients in main, before the loop, so they start once per worker.
use std::io::{self, BufRead, Write};

fn reply(input: &str) -> String {
    format!("You said: {input}") // your app's AI call goes here
}

fn main() -> io::Result<()> {
    let mut stdout = io::stdout().lock();
    for input in io::stdin().lock().split(0) {
        stdout.write_all(reply(&String::from_utf8_lossy(&input?)).as_bytes())?;
        stdout.write_all(b"\0")?;
        stdout.flush()?;
    }
    Ok(())
}
