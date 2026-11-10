# tinyeval

Know when a prompt or model change makes your Rust app's AI replies worse. tinyeval runs your own code against test cases in a short bash file.

## Install

```sh
cargo install tinyeval     # the tinyeval command
cargo add --dev tinyeval   # the worker helper
```

## Example

`evals/support.sh` lists the test cases. Its `worker` line starts your worker:

```bash
worker cargo run -q --release --example evalworker

test_case "refund after the window" "Can I return shoes that arrived 40 days ago?"
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`examples/evalworker.rs` answers each input with your app. Here `support::Error` is the app's own error type:

```rust
use std::sync::LazyLock;
use support::{Error, Support};
use tinyeval::CouldntRun;

static SUPPORT: LazyLock<Support> = LazyLock::new(Support::new); // set up on the first input

fn main() -> std::io::Result<()> {
    tinyeval::worker(|input| match SUPPORT.answer(&input) {
        Ok(reply) => Ok(reply),
        // No key, a 401, 429 or 5xx, or a timeout: the API's fault, so tinyeval says couldn't run.
        Err(e @ (Error::NoKey | Error::Network(_) | Error::Api { status: 401 | 429 | 500.., .. })) => {
            Err(CouldntRun(e.to_string()).into())
        }
        // Anything else, like a 400 for a request your app built, is the reply, so the eval fails.
        Err(e) => Err(e.into()),
    })
}
```

Return `CouldntRun` for what isn't your app's fault, and tinyeval counts it apart from the failures. Any other error, or a panic, becomes the reply. Rust has no official Anthropic or OpenAI SDK, so the helper leaves the sorting to you. With reqwest, it's one line:

```rust
let outage = e.is_timeout() || e.is_connect() || e.status().is_some_and(|s| s == 401 || s == 429 || s.is_server_error());
```

`worker` points stdout at stderr when it starts, child processes included, and keeps the real stdout for replies. Set your app up after that, in a `LazyLock` or on the first call, so nothing it prints mixes into a reply.

## Run it

```sh
tinyeval        # every file in evals/
tinyeval -n 3   # each test case 3 times; it passes when 2 do
```

The command needs bash 3.2 or later: macOS, Linux, or Git for Windows.

## Updating

`cargo install tinyeval` installs a newer command when there is one. The helper is in your `Cargo.lock`, so Dependabot and Renovate bump it. tinyeval names a new release under its summary.

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge, and more
- [evalship-hq/rust-llm-evals](https://github.com/evalship-hq/rust-llm-evals): a Rust support bot with its evals in CI
