# tinyeval for R

Find out when a prompt edit or a model swap makes the AI replies of your R code worse. Your test cases sit in a short bash file, and your own R functions answer them.

## Install

From R-universe:

```r
install.packages("tinyeval", repos = c("https://evalship-hq.r-universe.dev", getOption("repos")))
```

In an renv project, run `renv::snapshot()` after, so renv.lock records it.

## Example

`evals/support.sh` holds the test cases. Its `worker` line starts R once per worker, not once per test case:

```bash
worker Rscript evals/worker.R

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`evals/worker.R` loads your code and hands it each input:

```r
library(tinyeval) # before your code, so its printing stays out of the replies
source("R/support.R")

worker(function(input) {
  if (Sys.getenv("ANTHROPIC_API_KEY") == "") couldnt_run("ANTHROPIC_API_KEY isn't set")
  answer(input)
})
```

## Run it

From the project root:

```sh
Rscript -e 'quit(status = tinyeval::run())'            # every file in evals/
Rscript -e 'quit(status = tinyeval::run("-n", "3"))'   # each test case 3 times; it passes when 2 do
```

`tinyeval::run()` returns tinyeval's exit code, and `quit(status = ...)` hands it to CI, so a failing eval fails the job. Ctrl-C stops the run.

tinyeval needs bash 3.2 or later: macOS, Linux, or Git for Windows, whose bash `run()` finds on its own.

## Errors

- **`couldnt_run("reason")`** marks the test case as couldn't run. tinyeval counts it apart from the failures, and the run still exits 1.
- **httr2 errors**, ellmer's included, count as couldn't run on a 401, 429 or 5xx response, and when the request couldn't connect or timed out. They match by class, so httr2 needn't be installed.
- **Any other error** becomes the reply, such as `simpleError: boom`, so the eval fails. Its calls go to stderr, and the worker goes on with the next input.

## Output

In a worker tinyeval starts, `library(tinyeval)` points R's output at stderr with `sink()`, so `print()` and `cat()` can't end up in a reply. The replies go to the process's stdout. Base R can't move a file descriptor, so programs started with `system()`, and C code that writes to stdout directly, still reach the replies.

R reads `.Rprofile` before your worker file, so what it prints lands in the first reply. `tinyeval::run()` turns off renv's out-of-sync note for its workers.

## Updating

```r
install.packages("tinyeval", repos = "https://evalship-hq.r-universe.dev")
```

`tinyeval::run("update")` prints that line, and the run's summary says when a new release is out. Dependabot and Renovate don't read renv.lock yet.

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge, and more
- [evalship-hq/r-llm-evals](https://github.com/evalship-hq/r-llm-evals): an R support bot on httr2, with its evals in CI
