# Set up evals with tinyeval

If what you're reading is a summary, get the full text first: `curl -fsSL https://tinyeval.com/setup.md`

You're adding evals for this repo's AI features with tinyeval, a one-file bash runner that sends test inputs through the real code and grades the replies. Follow the steps in order. Ask the user only where a step says to.

## 1. Install

In the repo root, run:

```sh
curl -fsSL https://tinyeval.com/install.sh | sh
./tinyeval
```

The installer adds `./tinyeval`, `evals/example.sh` and an `eval-results.json` line in `.gitignore`. The example should pass. On Windows, run it in Git Bash.

## 2. Find the AI features

Search the code for LLM calls: SDK clients (openai, anthropic, google-genai, ruby_llm, langchain and the like), HTTP calls to model APIs, prompt files and templates. For each, note its entry point, its prompt and what users get from it. Start with the feature users depend on most. If that isn't clear, ask the user.

## 3. Write ask

Create `evals/<feature>.sh` and delete `evals/example.sh`. Define `ask` so it runs the real code path, the function production calls, with the input as `$1` (and on stdin) and the reply on stdout:

```bash
ask() { bin/rails runner 'puts Summarizer.call(STDIN.read)'; }
ask() { python3 -m app.summarize "$1"; }
ask() { go run ./cmd/summarize "$1"; }
ask() { cargo run -q --bin summarize -- "$1"; }
ask() { curl -s localhost:3000/api/summarize --data-binary @-; }
```

If no entry point takes one input and prints the reply, add a small script that calls the production function, for example `script/eval_summarize`. Never copy the prompt into the eval: the eval must break when the real prompt or model changes. Print JSON replies as JSON. Read keys from the environment variables the app already uses.

## 4. Write test cases

Write 5 to 10 test cases from realistic inputs: the common case, the edge cases the code handles, and anything that went wrong before (check comments, issues and commit messages). Grade each reply with the lines that state what must be true:

- `contains`, `not_contains`, `matches` and `equals` for facts and wording.
- `expect COMMAND` for structure: any command or bash function that gets the reply on stdin and exits 0 when it's right.
- `judge "CRITERION"` for qualities a reader has to judge. One criterion per line, concrete enough that two people would agree.

Long inputs go in a heredoc:

```bash
test_case "angry customer" <<'IN'
My package never showed up and I'm getting really annoyed.
IN
  judge "Apologizes once and asks for the order number"
```

## 5. Run

Run `./tinyeval -n 3 -j 4`: three runs per test case, four test cases at once. `judge` needs `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` (plus `TINYEVAL_JUDGE_MODEL`); ask the user for one if none is set.

For each failing test case, decide whether the eval or the feature is wrong. Fix a wrong eval. Leave an eval that catches a real bug failing, and don't change the feature unless the user asks.

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
      - run: ./tinyeval -n 3 -j 4
        env:
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
```

## 7. Report

Tell the user, briefly: which features have evals and how many test cases, what failed and whether the feature or the eval is wrong, and which secrets to add in the repo settings for CI.
