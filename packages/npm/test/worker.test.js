// The worker helper, run as tinyeval runs it: inputs and NUL bytes on stdin, replies on stdout.
import { spawn } from "node:child_process";
import assert from "node:assert/strict";
import test from "node:test";

const helper = new URL("../index.js", import.meta.url).href;

// Starts a worker whose app is `app`, writes each chunk to its stdin with a pause between them, and returns its output.
function run(app, chunks) {
  const code = `import { worker, CouldntRun } from ${JSON.stringify(helper)};\n${app}\nawait worker(answer);`;
  const child = spawn(process.execPath, ["--input-type=module", "-e", code]);
  const out = [], err = [];
  child.stdout.on("data", (d) => out.push(d));
  child.stderr.on("data", (d) => err.push(d));
  return new Promise((resolve) => {
    child.on("close", (status) => resolve({ status, stdout: Buffer.concat(out).toString(), stderr: Buffer.concat(err).toString() }));
    (async () => {
      for (const chunk of chunks) {
        child.stdin.write(chunk);
        await new Promise((r) => setTimeout(r, 50));
      }
      child.stdin.end();
    })();
  });
}

const echo = "const answer = async (input) => `You said: ${input}`;";

test("several inputs in one chunk, and UTF-8 input split across chunks", async () => {
  const split = Buffer.from("naïve 日本語 ✓\0");
  const r = await run(echo, ["one\0two\0", split.subarray(0, 8), split.subarray(8)]); // byte 8 is inside "日"
  assert.equal(r.stdout, "You said: one\0You said: two\0You said: naïve 日本語 ✓\0");
  assert.equal(r.status, 0);
});

test("the app's output goes to stderr, and NUL bytes leave the reply", async () => {
  const app = `console.log("app loaded"); process.stdout.write("raw\\n");
    const answer = (input) => { console.info("app called"); return "a\\0b"; };`;
  const r = await run(app, ["hi\0"]);
  assert.equal(r.stdout, "ab\0");
  assert.match(r.stderr, /app loaded\nraw\napp called/);
});

test("CouldntRun and SDK errors that aren't the app's fault couldn't run", async () => {
  const app = `class AnthropicError extends Error {}
    class APIError extends AnthropicError { constructor(status) { super(status + " body"); this.status = status; } }
    class RateLimitError extends APIError {}
    class BadRequestError extends APIError {}
    class APIConnectionError extends APIError { constructor() { super(undefined); } }
    class APIConnectionTimeoutError extends APIConnectionError {}
    class OpenAIError extends Error {}
    class InternalServerError extends OpenAIError { constructor() { super("529"); this.status = 529; } }
    const errors = {
      key: () => new CouldntRun("no ANTHROPIC_API_KEY\\nset it"), limit: () => new RateLimitError(429),
      timeout: () => new APIConnectionTimeoutError(), openai: () => new InternalServerError(),
      bad: () => new BadRequestError(400),
    };
    const answer = (input) => { throw errors[input](); };`;
  const r = await run(app, ["key\0limit\0timeout\0openai\0bad\0"]);
  assert.deepEqual(r.stdout.split("\0"), [
    "#tinyeval couldnt_run no ANTHROPIC_API_KEY set it\n",
    "#tinyeval couldnt_run anthropic: 429 RateLimitError\n",
    "#tinyeval couldnt_run anthropic: APIConnectionTimeoutError\n",
    "#tinyeval couldnt_run openai: 529 InternalServerError\n",
    "Error: 400 body", // any other API error fails the eval
    "",
  ]);
});

test("an app error becomes the reply, its stack goes to stderr, and the worker keeps going", async () => {
  const app = `const answer = async (input) => { if (input === "crash") throw new TypeError("boom"); return "ok"; };`;
  const r = await run(app, ["crash\0again\0"]);
  assert.equal(r.stdout, "TypeError: boom\0ok\0");
  assert.match(r.stderr, /TypeError: boom\n\s+at answer/);
  assert.equal(r.status, 0);
});
