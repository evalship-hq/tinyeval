---
name: tinyeval
description: Check a prompt, model or LLM call change on real inputs before you finish it, and keep those checks as test cases in the repo. Use whenever you edit a prompt or system message, switch models, change model settings (temperature, max tokens, tools, response format) or change the code around an AI API call (OpenAI, Anthropic, Gemini, OpenRouter, Bedrock, Ollama, LangChain, ruby_llm, Vercel AI SDK and the like), and when the user asks to tweak, improve, test, compare or eval a prompt or model, or asks whether a change made the replies worse. Works in any language.
---

# Check AI changes with tinyeval

A prompt or model change can fix the reply you looked at and break three you didn't. Don't try a few inputs by hand and move on: write them as test cases, run them before and after the change, and leave them in the repo so the next change runs them too. tinyeval is a one-file bash runner that sends each input through the real code and grades the reply.

## 1. Find the evals

- `./tinyeval` and `evals/*.sh` exist: go to step 2.
- The repo has other evals (promptfoo, pytest, DeepEval, a script): run those before and after the change, the way steps 2 to 4 describe, and leave tinyeval out. If the user wants to move them, follow [migrate.md](migrate.md) in this skill's folder.
- No evals: follow "Add tinyeval" below for the feature you're changing. Don't stop to ask first: the eval file and `./tinyeval` are part of your change, and your report names them so the user can drop them.

Always make the change the user asked for, even when the check can't run (a missing key, no network). Then say what the check still needs and the command that runs it.

## 2. Before the change

Make sure a test case covers what the user asked for (a friendlier tone, a new field, the bug they hit) and the inputs you'd have tried by hand. Add them to the feature's eval file if not. Then run that file:

```sh
./tinyeval -n 3 evals/<feature>.sh
```

`-n 3` runs each test case three times, as the same input can get a different reply. This is the baseline: tinyeval saves it in `eval-results.json`. A new test case that fails now and passes after the change is the proof the change works.

If you already made the change, put the old version back for this run (`git stash push -- <changed files>`, run, `git stash pop`). When switching models, also copy `eval-results.json` aside: each line has `duration_ms`, and `cost_usd` when the reply reports it or the app records its AI calls.

## 3. After the change

Run the same command. Under "Since the last run", tinyeval lists every test case that now passes or fails.

For each failure, decide whether the change or the eval is wrong. When the app records its AI calls, the test case's line in `eval-results.json` has `calls`: what each model got and answered, so you can see which call went wrong. Fix the change. Change an eval only when it checks something the user no longer wants. Never loosen an eval so it passes. A test case marked `!` couldn't run (its AI call failed or timed out, or the judge couldn't answer): fix what broke, such as a missing key.

## 4. Report

In a few lines: passing test cases before and after (7 of 10, then 10 of 10), what flipped, the test cases and files you added, and anything that couldn't run. For a model switch, add how the reply time (and the cost, if recorded) moved.

## Add tinyeval

1. In the repo root, download it. Then run `./tinyeval -v` as a command of its own, since permission checks block downloading and running a file in one step. Add `eval-results.json` to `.gitignore`. On Windows, run it in Git Bash.

   ```sh
   curl -fsSLo tinyeval https://github.com/evalship-hq/tinyeval/releases/download/v0.10.0/tinyeval && echo "b061feecf2654a5b6a746dd146a517acb017e30221185cd8552f7d1a9cdccb94  tinyeval" | shasum -a 256 -c && chmod +x tinyeval
   ```

2. Create `evals/<feature>.sh`. Define `ask` so it runs the code path production uses, with the input as `$1` (and on stdin) and the reply on stdout. Never put a copy of the prompt in the eval: the eval must break when the real prompt or model changes. If no entry point takes one input and prints the reply, add a small script that calls the production function.

   ```bash
   ask() { python3 -m app.summarize "$1"; }
   ask() { bin/rails runner 'puts Summarizer.call(STDIN.read)'; }
   ask() { node scripts/summarize.mjs "$1"; }
   ask() { go run ./cmd/summarize "$1"; }
   ```

   For an app that takes seconds to start, use `worker COMMAND` instead: `./tinyeval -h` and the README explain it.

3. Write 5 to 10 test cases: the case the user asked about, the inputs you'd have tried by hand, the common case, and the edge cases the code handles. Run `./tinyeval -h` for every grading line. In short:

   ```bash
   test_case "refund after the window" "Can I return shoes that arrived 40 days ago?"
     matches "30[- ]day"
     judge "Says a refund isn't possible anymore, politely"

   test_case "angry customer" <<'IN'
   My package never showed up and I'm getting really annoyed.
   IN
     judge "Apologizes once and asks for the order number"
   ```

   Prefer `contains`, `matches`, `equals` and `json 'FILTER'` for facts, wording and structure. Use `judge` for what a reader has to judge, one concrete criterion per line.

4. Keys. `ask` needs the key the app already reads; if it isn't set, ask the user for it. Never fake or mock the reply. `judge` uses `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY` or `OPENAI_API_KEY` (plus `TINYEVAL_JUDGE_MODEL`). With none set, a command that reads the prompt on stdin works too, such as `TINYEVAL_JUDGE='claude -p --model haiku'` in Claude Code. Pick a judge model the feature doesn't use.

5. Add this section to the repo's AGENTS.md, or to its CLAUDE.md if that's the only one, so the next agent runs the evals without this skill. If the repo has neither, ask whether to create AGENTS.md with it.

   ```markdown
   ## Evals

   The AI features have evals in `evals/`, run by `./tinyeval`. `./tinyeval -h` lists what an eval file can use.

   - After you change a prompt, a model or an AI call, run `./tinyeval -n 3` and fix what broke. `-k NAME` runs only the test cases whose name contains NAME.
   - When you add an AI feature or change what one should do, add or update its test cases.
   - Leave an eval that catches a real bug failing; don't loosen it to pass.
   ```

To cover every AI feature in the repo and run the evals in CI, follow [setup.md](setup.md) in this skill's folder.
