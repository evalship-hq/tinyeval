# Set up evals with tinyeval

If what you're reading is a summary, get the full text first: `curl -fsSL https://tinyeval.com/setup.md`

You're adding evals for this repo's AI features with tinyeval, a one-file bash runner that sends test inputs through the real code and grades the replies. Follow the steps in order. Ask the user only where a step says to.

## 1. Install

In the repo root, download the runner:

```sh
curl -fsSLo tinyeval https://github.com/evalship-hq/tinyeval/releases/latest/download/tinyeval && chmod +x tinyeval
```

It's one bash file that needs only bash and curl, and it gets committed with the code. Read it, then run `./tinyeval -v` as a command of its own: permission checks block downloading and running a file in one step. Add `eval-results.json` to `.gitignore`. On Windows, run it in Git Bash.

## 2. Find the AI features

If the repo already has evals, move them instead: follow `curl -fsSL https://raw.githubusercontent.com/evalship-hq/tinyeval/main/migrate.md`, then come back for step 7.

Search the code for LLM calls: SDK clients (openai, anthropic, google-genai, ruby_llm, langchain and the like), HTTP calls to model APIs, prompt files and templates. For each, note its entry point, its prompt and what users get from it. Start with the feature users depend on most. If that isn't clear, ask the user.

## 3. Write ask

Create `evals/<feature>.sh`. Define `ask` so it runs the real code path, the function production calls, with the input as `$1` (and on stdin) and the reply on stdout:

```bash
ask() { bin/rails runner 'puts Summarizer.call(STDIN.read)'; }
ask() { python3 -m app.summarize "$1"; }
ask() { go run ./cmd/summarize "$1"; }
ask() { cargo run -q --bin summarize -- "$1"; }
```

If no entry point takes one input and prints the reply, add a small script that calls the production function, for example `script/eval_summarize`. When the app takes seconds to start, as a Rails or Django app does, use `worker COMMAND` instead of `ask`: tinyeval keeps COMMAND running, one per `-j`, and sends it each input up to a NUL byte on stdin. It prints each reply and a NUL byte, and flushes; the README has Ruby and Python examples. Never put a copy of the prompt in the eval: the eval must break when the real prompt or model changes. Print JSON replies as JSON. Read keys from the environment variables the app already uses.

Where the code path calls a model, record the call when `TINYEVAL_CALLS` is set: append one line of JSON to that file with `call` (a name for the call, the same each time), `model`, `input` (what the model got), `output`, and `cost`, `input_tokens` and `output_tokens` when the response has them. Use the language's JSON encoder, one object per line, not indented. A failing test case then shows what each model got and answered. The README's "AI calls" section has an example.

## 4. Write test cases

Write 5 to 10 test cases from realistic inputs: the common case, the edge cases the code handles, and anything that went wrong before (check comments, issues and commit messages). Grade each reply with the lines that state what must be true:

- `contains`, `not_contains`, `matches` and `equals` for facts and wording.
- `json 'FILTER'` for JSON replies and tool calls: passes when jq's FILTER is true, like `json '.category == "transfer"'`.
- `expect COMMAND` for other structure: any command or bash function that gets the reply on stdin and exits 0 when it's right.
- `problems '.problems'` when the app already has checks in its own language: the worker runs them and returns their problems with the reply.
- `judge "CRITERION"` for qualities a reader has to judge. One criterion per line, concrete enough that two people would agree.

Long inputs go in a heredoc:

```bash
test_case "angry customer" <<'IN'
My package never showed up and I'm getting really annoyed.
IN
  judge "Apologizes once and asks for the order number"
```

For a chat feature, the input is the conversation so far, in the shape the code takes (a JSON array of messages, for example), and the lines grade the last reply.

## 5. Run

Run `./tinyeval -n 3`: three runs per test case, four test cases at once. `judge` needs `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` (plus `TINYEVAL_JUDGE_MODEL`); ask the user for one if none is set.

For each failing test case, decide whether the eval or the feature is wrong. Fix a wrong eval. Leave an eval that catches a real bug failing, and don't change the feature unless the user asks.

A test case marked `!` couldn't run: its AI call failed or timed out, or the judge couldn't answer. Fix what broke, such as a missing key or a `-t` limit that's too short, not the test case.

## 6. CI

If the repo uses GitHub Actions, add `.github/workflows/evals.yml` with the steps the app needs to run (language setup, dependencies) and the keys `ask` and `judge` read:

```yaml
name: Evals
on: pull_request
jobs:
  evals:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      # the app's setup steps go here
      - run: ./tinyeval -n 3
        env:
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
```

## 7. Tell coding agents

Add this section to the repo's AGENTS.md, or to its CLAUDE.md if that's the only one. If the repo has neither, ask the user whether to create AGENTS.md with it.

```markdown
## Evals

The AI features have evals in `evals/`, run by `./tinyeval`. `./tinyeval -h` lists what an eval file can use.

- After you change a prompt, a model or an AI call, run `./tinyeval -n 3` and fix what broke. `-k NAME` runs only the test cases whose name contains NAME.
- When you add an AI feature or change what one should do, add or update its test cases.
- Leave an eval that catches a real bug failing; don't loosen it to pass.
- `./tinyeval update` installs the latest tinyeval. Commit the new `./tinyeval`.
```

## 8. Report

Tell the user, briefly: which features have evals and how many test cases, what failed and whether the feature or the eval is wrong, where the Evals section went, and which secrets to add in the repo settings for CI.
