# Run tinyeval

Run the evals for your AI features on every pull request, whatever language your app is in. The run's summary page lists each eval that failed, with its reply.

## Use it

In `.github/workflows/evals.yml`:

```yaml
name: Evals
on: pull_request
jobs:
  evals:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      # Set up your app's language here, as for its tests.
      - uses: evalship-hq/tinyeval-action@v0.11.1
        with:
          args: -n 3
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

| Input | Default | |
|---|---|---|
| `args` | `evals/*.sh` | tinyeval's [options](https://github.com/evalship-hq/tinyeval#options) and eval files, split on spaces |

`-n 3` runs each test case 3 times and passes it when at least 2 pass. `-x junit.xml` also writes JUnit XML.

## Write an eval

`evals/support.sh` lists the test cases and how to grade each reply:

```bash
worker python3 evals/worker.py

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

The worker starts your app once and answers each test case. It reads an input up to a NUL byte and prints the reply and a NUL byte. [examples/workers](https://github.com/evalship-hq/tinyeval/tree/main/examples/workers) has that loop in 14 languages. Or run a command per test case: `ask() { node bot.js "$1"; }`.

## When the AI call fails

When the call can't run at all, such as a missing key, a 429 or a timeout, start the reply with `#tinyeval couldnt_run REASON` on its own line. tinyeval counts that test case as couldn't run, apart from the failures, and still exits 1, so the step fails.

## Needs bash

tinyeval is a bash script, for bash 3.2 or later. GitHub's Linux and macOS runners have it, and on Windows runners the action uses Git for Windows' bash. A self-hosted runner needs one of those.

## Updating

Pin a release, as above, and Dependabot opens a pull request for each new one, so your evals run on it before you merge. In `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

`@v0` follows every 0.x release instead, and Dependabot leaves it alone until v1. A repo that commits its own `./tinyeval` file keeps running that file.

## More

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge and the options
- [Template repos](https://github.com/evalship-hq/tinyeval#quickstart): a support bot with its evals in CI, in your app's language
- This action is built from `packages/action` in [evalship-hq/tinyeval](https://github.com/evalship-hq/tinyeval). Send issues and pull requests there.
