// Runs this test binary again as a worker, and checks that its stdout holds only the replies.
use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::{env, thread, time::Duration};

fn main() {
    if env::var_os("TINYEVAL_TEST_WORKER").is_some() {
        tinyeval::worker(|input| {
            println!("app called");
            let echo = if cfg!(windows) {
                ["cmd", "/c", "echo child output"]
            } else {
                ["sh", "-c", "echo child output"]
            };
            Command::new(echo[0]).args(&echo[1..]).status()?;
            Ok(format!("You said: {input}"))
        })
        .unwrap();
        return;
    }
    let mut child = Command::new(env::current_exe().unwrap())
        .env("TINYEVAL_TEST_WORKER", "1")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    stdin.write_all(b"na\xC3").unwrap(); // "ï" split across two writes
    stdin.flush().unwrap();
    thread::sleep(Duration::from_millis(200));
    stdin.write_all(b"\xAFve\0b\0").unwrap();
    drop(stdin);
    let mut stderr = String::new();
    child
        .stderr
        .take()
        .unwrap()
        .read_to_string(&mut stderr)
        .unwrap();
    let out = child.wait_with_output().unwrap();
    assert!(out.status.success(), "worker failed: {stderr}");
    assert_eq!(
        String::from_utf8_lossy(&out.stdout),
        "You said: naïve\0You said: b\0"
    );
    assert_eq!(stderr.matches("app called").count(), 2, "{stderr}");
    assert_eq!(stderr.matches("child output").count(), 2, "{stderr}");
    println!("stdout: ok");
}
