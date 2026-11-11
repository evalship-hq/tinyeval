# tinyeval packages

Each package puts tinyeval in one language's own registry. It is a wrapper: the repo's `tinyeval` file, unchanged, plus a worker helper written with the language's standard library. No third-party runtime dependencies, no second way to write evals, nothing the bash file can't do. The committed `./tinyeval` stays the main path in tinyeval's README.

| Job in release.yml | Language | Registry | Name | Folder |
|---|---|---|---|---|
| `rubygems` | Ruby | RubyGems | `tinyeval` | `packages/ruby` |
| `pypi` | Python | PyPI | `tinyeval-cli` (imported as `tinyeval`; PyPI has an unrelated tiny-eval) | `packages/python` |
| `npm` | JavaScript, TypeScript | npm | `tinyeval-cli` (with types; npm has an unrelated tiny-eval) | `packages/npm` |
| `crates` | Rust | crates.io | `tinyeval` | `packages/rust` |
| `hex` | Elixir | Hex | `tinyeval` | `packages/elixir` |
| `nuget` | C# | NuGet | `Tinyeval` (a library plus a dotnet tool) | `packages/dotnet` |
| `pub` | Dart | pub.dev | `tinyeval` | `packages/dart` |
| `go` | Go | Go modules | `github.com/evalship-hq/tinyeval/go`, tagged `go/vX.Y.Z` | `go/` |
| `packagist` | PHP | Packagist | `evalship/tinyeval` | `packages/php`, mirrored to `evalship-hq/tinyeval-php` |
| `luarocks` | Lua | LuaRocks | `tinyeval` | `packages/lua` |
| `maven` | Java, Kotlin, Scala | Maven Central | `com.evalship:tinyeval` | `packages/jvm` |
| `swift` | Swift | Swift Package Index | `tinyeval` | `packages/swift`, mirrored to `evalship-hq/tinyeval-swift` |
| `r-universe` | R | R-universe | `tinyeval` | `packages/r` |
| `homebrew` | any, C and C++ included | Homebrew tap | `evalship-hq/tap/tinyeval` (the command only) | `evalship-hq/homebrew-tap` |
| `action` | any | GitHub Actions Marketplace | `evalship-hq/tinyeval-action` | `packages/action`, mirrored to `evalship-hq/tinyeval-action` |

## The runner

1. **Ship `tinyeval` as it is.** Copy it in at build time and keep the copy out of git. Registries that build from git (Go modules, R-universe and the mirror repos) need it in git: there, a test fails when the copy differs from `./tinyeval`, or the release job writes it in.
2. **One version.** It lives in `_te_version` in `tinyeval`. The manifest reads it, or the build stamps it in, so a release changes one line. The build fails when the package's version and `_te_version` differ.
3. **A `tinyeval` command** where the ecosystem has commands: the gem's exe, npm `bin`, a PyPI console script, a dotnet tool, `mix tinyeval`, `dart run tinyeval`, `go run github.com/evalship-hq/tinyeval/go/cmd/tinyeval`, and so on. Where a command doesn't fit, the README shows the path to the bundled file. The command:
   - runs `bash <bundled tinyeval> ARGS...`, passing stdin, stdout, stderr and the exit code through. Replace the process where the language can (exec). Otherwise wait for bash, let it handle Ctrl-C, and exit with its code.
   - sets `TINYEVAL_PACKAGE_UPDATE` to the command that updates the package, such as `bundle update tinyeval` or `npm install --save-dev tinyeval-cli@latest`. It must take a new 0.x minor: `npm update` and `composer update` stay inside a `^0.11` range. With it set, `tinyeval update` prints that command and exits 2, and the new-release notices name it.
   - on Windows, uses Git for Windows' bash (`bin\bash.exe` in the folder above `git.exe`'s `cmd` folder, or `C:\Program Files\Git\bin\bash.exe`) before a `bash` on PATH, which may be WSL's. With none, it says tinyeval needs bash from Git for Windows and exits 2.
4. A repo that commits its own `./tinyeval` keeps running that copy. The runner does this itself; don't work around it.

## The worker helper

tinyeval's `worker COMMAND` starts COMMAND once per `-j` slot. It writes each input and a NUL byte to the worker's stdin and reads the reply up to a NUL byte from its stdout, one input at a time. It closes stdin when it's done. `examples/workers/` has tested loops in 14 languages, and `~/Code/<lang>-llm-evals/evals/worker.*` the error split below.

The helper is 20 to 60 lines, standard library only. It:

1. **Reads** stdin as bytes, splits on NUL, and keeps a partial input across reads. It decodes UTF-8 after joining, so a character split across reads survives. At end of input it exits 0.
2. **Calls** the user's function with each input, and writes the reply as UTF-8, with any NUL bytes dropped, then a NUL byte, and flushes.
3. **Keeps the app's output off stdout.** Before the user's code loads, it points stdout at stderr, at the file-descriptor level where the language allows (so child processes and native code are covered too), and keeps a private handle on the real stdout for replies. Do this when the helper's module loads and document "load the helper before your app". The `tinyeval` command must not load that code: it needs the real stdout.
4. **Splits errors** the way the example repos do:
   - **Couldn't run.** The user's code raises `CouldntRun("reason")`, or the language's closest equivalent: an error type in Go and Rust. Known errors from the official Anthropic and OpenAI SDKs count too: status 401, 429 and 500 or more (529 included), connection errors and timeouts. Match them by type name or status attribute, without importing the SDK, so the helper works when it's absent. The reply is `#tinyeval couldnt_run REASON` and a newline, with REASON on one line, such as `anthropic: 429 RateLimitError`.
   - **Becomes the reply, so the eval fails.** Any other error: other API errors and any exception from the app's own code. The reply is `ErrorType: message`, and the stack trace goes to stderr.
   - The worker keeps running after any error.
5. **Reads like the language.** The user's function takes the input string and returns the reply, or a promise or future of one.
   - Ruby: `Tinyeval.worker { |input| Support.new.answer(input) }`
   - Python: `worker(answer)`
   - JavaScript: `await worker(answer)`

Out of scope: recording `TINYEVAL_CALLS`, cost lines, retries, config, a second way to define test cases.

## The README for the registry page

1. **Value first:** one line on what it does for a developer in this language.
2. **Install** the way the ecosystem does it, as a dev dependency where that exists.
3. **A 10-line example:** `evals/support.sh` with its `worker` line, and the worker file with the helper, raising `CouldntRun` when the API key isn't set.
4. **Run it** with the package's command.
5. **Needs bash 3.2 or later:** macOS, Linux, Git for Windows.
6. **Updating** goes through the package manager, so Dependabot and Renovate see new versions.
7. **Links:** https://tinyeval.com, tinyeval's README for writing evals, and the example repo `evalship-hq/<lang>-llm-evals`.

Say what couldn't run means exactly: tinyeval counts it apart from the failures, and still exits 1. Never write that it doesn't fail.

Write each one for its language, in its words and tools. No keyword lists, no paragraphs copied between packages: registries remove spam. Short sentences. Don't mention evalship.

## Tests

1. **Unit tests** for the helper, in the language's usual test tool:
   - several inputs in one stdin chunk, and one input split across chunks, a multi-byte character included
   - UTF-8 input
   - the app's output kept off stdout
   - `CouldntRun`, and an SDK-shaped error with status 429
   - an app exception that becomes the reply
2. **End to end.** Build the package the way the registry gets it (`gem build`, a wheel, `npm pack`, `cargo package`...). Install it into an empty temporary project. Copy `packages/e2e.sh` to its `evals/`, and run the package's `tinyeval` command with `E2E_WORKER` set to a worker built on the helper around this fake app:
   - When it loads, it prints `app loaded` to stdout, and `app called` on each call.
   - For the input `crash`, it raises an error with the message `boom`.
   - For any other input, it returns `You said: INPUT`.

   It passes when tinyeval exits 0. It also checks that `tinyeval -v` prints the package's version, and that `tinyeval update` exits 2 naming the package's update command.
3. **One real run, locally, before you finish:**
   - Make a git worktree of `~/Code/<lang>-llm-evals` in your scratchpad, and leave the repo itself untouched.
   - In the worktree, delete the committed `tinyeval` (or the package's command runs that copy), depend on your local package, and rewrite `evals/worker.*` with the helper, keeping its error split.
   - Run `env -u ANTHROPIC_BASE_URL ANTHROPIC_API_KEY="$(grep '^ANTHROPIC_API_KEY=' ~/Code/evalship/.env | cut -d= -f2-)" <package's tinyeval command> -n 1`. Never print the key.
   - All 3 test cases must pass. Then remove the worktree.

## CI

1. **Tests:** your own `.github/workflows/package-<job>.yml`, on pushes to main and pull requests, with `paths:` for `tinyeval`, `packages/e2e.sh`, your folder and the workflow file. Unit tests and the end-to-end run on ubuntu-latest. Add windows-latest where the ecosystem is used on Windows (npm, PyPI and NuGet at least). Native worker programs work on Git Bash since 8c710ad.
2. **Release:** replace your stub job in `.github/workflows/release.yml`. Keep `needs: release`, and drop `if: false`.
   - It runs the package's tests, then publishes the tag's version.
   - Prefer trusted publishing (`permissions: id-token: write`). Otherwise read a repository secret, and name it in your report.
   - When the registry already has this version, it succeeds without publishing, so a re-run works.
   - Mirror repos are pushed with the `MIRROR_TOKEN` secret.
3. Pin each third-party action to a full commit SHA with its version in a comment, as `test.yml` does.

## Where you work

1. Your own git worktree: `git -C ~/Code/tinyeval worktree add ~/Code/tinyeval-<job> -b package-<job> main`.
2. Touch only your folder, your workflow file and your stub in `release.yml`. For a change anywhere else, such as `tinyeval` itself, ask the lead in your report.
3. Commit with `git commit -- <paths>`, never `-a`. Don't push: the lead reviews and merges.
4. Build output stays out of git, through a `.gitignore` in your folder.
5. Commit messages: one short sentence as the subject. End with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## What only Garm does

Auto mode blocks tags, registry accounts, tokens, trusted-publisher settings and signing keys. Don't try them. The mirror and tap repos exist already, public and empty: evalship-hq/tinyeval-php, tinyeval-swift, homebrew-tap, tinyeval-action and evalship-hq.r-universe.dev. Write each one as a numbered step with the exact command or URL and every field to fill in. Secrets go in with `pbpaste | gh secret set NAME -R evalship-hq/tinyeval`, never through the chat.

## Report

In under 250 words: your commits, the unit and end-to-end results, the real run's summary line, Garm's numbered steps, and anything that differs from this spec, with why.
