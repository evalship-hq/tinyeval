#!/usr/bin/env bash
# Runs tinyeval on the fixtures and checks its exit codes, output and results file.
cd "$(dirname "$0")/.." || exit 1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
ok() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

# The tests read results with jq; tinyeval must not need it, so a jq that fails comes first in PATH.
real_jq=$(command -v jq) || { echo "the tests need jq"; exit 1; }
jqr() { "$real_jq" "$@"; }
mkdir "$tmp/bin" && printf '#!/bin/sh\necho "tinyeval called jq" >&2\nexit 99\n' >"$tmp/bin/jq" && chmod +x "$tmp/bin/jq"
export PATH="$tmp/bin:$PATH"

# The fake judge passes a reply that mentions "30 days" and fails any other.
export TINYEVAL_JUDGE='input=$(cat); case $input in *"30 days"*) echo "PASS it does";; *) printf "**FAIL**\nIt approves the refund.";; esac'

out=$(./tinyeval -o "$tmp/basics.json" test/fixtures/basics.sh 2>&1); code=$?
ok "basics pass" '[ $code -eq 0 ]'
ok "basics: valid JSON, six evals" '[ "$(jqr ".evals | length" "$tmp/basics.json")" -eq 6 ]'
ok "basics: suite and file set" 'jqr -e ".evals[0] | .suite == \"basics\" and .file == \"test/fixtures/basics.sh\"" "$tmp/basics.json" >/dev/null'
ok "basics: heredoc input kept" 'jqr -e ".evals[4].input == \"line one\nline two\"" "$tmp/basics.json" >/dev/null'
ok "basics: summary" '[[ $out == *"All 6 evals passed"* ]]'
ok "basics: no jq call" '[[ $out != *"called jq"* ]]'

./tinyeval -o "$tmp/esc.json" test/fixtures/escaping.sh >/dev/null; code=$?
ok "escaping: passes" '[ $code -eq 0 ]'
# tr: jq.exe on Windows writes CRLF.
ok "escaping: output survives as JSON" '[ "$(jqr -r ".evals[0].output" "$tmp/esc.json" | tr -d "\r")" = "$(printf "back\\\\slash \"quoted\"\ttab\nline two [31mred[0m")" ]'
ok "escaping: key with quotes" 'jqr -e ".evals[0].key == \"escaping \\\"quotes\\\"\"" "$tmp/esc.json" >/dev/null'

out=$(./tinyeval -o "$tmp/failing.json" test/fixtures/failing.sh); code=$?
ok "failing exits 1" '[ $code -eq 1 ]'
ok "failing: contains reason" '[[ $out == *"expected to contain \"30 days\""* ]]'
ok "failing: judge reason without verdict" '[[ $out == *"judge: It approves the refund."* ]]'
ok "failing: ask error shown" '[[ $out == *"ask failed (exit 3): rate limited"* ]]'
ok "failing: failure in results" 'jqr -e ".evals[0].passed == false and (.evals[0].failure | contains(\"judge: It approves\"))" "$tmp/failing.json" >/dev/null'

# The judge's API, faked with files: curl reads file:// URLs and ignores the request body.
api() { mkdir -p "$tmp/api/chat" && printf '%s' "$1" >"$tmp/api/chat/completions"; }
api_url="file://$tmp/api"
if command -v cygpath >/dev/null; then api_url="file:///$(cygpath -m "$tmp/api")"; fi # curl.exe on Windows
judge() { TINYEVAL_JUDGE='' TINYEVAL_JUDGE_URL=$api_url TINYEVAL_JUDGE_MODEL=m ./tinyeval -o "$tmp/judge.json" test/fixtures/judge.sh; }
api '{"choices":[{"message":{"role":"assistant","content":"**FAIL**\nIt says \"yes\" to a refund."}}]}'
out=$(judge); code=$?
ok "judge API: FAIL and its reason" '[ $code -eq 1 ] && [[ $out == *"judge: It says \"yes\" to a refund."* ]]'
api '{"choices":[{"message":{"role":"assistant","content":"PASS\nIt declines."}}]}'
out=$(judge); code=$?
ok "judge API: PASS" '[ $code -eq 0 ]'
api '{"error":{"message":"Invalid API key","code":401}}'
out=$(judge); code=$?
ok "judge API: error message shown" '[ $code -eq 1 ] && [[ $out == *"judge couldn'"'"'t run: Invalid API key"* ]]'

export COUNTER="$tmp/counter"
out=$(./tinyeval -n 3 -o "$tmp/flaky.json" test/fixtures/flaky.sh); code=$?
ok "flaky: 2 of 3 passes" '[ $code -eq 0 ] && [[ $out == *"mostly yes"*"2/3"* ]]'
ok "flaky: one entry per run" '[ "$(jqr "[.evals[] | select(.passed)] | length" "$tmp/flaky.json")" -eq 2 ] && [ "$(jqr ".evals | length" "$tmp/flaky.json")" -eq 3 ]'

out=$(./tinyeval -o "$tmp/noask.json" test/fixtures/noask.sh); code=$?
ok "no ask: fails with a hint" '[ $code -eq 1 ] && [[ $out == *"define ask in test/fixtures/noask.sh"* ]]'

./tinyeval -o "$tmp/x.json" test/fixtures/empty.sh >/dev/null 2>&1; code=$?
ok "no test cases exits 2" '[ $code -eq 2 ]'
./tinyeval -n 0 test/fixtures/basics.sh >/dev/null 2>&1; code=$?
ok "bad -n exits 2" '[ $code -eq 2 ]'
./tinyeval test/fixtures/missing.sh >/dev/null 2>&1; code=$?
ok "missing file exits 2" '[ $code -eq 2 ]'

# A previous run where "wrong reply" passed: line 2 of the file is its first eval.
sed '2s/"passed":false/"passed":true/' "$tmp/failing.json" >"$tmp/prev.json"
out=$(./tinyeval -o "$tmp/prev.json" test/fixtures/failing.sh)
ok "since last run: names the new failure" '[[ $out == *"Since the last run"*"failing › wrong reply fails now"* ]]'
ok "since last run: unchanged evals left out" '[[ $out != *"ask fails fails now"* ]]'

[ $fails -eq 0 ] && echo "all tests passed" || { echo "$fails failed"; exit 1; }
