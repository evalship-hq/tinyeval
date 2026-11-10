# tinyeval

Check your JavaScript or TypeScript app's AI replies on every pull request, with test cases in a short bash file.

## Install

```sh
npm install --save-dev tinyeval-cli
```

## Example

`evals/support.sh` lists the test cases. Its `worker` line starts your app once and sends it each input:

```bash
worker node evals/worker.mjs

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`evals/worker.mjs` hands each input to your code and returns its reply:

```js
import { worker, CouldntRun } from "tinyeval-cli"; // first, so your app's console.log goes to stderr
import { answer } from "../src/support.js";

await worker(async (input) => {
  if (!process.env.ANTHROPIC_API_KEY) throw new CouldntRun("no ANTHROPIC_API_KEY");
  return answer(input);
});
```

An error your code throws becomes the reply, so the eval fails. `CouldntRun` marks the test case as couldn't run instead: tinyeval counts it apart from the failures, and still exits 1. So do bad keys, rate limits, server errors and timeouts from `@anthropic-ai/sdk` and `openai`.

The types come with the package. In TypeScript, name the file `worker.ts` and start it with `worker node evals/worker.ts` (Node 22.18 or later, or add `--experimental-strip-types`).

## Run it

```sh
npx tinyeval
```

`npx tinyeval -h` lists the options, such as `-n 3` to run each test case 3 times.

## Needs bash

tinyeval needs bash 3.2 or later. macOS and Linux come with it. On Windows, install [Git for Windows](https://gitforwindows.org). The worker helper runs on Node 18 or later.

## Updating

```sh
npm update tinyeval-cli
```

Or `pnpm update tinyeval-cli`, `yarn up tinyeval-cli`, `bun update tinyeval-cli`. Since the version sits in your lock file, Dependabot and Renovate open the update for you.

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every grading line, the judge and the options
- Example repos: [javascript-llm-evals](https://github.com/evalship-hq/javascript-llm-evals) and [typescript-llm-evals](https://github.com/evalship-hq/typescript-llm-evals)
