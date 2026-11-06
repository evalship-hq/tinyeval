// tinyeval worker in JavaScript. In your eval file:
//   worker node evals/worker.mjs
// Bun runs it too: worker bun evals/worker.mjs. Import your app's modules at the top, so they load once per worker.

async function reply(input) {
  return "You said: " + input; // your app's AI call goes here
}

let rest = Buffer.alloc(0);
for await (const chunk of process.stdin) {
  rest = Buffer.concat([rest, chunk]);
  let i;
  while ((i = rest.indexOf(0)) >= 0) {
    const input = rest.subarray(0, i).toString();
    rest = rest.subarray(i + 1);
    process.stdout.write((await reply(input)) + "\0");
  }
}
