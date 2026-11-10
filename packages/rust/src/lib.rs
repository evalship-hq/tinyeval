//! A worker for [tinyeval](https://tinyeval.com): it answers each test case's input with your code.
//!
//! ```no_run
//! fn main() -> std::io::Result<()> {
//!     tinyeval::worker(|input| Ok(format!("You said: {input}")))
//! }
//! ```
use std::error::Error;
use std::fmt;
use std::fs::File;
use std::io::{self, BufRead, Write};
use std::panic::{self, AssertUnwindSafe};

/// Return it when the AI call couldn't run, such as on a missing key, a 429 or a timeout. tinyeval then counts
/// the test case apart from the failures. Any other error becomes the reply, so the eval fails.
#[derive(Debug)]
pub struct CouldntRun(pub String);

impl fmt::Display for CouldntRun {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str(&self.0)
    }
}

impl Error for CouldntRun {}

/// Answers each input tinyeval sends with `answer`, until tinyeval closes stdin.
///
/// It first points stdout at stderr, for child processes too, and keeps the real stdout for the replies.
/// Set up your app after it starts, in a `LazyLock` or on the first call, so what it prints stays off stdout.
pub fn worker<F>(answer: F) -> io::Result<()>
where
    F: FnMut(String) -> Result<String, Box<dyn Error>>,
{
    let replies = take_stdout()?;
    serve(io::stdin().lock(), replies, answer)
}

fn serve<F>(input: impl BufRead, mut replies: impl Write, mut answer: F) -> io::Result<()>
where
    F: FnMut(String) -> Result<String, Box<dyn Error>>,
{
    for input in input.split(0) {
        let input = String::from_utf8_lossy(&input?).into_owned();
        let reply = match panic::catch_unwind(AssertUnwindSafe(|| answer(input))) {
            Ok(Ok(reply)) => reply,
            Ok(Err(e)) => match std::iter::successors(Some(&*e), |&e| e.source())
                .find_map(|e| e.downcast_ref::<CouldntRun>())
            {
                Some(CouldntRun(why)) => {
                    format!("#tinyeval couldnt_run {}\n", why.replace(['\r', '\n'], " "))
                }
                None => {
                    eprintln!("tinyeval worker: {e:?}");
                    format!("Error: {e}")
                }
            },
            // The panic hook has printed where to stderr.
            Err(panic) => {
                let why = panic
                    .downcast_ref::<&str>()
                    .copied()
                    .or(panic.downcast_ref::<String>().map(|s| s.as_str()));
                format!("panic: {}", why.unwrap_or("Box<dyn Any>"))
            }
        };
        replies.write_all(&[reply.replace('\0', "").as_bytes(), b"\0"].concat())?;
        replies.flush()?;
    }
    Ok(())
}

// A copy of stdout for the replies, then stdout pointed at stderr.
#[cfg(unix)]
fn take_stdout() -> io::Result<File> {
    use std::os::fd::AsFd;
    extern "C" {
        fn dup2(from: i32, to: i32) -> i32;
    }
    let replies = io::stdout().as_fd().try_clone_to_owned()?; // close-on-exec, so child processes don't get it
    if unsafe { dup2(2, 1) } < 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(replies.into())
}

// Windows has no fd 1 to replace, so this moves the standard output handle, which Rust's stdout and child processes
// use. C code writing to the C runtime's stdout still reaches the replies.
#[cfg(windows)]
fn take_stdout() -> io::Result<File> {
    use std::os::windows::io::{AsHandle, AsRawHandle};
    extern "system" {
        fn SetStdHandle(which: u32, handle: *mut std::ffi::c_void) -> i32;
    }
    let replies = io::stdout().as_handle().try_clone_to_owned()?;
    if unsafe { SetStdHandle(-11i32 as u32, io::stderr().as_raw_handle()) } == 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(replies.into())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{BufReader, Read};

    // Hands out its chunks one read at a time, as a pipe may.
    struct Chunks(Vec<&'static [u8]>);
    impl Read for Chunks {
        fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
            if self.0.is_empty() {
                return Ok(0);
            }
            let chunk = self.0.remove(0);
            buf[..chunk.len()].copy_from_slice(chunk);
            Ok(chunk.len())
        }
    }

    fn run(
        chunks: Vec<&'static [u8]>,
        answer: impl FnMut(String) -> Result<String, Box<dyn Error>>,
    ) -> String {
        let mut out = Vec::new();
        serve(BufReader::new(Chunks(chunks)), &mut out, answer).unwrap();
        String::from_utf8(out).unwrap()
    }

    fn echo(input: String) -> Result<String, Box<dyn Error>> {
        Ok(format!("You said: {input}"))
    }

    #[test]
    fn several_inputs_in_one_chunk() {
        assert_eq!(run(vec![b"a\0b\0"], echo), "You said: a\0You said: b\0");
    }

    #[test]
    fn an_input_split_across_reads_inside_a_character() {
        // "ï" is the two bytes C3 AF.
        assert_eq!(
            run(
                vec![b"na\xC3", b"\xAFve ", "日本語 ✓\0x\0".as_bytes()],
                echo
            ),
            "You said: naïve 日本語 ✓\0You said: x\0"
        );
    }

    #[test]
    fn nul_bytes_are_dropped_from_the_reply() {
        assert_eq!(run(vec![b"a\0"], |_| Ok("x\0y".into())), "xy\0");
    }

    #[test]
    fn couldnt_run_on_one_line() {
        let out = run(vec![b"a\0"], |_| {
            Err(CouldntRun("anthropic: 429\nrate limited".into()).into())
        });
        assert_eq!(out, "#tinyeval couldnt_run anthropic: 429 rate limited\n\0");
    }

    #[derive(Debug)]
    struct ApiError {
        status: u16,
    }
    impl fmt::Display for ApiError {
        fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
            write!(f, "{} rate_limit_error", self.status)
        }
    }
    impl Error for ApiError {}

    #[test]
    fn a_429_is_couldnt_run_once_the_app_says_so() {
        let call = |status| Err::<String, _>(ApiError { status });
        // Unmapped, it's an app error: the helper doesn't guess at HTTP clients.
        assert_eq!(
            run(vec![b"a\0"], |_| Ok(call(429)?)),
            "Error: 429 rate_limit_error\0"
        );
        let mapped = |_| match call(429) {
            Err(e) if e.status == 429 => Err(CouldntRun(format!("anthropic: {e}")).into()),
            other => Ok(other?),
        };
        assert_eq!(
            run(vec![b"a\0"], mapped),
            "#tinyeval couldnt_run anthropic: 429 rate_limit_error\n\0"
        );
    }

    #[derive(Debug)]
    struct Wrapped(CouldntRun);
    impl fmt::Display for Wrapped {
        fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
            f.write_str("support bot")
        }
    }
    impl Error for Wrapped {
        fn source(&self) -> Option<&(dyn Error + 'static)> {
            Some(&self.0)
        }
    }

    #[test]
    fn couldnt_run_behind_another_error() {
        let out = run(vec![b"a\0"], |_| {
            Err(Wrapped(CouldntRun("timed out".into())).into())
        });
        assert_eq!(out, "#tinyeval couldnt_run timed out\n\0");
    }

    #[test]
    fn an_app_error_or_panic_becomes_the_reply_and_the_worker_goes_on() {
        let out = run(vec![b"crash\0panic\0ok\0"], |input| match input.as_str() {
            "crash" => Err("boom".into()),
            "panic" => panic!("index out of bounds"),
            _ => echo(input),
        });
        assert_eq!(
            out,
            "Error: boom\0panic: index out of bounds\0You said: ok\0"
        );
    }
}
