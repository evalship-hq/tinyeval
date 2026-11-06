#!/usr/bin/env bash
# How fast tinyeval, promptfoo and Braintrust run the same suite. The AI call is a stub script, the same in all three,
# and each test case has one regex check, so the times are the runners' own:
#   overhead:  200 test cases, 1 run, 4 at once, an AI call that answers at once
#   parallel:  40 test cases, 3 runs, 8 at once, an AI call that takes 1 second, like a model (15 s at best)
# Installs promptfoo and Braintrust into a temp folder. Needs Node 22.22 or later and python3.
set -eu
cd "$(dirname "$0")"
promptfoo=promptfoo@0.125.1 braintrust="braintrust==0.49.2 autoevals==0.4.1"
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
since() { awk -v a="$1" -v b="$(now)" 'BEGIN { printf "%.1f s", b - a }'; }

cp ../tinyeval "$w/tinyeval"
npm install --prefix "$w/pf" --cache "$w/npm-cache" --no-audit --no-fund --loglevel=error "$promptfoo" >/dev/null
export PROMPTFOO_CONFIG_DIR="$w/pf-config" PROMPTFOO_DISABLE_TELEMETRY=1 PROMPTFOO_DISABLE_UPDATE=1
python3 -m venv "$w/bt"
# shellcheck disable=SC2086 # several packages
"$w/bt/bin/pip" install --no-cache-dir -q $braintrust

# run NAME CASES RUNS JOBS DELAY
run() {
  local d="$w/$1" n=$2 runs=$3 jobs=$4 t
  mkdir -p "$d/evals"
  printf 'sleep %s\necho "Sorry, refunds are only possible within 30 days."\n' "$5" >"$d/ask.sh"

  { printf 'ask() { sh %q "$1"; }\n' "$d/ask.sh"
    printf 'i=1\nwhile [ $i -le %s ]; do\n  test_case "case $i" "Can I return item $i?"\n    matches "30[- ]day"\n  i=$((i + 1))\ndone\n' "$n"
  } >"$d/evals/speed.sh"
  { echo q; i=1; while [ "$i" -le "$n" ]; do echo "Can I return item $i?"; i=$((i + 1)); done; } >"$d/cases.csv"
  printf "prompts: ['{{q}}']\nproviders: ['exec: sh %s']\ndefaultTest:\n  assert:\n    - type: regex\n      value: 30[- ]day\ntests: file://cases.csv\n" \
    "$d/ask.sh" >"$d/promptfooconfig.yaml"
  cat >"$d/eval_speed.py" <<PY
import re, subprocess
from braintrust import Eval
Eval("speed", data=lambda: [{"input": f"Can I return item {i}?"} for i in range(1, $n + 1)],
     task=lambda input: subprocess.run(["sh", "$d/ask.sh", input], capture_output=True, text=True, check=True).stdout,
     scores=[lambda output, **kw: 1 if re.search(r"30[- ]day", output) else 0],
     trial_count=$runs, max_concurrency=$jobs)
PY

  echo "$1: $n test cases, $runs run(s) each, $jobs at once, AI call $5 s"
  t=$(now)
  (cd "$d" && "$w/tinyeval" -n "$runs" -j "$jobs" -o "$d/te.json" evals/speed.sh >"$d/te.out" 2>&1) || true
  echo "  tinyeval:   $(since "$t") ($(tail -1 "$d/te.out" | sed 's/ (.*//'))"
  t=$(now)
  (cd "$d" && "$w/pf/node_modules/.bin/promptfoo" eval --repeat "$runs" -j "$jobs" --no-cache --no-table --no-progress-bar \
    >"$d/pf.out" 2>&1) || true
  echo "  promptfoo:  $(since "$t") ($(grep -m 1 'passed (' "$d/pf.out" | sed 's/^[^0-9]*//'))"
  t=$(now)
  (cd "$d" && "$w/bt/bin/braintrust" eval --no-send-logs eval_speed.py >"$d/bt.out" 2>&1) || true
  echo "  Braintrust: $(since "$t") ($(grep -m 1 'score$' "$d/bt.out"))"
}

run overhead 200 1 4 0
run parallel 40 3 8 1
