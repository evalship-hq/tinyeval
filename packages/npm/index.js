// tinyeval's worker helper: `await worker(answer)` answers each input from an eval file's worker line.
// Import it before your app, so the app's output can't mix into the replies on stdout.
import { writeSync } from "node:fs";

// process.stdout, and with it console.log, becomes stderr. Replies go straight to fd 1, which no stream has opened,
// so it stays blocking. Node can't dup2: a child process that inherits stdout still writes to the real one.
const stderr = process.stderr;
Object.defineProperty(process, "stdout", { configurable: true, enumerable: true, get: () => stderr });

export class CouldntRun extends Error {
  name = "CouldntRun";
}

function send(text) {
  const bytes = Buffer.from(text.replaceAll("\0", "") + "\0");
  for (let at = 0; at < bytes.length; ) {
    try {
      at += writeSync(1, bytes, at);
    } catch (err) {
      if (err.code !== "EAGAIN") throw err; // something opened stdout as a stream, which made it non-blocking
    }
  }
}

// Why the call couldn't run, or null when the error is the reply. SDK errors are known by their class names,
// so neither SDK has to be installed.
function couldntRun(err) {
  if (err?.name === "CouldntRun") return err.message;
  const names = [];
  for (let p = Object(err); (p = Object.getPrototypeOf(p)); ) names.push(p.constructor?.name);
  const sdk = names.includes("AnthropicError") ? "anthropic" : names.includes("OpenAIError") ? "openai" : null;
  if (!sdk) return null;
  if (names.includes("APIConnectionError")) return `${sdk}: ${names[0]}`; // the network or a timeout
  const status = err.status;
  return status === 401 || status === 429 || status >= 500 ? `${sdk}: ${status} ${names[0]}` : null;
}

export async function worker(answer) {
  let rest = Buffer.alloc(0);
  for await (const chunk of process.stdin) {
    rest = Buffer.concat([rest, chunk]);
    let i;
    while ((i = rest.indexOf(0)) >= 0) {
      const input = rest.subarray(0, i).toString(); // decoded once whole, so a character split across reads survives
      rest = rest.subarray(i + 1);
      let reply;
      try {
        reply = String(await answer(input));
      } catch (err) {
        console.error(err);
        const reason = couldntRun(err);
        reply = reason === null ? String(err) : `#tinyeval couldnt_run ${reason.replace(/\s+/g, " ").trim()}\n`;
      }
      send(reply);
    }
  }
  process.exit(0);
}
