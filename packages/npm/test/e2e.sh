#!/usr/bin/env bash
# Packs tinyeval as npm gets it, installs it into an empty project, and runs packages/e2e.sh through its command.
set -euo pipefail
pkg=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
(cd "$pkg" && npm pack --silent --pack-destination "$tmp" >/dev/null)
cd "$tmp"
npm init -y >/dev/null
npm install --silent --no-audit --no-fund --save-dev ./tinyeval-*.tgz
mkdir evals
cp "$pkg/../e2e.sh" evals/
cat >app.mjs <<'JS'
console.log("app loaded");
export function answer(input) {
  console.log("app called");
  if (input === "crash") throw new Error("boom");
  return `You said: ${input}`;
}
JS
cat >evals/worker.mjs <<'JS'
import { worker } from "tinyeval-cli";
import { answer } from "../app.mjs";
await worker(answer);
JS
E2E_WORKER="node evals/worker.mjs" npx tinyeval

version=$(node -p 'require("./node_modules/tinyeval-cli/package.json").version')
[ "$version" = "$(sed -n 's/^_te_version=//p' "$pkg/../../tinyeval")" ] || { echo "package.json has $version" >&2; exit 1; }
[ "$(npx tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $(npx tinyeval -v)" >&2; exit 1; }
code=0; said=$(npx tinyeval update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $said == *"npm install --save-dev tinyeval-cli@latest"* ]] || { echo "tinyeval update exited $code: $said" >&2; exit 1; }
# CommonJS can require it where Node can require ES modules (20.19, 22.12 and later).
node -e 'if (process.features.require_module && typeof require("tinyeval-cli").worker !== "function") process.exit(1)'
echo "end to end: ok"
