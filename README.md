# tinyeval

Evals framework for AI features that works with any language. One bash file, as few dependencies as possible.

```
$ tinyeval
support
  ✓ refund after the window 4.4s
  ✗ missing package 2.5s
      judge: It promises a new package before asking for the order number.
      reply: So sorry about that! I've sent a replacement your way...

1 of 2 evals failed (eval-results.json)
```

## Quickstart

Ask your coding agent:

```
Set up evals with https://tinyeval.com/setup.md
```

Or set it up yourself. In your repo's root:

```sh
curl -fsSL https://tinyeval.com/install.sh | sh
tinyeval
```

[install.sh](install.sh) adds `./tinyeval` (commit it), `evals/example.sh` and an `eval-results.json` line in `.gitignore`. It also puts a `tinyeval` command in `~/.local/bin` that runs the repo's `./tinyeval`, so each repo keeps its own version. Teammates and CI run `./tinyeval` with nothing to install. Then replace `ask` in the example with your AI call:

```bash
ask() { python3 bot.py "$1"; }   # your AI call: input in, reply out

test_case "refund after the window" "Can I return shoes that arrived 40 days ago?"
  contains "30 days"
  judge "Says a refund isn't possible anymore, politely"
```

tinyeval needs bash 3.2 or later, which macOS, most Linux and Git for Windows come with (on Alpine, `apk add bash`). `judge` also uses curl.

## Writing evals

Each file in `evals/` is a suite. It defines `ask` and lists test cases.

**ask** makes your AI call. It gets the input as `$1` and on stdin, and prints the reply. Use the code you already have:

```bash
ask() { ruby bin/answer.rb; }                                 # Ruby, input on stdin
ask() { bin/rails runner 'puts Bot.reply(STDIN.read)'; }      # Rails
ask() { go run ./cmd/answer "$1"; }                           # Go
ask() { cargo run -q --bin answer -- "$1"; }                  # Rust
ask() { python3 -m app.answer "$1"; }                         # Python
ask() { curl -s localhost:3000/api/chat --data-binary @-; }   # a running server
```

**test_case NAME [INPUT]** starts a test case. Long input goes in a heredoc:

```bash
test_case "missing package" <<'EOF'
My package never showed up and I'm getting really annoyed.
EOF
  matches "order (number|id)"
```

The lines under a test case grade its reply. It passes when all of them pass.

| Line | Passes when the reply |
|---|---|
| `contains TEXT` | contains TEXT, ignoring case |
| `not_contains TEXT` | doesn't contain TEXT, ignoring case |
| `matches REGEX` | matches the extended regex |
| `equals TEXT` | is exactly TEXT |
| `expect COMMAND...` | makes COMMAND exit 0 when piped into it |
| `judge CRITERION` | meets CRITERION, as a model reads it |

`expect` takes any command or bash function. What it prints on a failure becomes the reason.

```bash
expect jq -e '.items | length > 0'          # JSON with items
expect python3 evals/sql_parses.py          # your own grader
short() { [ "$(wc -w)" -lt 80 ] || echo "over 80 words"; }
expect short
```

See [examples/support.sh](examples/support.sh) for a suite whose AI call is a Ruby script.

## Judge

`judge` asks a model whether the reply meets the criterion. It uses the first key it finds:

| Environment variable | Judge model |
|---|---|
| `OPENROUTER_API_KEY` | `anthropic/claude-haiku-5.5` |
| `ANTHROPIC_API_KEY` | `claude-haiku-5-5` |
| `OPENAI_API_KEY` | set `TINYEVAL_JUDGE_MODEL` |

`TINYEVAL_JUDGE_MODEL` picks another model. Any OpenAI-compatible API works with `TINYEVAL_JUDGE_URL` and `TINYEVAL_JUDGE_KEY`, such as Ollama at `http://localhost:11434/v1`. Or set `TINYEVAL_JUDGE` to a command that reads the prompt on stdin, like `claude -p`.

## Options

| Flag | Does |
|---|---|
| `-n 3` | runs each test case 3 times; it passes when at least half pass and shows `~` when some failed |
| `-j 4` | runs 4 test cases at once; output stays in file order |
| `-t 60` | stops an AI call after 60 seconds (default: 300) |
| `-k refund` | runs only the test cases whose name contains "refund" |
| `-o file` | writes the results there instead of `eval-results.json` |

The same input can get a different reply each time, so `-n 3` is worth its cost.

## Since the last run

tinyeval writes `eval-results.json` and compares each run with the one before it:

```
Since the last run
  ✗ support › missing package fails now
```

## Updating

```sh
tinyeval update
```

This replaces `./tinyeval` with the latest release. Commit it. In a terminal, tinyeval checks for a new release once a day and names it under the summary. The check downloads the latest tinyeval from GitHub and sends nothing about your evals. It never runs in CI.

## In CI

tinyeval exits 1 when an eval fails, so any CI can run it. On GitHub Actions:

```yaml
name: Evals
on: pull_request
jobs:
  evals:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: ./tinyeval -n 3 -j 4
        env:
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
```

## Results file

`eval-results.json` holds one line per run:

```json
{"evals": [
{"suite":"support","key":"missing package","passed":false,"file":"evals/support.sh","duration_ms":2510,"input":"My package never showed up...","output":"So sorry about that!...","failure":"judge: It promises a new package..."}
]}
```

## Compare pull requests with main

A fresh CI run has no last run to compare with. [evalship](https://evalship.com) reads `eval-results.json` as is. It compares each pull request with main, tells flaky evals from real drops and comments on the pull request. Connect your repo on [evalship.com](https://evalship.com), then upload the file:

```yaml
      - run: ./tinyeval -n 3 -j 4
        continue-on-error: true   # evalship's check is the gate
        env:
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
      - uses: actions/upload-artifact@v7
        if: always()
        with:
          name: eval-results
          path: eval-results.json
```

## License

MIT
