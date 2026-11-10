# tinyeval

Test your Python app's AI calls from the command line: write test cases in a short bash file, and tinyeval runs them against your real code and says which replies pass.

## Install

```sh
pip install tinyeval-cli
```

With uv, as a dev dependency:

```sh
uv add --dev tinyeval-cli
```

## Example

`evals/support.sh` lists the test cases. Its `worker` line starts your app once, not once per test case:

```bash
worker python -m evals.worker

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`evals/worker.py` hands each input to your code. Import `tinyeval` before your app, so the app's prints go to stderr and only replies reach tinyeval:

```python
import os

from tinyeval import CouldntRun, worker

from app.support import answer


def reply(message):
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise CouldntRun("ANTHROPIC_API_KEY isn't set")
    return answer(message)


worker(reply)
```

`reply` can also be an `async def`.

## Run it

```sh
tinyeval
```

With uv: `uv run tinyeval`. Add `-n 3` to run each test case three times.

## Errors

- **`CouldntRun("reason")`** marks the test case as couldn't run. tinyeval counts it apart from failures, and still exits 1.
- **Errors from the `anthropic` and `openai` SDKs** count as couldn't run too, when the cause isn't your code: status 401, 429 or 500 and up, connection errors and timeouts.
- **Any other exception** becomes the reply, such as `ValueError: no order id`, so the eval fails. Its traceback goes to stderr.

## Needs bash

bash 3.2 or later: macOS and Linux have it, and on Windows it comes with [Git for Windows](https://gitforwindows.org).

## Updating

```sh
pip install -U tinyeval-cli
```

With uv: `uv lock --upgrade-package tinyeval`. tinyeval is a normal dependency in your lock file, so Dependabot and Renovate open pull requests for new versions.

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every line an eval file can use, the judge included.
- [python-llm-evals](https://github.com/evalship-hq/python-llm-evals): a support bot with its evals, run on every pull request.
