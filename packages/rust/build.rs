// The crate ships ./tinyeval, which prepare.sh copies in, at the version in its _te_version line.
fn main() {
    println!("cargo:rerun-if-changed=tinyeval");
    let runner =
        std::fs::read_to_string("tinyeval").expect("no tinyeval in the crate: run ./prepare.sh");
    let version = env!("CARGO_PKG_VERSION");
    assert!(
        runner.contains(&format!("\n_te_version={version}\n")),
        "Cargo.toml's version {version} isn't tinyeval's _te_version: run ./prepare.sh"
    );
}
