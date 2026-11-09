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

Or start from a template repo with a support bot, its test cases and a CI workflow: [Python](https://github.com/evalship-hq/python-llm-evals), [TypeScript](https://github.com/evalship-hq/typescript-llm-evals), [JavaScript](https://github.com/evalship-hq/javascript-llm-evals), [Go](https://github.com/evalship-hq/go-llm-evals), [Java](https://github.com/evalship-hq/java-llm-evals), [C#](https://github.com/evalship-hq/csharp-llm-evals), [Ruby](https://github.com/evalship-hq/ruby-llm-evals), [PHP](https://github.com/evalship-hq/php-llm-evals), [Rust](https://github.com/evalship-hq/rust-llm-evals), [Kotlin](https://github.com/evalship-hq/kotlin-llm-evals), [Swift](https://github.com/evalship-hq/swift-llm-evals), [Dart](https://github.com/evalship-hq/dart-llm-evals), [Elixir](https://github.com/evalship-hq/elixir-llm-evals), [C++](https://github.com/evalship-hq/cpp-llm-evals), [Scala](https://github.com/evalship-hq/scala-llm-evals), [Lua](https://github.com/evalship-hq/lua-llm-evals) or [R](https://github.com/evalship-hq/r-llm-evals).

## Check every prompt change

With the tinyeval skill, your coding agent tests a change to a prompt, a model or an AI call before it finishes. It runs the change's test cases before and after, and keeps the inputs it would have tried by hand as test cases.

In Claude Code:

```
/plugin install tinyeval --marketplace evalship-hq/tinyeval
```

In Codex, Cursor, Gemini CLI and other agents that read skills:

```sh
npx skills add evalship-hq/tinyeval
```

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

**worker COMMAND** keeps your AI call running instead, so a slow-starting app, like a Rails app, starts once per `-j` rather than for every call. It reads each input up to a NUL byte on stdin, and prints the reply and a NUL byte:

```bash
worker bin/rails runner evals/worker.rb
```

```ruby
# evals/worker.rb
$stdout.sync = true
while (input = $stdin.gets("\0"))
  print Bot.reply(input.chomp("\0")), "\0"
end
```

Tested workers for Python, JavaScript, Go, Rust, PHP, Java, Kotlin, C#, Elixir, Swift, Dart, Perl and Lua are in [examples/workers](examples/workers/).

A worker that stops or takes longer than `-t` starts again for the next test case. Test cases go to the workers in turn: with `-j 3`, the 1st, 4th and 7th go to the first one, so test cases that alternate between kinds give each worker the same kind.

**test_case NAME [INPUT]** starts a test case. Each in a file needs its own NAME, since the results are keyed by it. Long input goes in a heredoc:

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
| `json FILTER` | is JSON, and jq's FILTER is true for it |
| `problems FILTER` | is JSON, and jq's FILTER gives an empty list |
| `expect COMMAND...` | makes COMMAND exit 0 when piped into it |
| `judge CRITERION` | meets CRITERION, as a model reads it |

`json '.category == "transfer"'` checks structured output and tool calls. It needs jq, which macOS and GitHub's runners come with. `expect` takes any command or bash function. What it prints on a failure becomes the reason.

```bash
expect python3 evals/sql_parses.py          # your own grader
short() { [ "$(wc -w)" -lt 80 ] || echo "over 80 words"; }
expect short
```

Checks written in your app's language can run in the worker, once per reply. The worker returns them with the reply, and `problems` fails with each one:

```bash
worker npx tsx evals/worker.ts   # replies {"tags": [...], "problems": ["tag 3 is generic"]}

test_case "three headphones" '{"call": "tags", "category": "Headphones"}'
  target src/services/tags.ts#generateProductTags
  problems .problems
```

`target` names the code a test case covers. It grades nothing, and the results file keeps it.

**check NAME** makes the lines after it a separate eval of the same reply, named "TEST CASE / NAME". One AI call then shows as several evals, each passing or failing on its own:

```bash
test_case "duck fesenjan" "$(cat evals/recipes/duck-fesenjan.txt)"
  json '.completed'
check servings
  json '.servings == 4'
check units
  not_contains "cups"
```

For a chat feature, give the conversation so far and grade the last reply:

```bash
ask() { ruby bin/chat.rb; }   # sends the messages on stdin to the model, prints its reply

test_case "remembers the order number" <<'EOF'
[{"role": "user", "content": "My order 4471 never arrived."},
 {"role": "assistant", "content": "Sorry to hear that. Let me look into it."},
 {"role": "user", "content": "Any news?"}]
EOF
  contains "4471"
```

An eval file is bash, so test cases can come from a file:

```bash
# evals/refunds.tsv: a name, a question and a phrase the reply needs, split by tabs
while IFS=$'\t' read -r name question want || [ -n "$name" ]; do
  test_case "$name" "$question"
    contains "$want"
done <evals/refunds.tsv
```

See [examples/support.sh](examples/support.sh) for a suite whose AI call is a Ruby script using the `anthropic` gem.

## Judge

`judge` asks a model whether the reply meets the criterion. It uses the first key it finds:

| Environment variable | Judge model |
|---|---|
| `OPENROUTER_API_KEY` | `anthropic/claude-haiku-5.5` |
| `ANTHROPIC_API_KEY` | `claude-haiku-5-5` |
| `OPENAI_API_KEY` | set `TINYEVAL_JUDGE_MODEL` |

`TINYEVAL_JUDGE_MODEL` picks another model. Any OpenAI-compatible API works with `TINYEVAL_JUDGE_URL` and `TINYEVAL_JUDGE_KEY`, such as Ollama at `http://localhost:11434/v1`. Or set `TINYEVAL_JUDGE` to a command that reads the prompt on stdin, like `claude -p`.

Pick a judge model your feature doesn't use: a model grading its own replies is the most common [judge mistake](https://evalship.com/articles/llm-as-a-judge-mistakes) in open-source suites.

When the API answers with a rate limit or a server error, the judge waits and tries again, up to 3 times. `ask` never gets a second try, so a flaky AI feature still shows.

## Options

| Flag | Does |
|---|---|
| `-n 3` | runs each test case 3 times; it passes when at least half pass and shows `~` when some failed; runs that couldn't run don't count |
| `-j 8` | runs 8 test cases at once (default: 4); output stays in file order. `-j 1` is for an AI call that can't run alongside itself |
| `-t 60` | stops an AI call after 60 seconds (default: 300) |
| `-k refund` | runs only the test cases whose name contains "refund" |
| `-o file` | writes the results there instead of `eval-results.json` |
| `-x file` | also writes them as JUnit XML, which GitLab, Jenkins and CircleCI show with their tests |

The same input can get a different reply each time, so `-n 3` is worth its cost.

## Couldn't run

```
  ! missing package couldn't run
      ask failed (exit 1): anthropic: 529 overloaded_error
```

When the AI call fails or times out, or the judge can't answer, the run says nothing about the reply. tinyeval counts it apart from the failures and leaves it out of Since the last run. It still exits 1.

A worker has no exit code, and an app may catch its own errors. To say a run couldn't run, start the reply with a line `#tinyeval couldnt_run REASON`. A line `#tinyeval cost_usd DOLLARS` records what the call cost. tinyeval reads these lines and grades the rest of the reply:

```ruby
rescue RateLimited => e
  print "#tinyeval couldnt_run #{e.message}\n", "\0"
```

## AI calls

```
  ✗ refund window 1.8s
      judge: It promises a refund after 90 days.
      reply: Sure, we can refund that!
      calls: classify-ticket (claude-haiku-5-5) → answer (claude-opus-5-5)
```

A reply can go wrong in any AI call your app makes on the way, not only the last one. Record each call to see what every model got and answered. tinyeval sets `TINYEVAL_CALLS` to a file for each test case, and the app adds one line of JSON per call:

```ruby
if ENV["TINYEVAL_CALLS"]
  File.write(ENV["TINYEVAL_CALLS"], { call: "answer", model:, input: prompt, output: reply, cost: }.to_json + "\n", mode: "a")
end
```

`call` names the call, the same each time. The rest is optional: `model`, `input`, `output`, `error`, `input_tokens`, `output_tokens`, `cost` in dollars and `duration_ms`. A tool call or agent step can be a line too, with `"kind": "tool"` or `"kind": "step"`. These are the fields [evalship](https://evalship.com) takes from production, so the app records calls the same way in both.

tinyeval keeps the calls with each eval in the results file, lists them under a failing test case, and adds up their `cost` unless the reply says it with `#tinyeval cost_usd`.

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

This replaces `./tinyeval` with the latest release. Commit it. In a terminal, tinyeval checks for a new release once a day and names it under the summary. On GitHub Actions, it checks on every run and names a new release in the job summary. Other CI never checks. The check downloads the latest tinyeval from GitHub and sends nothing about your evals.

## In CI

tinyeval exits 1 when an eval fails or couldn't run, so any CI can run it. On GitHub Actions, the run's summary page lists what failed:

```yaml
name: Evals
on: pull_request
jobs:
  evals:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: ./tinyeval -n 3
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

A run that couldn't run also has `"metadata":{"couldnt_run":"why"}`, one whose reply said its cost has `"cost_usd"`, and one whose app recorded its [AI calls](#ai-calls) has `"calls"`.

## Share results

```sh
tinyeval share
```

This prints a private link to the results on evalship.com, failing evals first, with each input and reply. Send it to a teammate, or paste it into an issue. Anyone with the link can open it without an account, and search engines don't index it. It's deleted after 30 days, or sooner with the command `share` prints. In GitHub Actions, the run's summary page links it too.

`tinyeval share` sends `eval-results.json` and nothing else. `tinyeval share junit.xml` sends another results file instead, such as JUnit XML or promptfoo's JSON.

## Other eval tools

We ran the same suites in promptfoo and Braintrust, each installed from a cold cache on an M2 MacBook on 2026-11-05 and 06. [bench/](bench/) has the setups and the scripts.

| | tinyeval 0.5.0 | promptfoo 0.125.1 | Braintrust 0.49.2 (Python) |
|---|---|---|---|
| Needs | bash and curl | Node 22.22 or later | Python, and `openai` for judges |
| Install | 28 KB, 1 file, 0.2–6 s | 690 MB, 614 packages, 38–63 s | 65 MB, 35 packages, 7–11 s |
| Startup | 0.01 s | 0.8 s | 0.2 s |
| [examples/support.sh](examples/support.sh) | 9 lines | 22 lines, plus a 1-line script | 30 lines |
| 200 test cases, instant AI call | 1.3 s | 1.9 s | 1.0 s |
| 40 test cases, 3 runs, 1 s AI call | 15.5 s | 16.6 s | 15.7 s |
| Install, then those 40 test cases | 16 s | 54 s | 23 s |
| 20 test cases, 3 runs, an app that takes 2 s to start | 11.4 s | 25.5 s | 24.7 s |

With real AI calls, suite speed is a tie: 120 calls of a second, 8 at once, take 15 seconds at least, and all three finish within 2 of that. The difference is the install, on a CI runner without a dependency cache, and an app that's slow to start: tinyeval's `worker` keeps it running, while promptfoo's exec provider and our Braintrust task start it for each call. Both avoid that by calling a running server, and Braintrust by calling a Python app in-process. The speed rows give all three the same script as the AI call and a regex check, 4 and then 8 at once, and take the fastest of 3 tries. The support suite, with Haiku 5.5 answering and judging, took 8 to 10 seconds in tinyeval and Braintrust, nearly all of it model calls. Braintrust ran locally with `--no-send-logs`, without an account. promptfoo's judge didn't run: its `llm-rubric` sends `temperature`, which Claude Haiku 5.5 rejects ([promptfoo#12163](https://github.com/promptfoo/promptfoo/issues/12163)). With Claude Opus 5.5 or Sonnet 5.5 as the judge, it runs.

tinyeval has no viewer, reply cache or hosted datasets: its results are one JSON file. Pick promptfoo for red teaming or comparing many providers side by side. Pick Braintrust for a hosted place to compare experiments and keep datasets. Raindrop is a hosted product that monitors AI features in production, not an eval runner, so it isn't in the table.

To move evals you already have, with their names and checks, give your coding agent [migrate.md](migrate.md).

## Compare pull requests with main

A fresh CI run has no last run to compare with. [evalship](https://evalship.com) reads `eval-results.json` as is. It compares each pull request with main, tells flaky evals from real drops and comments on the pull request. Connect your repo on [evalship.com](https://evalship.com), then upload the file:

```yaml
      - run: ./tinyeval -n 3
        continue-on-error: true   # evalship's check is the gate
        env:
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
      - uses: actions/upload-artifact@v7
        if: always()
        with:
          name: eval-results
          path: eval-results.json
```

## Guides

- [LLM evals in Ruby, Go and Rust](https://evalship.com/articles/llm-evals-in-ruby-go-rust): tinyeval calling your real code in each, and in GitHub Actions
- [Recorded LLM replies in Rails tests pass any prompt change](https://evalship.com/articles/recorded-llm-replies-in-rails-tests): why 16 of 19 Ruby apps' replays miss prompt changes
- [LLM evals that can't fail](https://evalship.com/articles/llm-eval-flaws): the flaws found in 10 open-source eval suites
- [How noisy are LLM evals in CI?](https://evalship.com/articles/eval-noise): how often passing evals fail by chance, and why `-n 3` helps

## License

MIT
