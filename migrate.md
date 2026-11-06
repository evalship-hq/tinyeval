# Move existing evals to tinyeval

If what you're reading is a summary, get the full text first: `curl -fsSL https://raw.githubusercontent.com/evalship-hq/tinyeval/main/migrate.md`

You're moving this repo's existing evals, run by a test framework or a script of its own, to tinyeval, a one-file bash runner. The evals must keep testing exactly what they test now, under the same names. Ask the user only where a step says to.

## 1. Read what runs today

Find every eval: the files, the fixtures they read, the checks that grade each reply, and the CI workflow that runs them, with its environment variables, schedules and how many times each case runs. Note what the harness does besides grading, such as caching, A/B labels, comparisons or files it writes. Install tinyeval as [setup.md](https://tinyeval.com/setup.md) step 1 says.

## 2. Keep the names

Tools that track results over time, such as evalship, key each eval by its suite and its name. Keep both exactly as the last results file has them, so no history starts over:

- tinyeval names a suite after its eval file, so `evals/prompts.sh` is suite `prompts`.
- A test case's name is its eval's name, and each needs its own.
- When one test case holds several evals today, write one `check NAME` per eval after its grading lines. Each is keyed "TEST CASE / NAME".

If a name can't stay, say so in step 7.

## 3. Keep the checks

Don't rewrite the checks in bash. Add a worker that calls the same function the eval calls now, runs the existing checks on its reply, and prints `{"problems": [...], "output": ...}`. Then grade each test case with `problems .problems`. The README's [worker examples](examples/workers/) show the input and reply protocol in several languages. A test case can list several checks' problems in one reply, each graded by its own `check` line.

When the call itself breaks after the app's own retries, such as a rate limit or an outage, start the reply with `#tinyeval couldnt_run REASON`, so it counts as couldn't run, not as a failure. If the harness recorded cost, keep it with `#tinyeval cost_usd DOLLARS`.

## 4. Write the test cases

Keep the cases in the fixture files they're in now, and loop over them in the eval file:

```bash
while IFS= read -r case_json; do
  test_case "$(jq -r .name <<<"$case_json")" "$case_json"
    problems .problems
done < <(jq -c '.[]' evals/fixtures/cases.json)
```

Add `target FILE#FUNCTION` lines for the code each test case covers.

## 5. Map the options

| Today | tinyeval |
|---|---|
| runs per case | `-n` |
| run one case | `-k NAME` |
| CI shards or a thread pool | `-j`, with one worker each |
| per-case timeout | `-t` |
| a results file per suite | `-o FILE` |

Check that cases can run side by side: what each writes to a shared database or files.

## 6. Check before switching

Run one or two test cases for real. Then compare the keys of `eval-results.json` with those of the last results file from CI:

```bash
diff <(jq -r '.evals[] | .suite + " / " + .key' old-results.json | sort -u) <(jq -r '.evals[] | .suite + " / " + .key' eval-results.json | sort -u)
```

The diff should be empty. Run the full suite once in CI, on the pull request, not on this machine.

## 7. Open a pull request

Replace the old eval files and harness code in the same pull request, so main never runs both. Its description lists what was kept, what tinyeval replaced, and what was removed, with any names that changed. The user merges it.
