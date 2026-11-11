// The tinyeval command: runs the bundled tinyeval with bash. It doesn't use the library, which moves stdout.
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::{exit, Command};

const RUNNER: &str = include_str!("../tinyeval");
const VERSION: &str = env!("CARGO_PKG_VERSION");

fn main() {
    let runner = write_runner().unwrap_or_else(|e| {
        eprintln!("tinyeval: couldn't write the bundled tinyeval to a file: {e}");
        exit(2)
    });
    let mut bash = Command::new(bash());
    bash.arg(&runner)
        .args(env::args_os().skip(1))
        // cargo update stays inside the helper's 0.x requirement, so the helper needs a new one.
        .env("TINYEVAL_PACKAGE_UPDATE", "cargo install tinyeval, and raise tinyeval in Cargo.toml");
    run(bash)
}

// The runner needs a real file, so its $0 works, once per version in the cache folder, or in temp when that's not writable.
fn write_runner() -> std::io::Result<PathBuf> {
    let var = |name| {
        env::var_os(name)
            .filter(|v| !v.is_empty())
            .map(PathBuf::from)
    };
    let cache = var("XDG_CACHE_HOME")
        .or_else(|| var("HOME").map(|home| home.join(".cache")))
        .or_else(|| var("LOCALAPPDATA"));
    let mut error = None;
    for dir in cache.into_iter().chain([env::temp_dir()]) {
        let path = dir.join("tinyeval").join(format!("tinyeval-{VERSION}"));
        if fs::read(&path).is_ok_and(|have| have == RUNNER.as_bytes()) {
            return Ok(path);
        }
        // Through a temporary file, so a tinyeval starting at the same time never runs half of it.
        let tmp = path.with_extension(format!("{}.tmp", std::process::id()));
        match fs::create_dir_all(path.parent().unwrap())
            .and_then(|_| fs::write(&tmp, RUNNER))
            .and_then(|_| fs::rename(&tmp, &path))
        {
            Ok(()) => return Ok(path),
            Err(e) => error = Some(e),
        }
    }
    Err(error.unwrap())
}

#[cfg(unix)]
fn bash() -> PathBuf {
    PathBuf::from("bash")
}

#[cfg(unix)]
fn run(mut bash: Command) -> ! {
    use std::os::unix::process::CommandExt;
    let e = bash.exec();
    eprintln!("tinyeval: couldn't start bash: {e}");
    exit(2)
}

// Git for Windows' bash, before a bash on PATH, which may be WSL's.
#[cfg(windows)]
fn bash() -> PathBuf {
    let path: Vec<PathBuf> = env::var_os("PATH")
        .map(|p| env::split_paths(&p).collect())
        .unwrap_or_default();
    let git = path
        .iter()
        .map(|dir| dir.join("git.exe"))
        .find(|git| git.is_file());
    let git_bash = git.and_then(|git| Some(git.parent()?.parent()?.join("bin").join("bash.exe")));
    git_bash
        .into_iter()
        .chain([PathBuf::from(r"C:\Program Files\Git\bin\bash.exe")])
        .chain(path.iter().map(|dir| dir.join("bash.exe")))
        .find(|bash| bash.is_file())
        .unwrap_or_else(|| {
            eprintln!("tinyeval: tinyeval needs bash from Git for Windows: https://git-scm.com/download/win");
            exit(2)
        })
}

// Windows can't replace this process with bash, so it waits for it, and leaves Ctrl-C to bash.
#[cfg(windows)]
fn run(mut bash: Command) -> ! {
    extern "system" fn handled(_: u32) -> i32 {
        1
    }
    extern "system" {
        fn SetConsoleCtrlHandler(handler: Option<extern "system" fn(u32) -> i32>, add: i32) -> i32;
    }
    unsafe { SetConsoleCtrlHandler(Some(handled), 1) };
    match bash.status() {
        Ok(status) => exit(status.code().unwrap_or(1)),
        Err(e) => {
            eprintln!("tinyeval: couldn't start bash: {e}");
            exit(2)
        }
    }
}
