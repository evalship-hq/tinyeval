#!/usr/bin/env bash
# Installs tinyeval, promptfoo and Braintrust from cold caches into a temp folder, then runs the same support
# suite in each: 2 test cases, 3 runs each, 4 at once, the example's AI call and Claude Haiku 5.5 as the judge.
# Needs Node 22.22 or later (promptfoo refuses older ones), python3, ruby with the anthropic gem, and ANTHROPIC_API_KEY.
set -eu
cd "$(dirname "$0")"
promptfoo=promptfoo@0.125.1 braintrust="braintrust==0.49.2 autoevals==0.4.1 openai"
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
since() { awk -v a="$1" -v b="$(now)" 'BEGIN { printf "%.1fs", b - a }'; }
kb() { du -sk "$@" | awk '{ s += $1 } END { print s " KB" }'; }
# Best of 3, so a cold disk cache doesn't count.
startup() { best=99; for _ in 1 2 3; do t=$(now); "$@" >/dev/null 2>&1; best=$(awk -v a="$t" -v b="$(now)" -v m="$best" 'BEGIN { d = b - a; print (d < m ? d : m) }'); done; printf '%.2fs' "$best"; }

echo "tinyeval"
t=$(now)
curl -fsSLo "$w/tinyeval" https://github.com/evalship-hq/tinyeval/releases/latest/download/tinyeval && chmod +x "$w/tinyeval"
echo "  install: $(since "$t"), $(kb "$w/tinyeval"), 1 file"
echo "  startup: $(startup "$w/tinyeval" -v)"
t=$(now)
(cd .. && "$w/tinyeval" -n 3 -j 4 -o "$w/te.json" examples/support.sh >"$w/te.out") || true
echo "  run:     $(since "$t") ($(tail -1 "$w/te.out"))"

echo "promptfoo ($promptfoo)"
t=$(now)
npm install --prefix "$w/pf" --cache "$w/npm-cache" --no-audit --no-fund --loglevel=error "$promptfoo" >/dev/null
echo "  install: $(since "$t"), $(kb "$w/pf/node_modules"), $(($(npm ls --all --parseable --prefix "$w/pf" 2>/dev/null | sort -u | wc -l) - 1)) packages"
export PROMPTFOO_CONFIG_DIR="$w/pf-config" PROMPTFOO_DISABLE_TELEMETRY=1 PROMPTFOO_DISABLE_UPDATE=1
echo "  startup: $(startup "$w/pf/node_modules/.bin/promptfoo" --version)"
t=$(now)
(cd promptfoo && "$w/pf/node_modules/.bin/promptfoo" eval --repeat 3 -j 4 --no-cache --no-table >"$w/pf.out" 2>&1) || true
echo "  run:     $(since "$t") ($(grep -iE 'pass(ed|ing)|fail' "$w/pf.out" | tail -1))"

echo "Braintrust ($braintrust)"
python3 -m venv "$w/bt"
base=$(du -sk "$w/bt" | cut -f1)
t=$(now)
# shellcheck disable=SC2086 # several packages
"$w/bt/bin/pip" install --no-cache-dir -q $braintrust
echo "  install: $(since "$t"), $(($(du -sk "$w/bt" | cut -f1) - base)) KB, $(($("$w/bt/bin/pip" list --format=freeze | wc -l) - 1)) packages"
echo "  startup: $(startup "$w/bt/bin/braintrust" --version)"
t=$(now)
(cd braintrust && OPENAI_BASE_URL=https://api.anthropic.com/v1 OPENAI_API_KEY=$ANTHROPIC_API_KEY \
  "$w/bt/bin/braintrust" eval --no-send-logs eval_support.py >"$w/bt.out" 2>&1) || true
echo "  run:     $(since "$t")"
grep -E 'judge|rules' "$w/bt.out" | head -4 | sed 's/^/           /'
if [ -n "${OUT-}" ]; then cp "$w"/*.out "$OUT"; fi # OUT=dir keeps each tool's output
