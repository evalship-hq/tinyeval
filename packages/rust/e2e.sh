#!/usr/bin/env bash
# Packages the crate as crates.io gets it, installs its tinyeval command into a temporary root, and runs
# packages/e2e.sh in an empty project whose worker uses the crate's helper.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
./prepare.sh
version=$(sed -n 's/^_te_version=//p' tinyeval)
cargo package -q --allow-dirty # dirty when prepare.sh changed the version
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
tar -xzf "target/package/tinyeval-$version.crate" -C "$tmp"
crate=$tmp/tinyeval-$version
cargo install -q --path "$crate" --root "$tmp/root"
export PATH="$tmp/root/bin:$PATH"

cd "$tmp" && cargo new -q --vcs none app && cd app
dep=$crate && if command -v cygpath >/dev/null; then dep=$(cygpath -m "$crate"); fi # Git Bash: cargo needs C:/ paths
echo "tinyeval = { path = \"$dep\" }" >>Cargo.toml
mkdir -p src/bin evals && cp "$here/../e2e.sh" evals/
cat >src/bin/worker.rs <<'RS'
use std::sync::LazyLock;

struct App;
static APP: LazyLock<App> = LazyLock::new(|| {
    println!("app loaded");
    App
});

impl App {
    fn call(&self, input: &str) -> Result<String, Box<dyn std::error::Error>> {
        println!("app called");
        if input == "crash" {
            return Err("boom".into());
        }
        Ok(format!("You said: {input}"))
    }
}

fn main() -> std::io::Result<()> {
    tinyeval::worker(|input| APP.call(&input))
}
RS
cargo build -q --bin worker
E2E_WORKER="$PWD/target/debug/worker" tinyeval

[ "$(tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $(tinyeval -v)" >&2; exit 1; }
status=0 && said=$(tinyeval update 2>&1) || status=$?
[ "$status" = 2 ] && [[ $said == *"cargo install tinyeval"* ]] || { echo "tinyeval update exited $status: $said" >&2; exit 1; }
echo "e2e: ok"
