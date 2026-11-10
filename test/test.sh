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
export XDG_CACHE_HOME="$tmp/cache" # where the daily update check keeps the latest version
furl() { if command -v cygpath >/dev/null; then echo "file:///$(cygpath -m "$1")"; else echo "file://$1"; fi; }
export TINYEVAL_DOWNLOAD_URL="$(furl "$tmp/no-release")" # the update checks stay offline; tests that want a release set it

# The fake judge passes a reply that mentions "30 days" and fails any other.
export TINYEVAL_JUDGE='input=$(cat); case $input in *"30 days"*) echo "PASS it does";; *) printf "**FAIL**\nIt approves the refund.";; esac'

out=$(./tinyeval -o "$tmp/basics.json" test/fixtures/basics.sh 2>&1); code=$?
ok "basics pass" '[ $code -eq 0 ]'
ok "basics: valid JSON, six evals" '[ "$(jqr ".evals | length" "$tmp/basics.json")" -eq 6 ]'
ok "basics: suite and file set" 'jqr -e ".evals[0] | .suite == \"basics\" and .file == \"test/fixtures/basics.sh\"" "$tmp/basics.json" >/dev/null'
ok "basics: heredoc input kept" 'jqr -e ".evals[4].input == \"line one\nline two\"" "$tmp/basics.json" >/dev/null'
ok "basics: summary" '[[ $out == *"All 6 evals passed"* ]]'
ok "basics: no jq call" '[[ $out != *"called jq"* ]]'

out=$(TMPDIR=/nonexistent ./tinyeval -o "$tmp/notmp.json" test/fixtures/basics.sh 2>&1); code=$?
ok "a TMPDIR it can't write to: works in the repo, leaves nothing" '[ $code -eq 0 ] && [[ $out == *"All 6 evals passed"* ]] && [ -z "$(ls -A | grep "^.tinyeval\\.")" ]'

./tinyeval -o "$tmp/esc.json" test/fixtures/escaping.sh >/dev/null; code=$?
ok "escaping: passes" '[ $code -eq 0 ]'
# tr: jq.exe on Windows writes CRLF.
ok "escaping: output survives as JSON" '[ "$(jqr -r ".evals[0].output" "$tmp/esc.json" | tr -d "\r")" = "$(printf "back\\\\slash \"quoted\"\ttab\nline two [31mred[0m")" ]'
ok "escaping: key with quotes" 'jqr -e ".evals[0].key == \"escaping \\\"quotes\\\"\"" "$tmp/esc.json" >/dev/null'

out=$(./tinyeval -o "$tmp/braces.json" test/fixtures/braces.sh 2>&1); code=$?
ok "braces: inputs keep them, so bash 3.2 can't multiply JSON rows" '[ $code -eq 0 ] && [[ $out == *"All 2 evals passed"* ]]'

out=$(./tinyeval -o "$tmp/failing.json" test/fixtures/failing.sh); code=$?
ok "failing exits 1" '[ $code -eq 1 ]'
ok "failing: contains reason" '[[ $out == *"expected to contain \"30 days\""* ]]'
ok "failing: judge reason without verdict" '[[ $out == *"judge: It approves the refund."* ]]'
ok "failing: ask error shown" '[[ $out == *"ask failed (exit 3): rate limited"* ]]'
ok "failing: a broken AI call couldn't run" '[[ $out == *"! ask fails couldn'"'"'t run"* ]] && [[ $out == *"1 of 2 evals failed, 1 couldn'"'"'t run"* ]]'
ok "failing: couldnt_run in results" 'jqr -e ".evals[1].metadata.couldnt_run | startswith(\"ask failed (exit 3)\")" "$tmp/failing.json" >/dev/null && jqr -e ".evals[0].metadata == null" "$tmp/failing.json" >/dev/null'
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
ok "judge API: error message shown" '[ $code -eq 1 ] && [[ $out == *"judge couldn'"'"'t run: Invalid API key"* ]] && [[ $out == *"1 of 1 evals couldn'"'"'t run"* ]]'

api '{"choices":[{"message":{"role":"assistant","content":"The reply does not PASS: it approves the refund."}}]}'
out=$(judge); code=$?
ok "judge API: \"does not PASS\" is no pass" '[ $code -eq 1 ] && [[ $out == *"judge gave no PASS or FAIL"* ]]'
api '{"choices":[{"message":{"role":"assistant","content":"Verdict: **PASS**\nIt declines."}}]}'
out=$(judge); code=$?
ok "judge API: a labeled verdict passes" '[ $code -eq 0 ]'

export COUNTER="$tmp/counter"
out=$(./tinyeval -n 3 -o "$tmp/flaky.json" test/fixtures/flaky.sh); code=$?
ok "flaky: 2 of 3 passes" '[ $code -eq 0 ] && [[ $out == *"mostly yes"*"2/3"* ]]'
rm -f "$COUNTER"
out=$(./tinyeval -n 3 -o "$tmp/broken.json" test/fixtures/broken.sh); code=$?
ok "a run that couldn't run doesn't count toward -n" '[ $code -eq 0 ] && [[ $out == *"~ one run broke 1/2, 1 couldn'"'"'t run"* ]] && [[ $out == *"All 1 evals passed"* ]]'
ok "flaky: one entry per run" '[ "$(jqr "[.evals[] | select(.passed)] | length" "$tmp/flaky.json")" -eq 2 ] && [ "$(jqr ".evals | length" "$tmp/flaky.json")" -eq 3 ]'

out=$(./tinyeval -o "$tmp/typo.json" test/fixtures/typo.sh 2>/dev/null); code=$?
ok "a misspelled line fails its test case" '[ $code -eq 1 ] && [[ $out == *"not a tinyeval line: contians"* ]]'
ok "a test case with no grading lines fails" '[[ $out == *"nothing grades this test case"* ]] && [[ $out == *"3 of 4 evals failed"* ]]'
ok "a second test case with a name gets a number and fails" '[[ $out == *"graded #2"*"another test case in this file is named \"graded\""* ]] && jqr -e "[.evals[].key] == [\"misspelled\", \"no lines\", \"graded\", \"graded #2\"]" "$tmp/typo.json" >/dev/null'

out=$(./tinyeval -o "$tmp/loop.json" test/fixtures/loop.sh 2>/dev/null); code=$?
ok "a loop reading into input keeps each test case's own input" '[ $code -eq 0 ] && jqr -e "[.evals[].input] == [\"first\", \"second\"]" "$tmp/loop.json" >/dev/null'

out=$(./tinyeval -o "$tmp/headers.json" test/fixtures/headers.sh 2>/dev/null); code=$?
ok "#tinyeval couldnt_run: the run couldn't run" '[[ $out == *"! rate limited couldn'"'"'t run"* ]] && jqr -e ".evals[0].metadata.couldnt_run == \"429 rate limited\"" "$tmp/headers.json" >/dev/null'
ok "#tinyeval cost_usd: on the test case's own eval only, and not in the graded reply" 'jqr -e "[.evals[1:3][] | .cost_usd] == [0.0000125, null] and .evals[1].output == \"{\\\"answer\\\": 42}\"" "$tmp/headers.json" >/dev/null'
ok "a misspelled #tinyeval line fails" '[ $code -eq 1 ] && [[ $out == *"not a #tinyeval line: cost 1"* ]]'

out=$(./tinyeval -o "$tmp/calls.json" test/fixtures/calls.sh 2>&1); code=$?
ok "calls: kept on every eval of the test case, as written" 'jqr -e "[.evals[0:2][] | .calls | map(.call)] == [[\"classify\", \"answer\"], [\"classify\", \"answer\"]] and .evals[0].calls[1].input == \"x \\\"quoted\\\"\"" "$tmp/calls.json" >/dev/null'
ok "calls: their cost adds up on the test case's own eval" 'jqr -e "[.evals[0:2][] | .cost_usd] == [0.0026, null]" "$tmp/calls.json" >/dev/null'
ok "calls: a failing test case lists them" '[[ $out == *"calls: classify (haiku) → answer (opus)"* ]]'
ok "calls: a pretty-printed call fails, and the results stay JSON" '[ $code -eq 1 ] && [[ $out == *"line 1 of \$TINYEVAL_CALLS isn'"'"'t a JSON object on one line (write each call unindented): {"* ]] && [[ $out != *"line 2 of"*  ]] && jqr -e ".evals[3].calls == null" "$tmp/calls.json" >/dev/null'
ok "calls: none written, none kept" 'jqr -e ".evals[4] | has(\"calls\") | not" "$tmp/calls.json" >/dev/null'
ok "calls: the reply's own cost_usd wins" 'jqr -e ".evals[5].cost_usd == 0.5" "$tmp/calls.json" >/dev/null'
./tinyeval -j 1 -o "$tmp/wcalls.json" test/fixtures/worker_calls.sh >/dev/null 2>&1
ok "calls: a worker's are each test case's own" 'jqr -e "[.evals[].calls | map(.call)] == [[\"one\"], [\"two\"]]" "$tmp/wcalls.json" >/dev/null'
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces OTEL_RESOURCE_ATTRIBUTES=service.name=shop ./tinyeval -n 2 -o "$tmp/otel.json" test/fixtures/otel.sh >/dev/null 2>&1
ok "otel: each run's spans carry its eval's otel id, after the app's own attributes" 'jqr -e "[.evals[] | .output == \"service.name=shop,evalship.eval=\" + .otel] | all" "$tmp/otel.json" >/dev/null'
ok "otel: one id per run of a test case, its checks sharing it" 'jqr -e "[.evals[].otel] | length == 6 and .[0] == .[1] and (unique | length) == 4" "$tmp/otel.json" >/dev/null'
./tinyeval -o "$tmp/nootel.json" test/fixtures/otel.sh >/dev/null 2>&1
ok "otel: no OTLP endpoint, no tag" 'jqr -e "[.evals[] | has(\"otel\")] | any | not" "$tmp/nootel.json" >/dev/null'

out=$(./tinyeval -o "$tmp/noask.json" test/fixtures/noask.sh); code=$?
ok "no ask: fails with a hint" '[ $code -eq 1 ] && [[ $out == *"define ask or worker in test/fixtures/noask.sh"* ]]'

./tinyeval -o "$tmp/x.json" test/fixtures/empty.sh >/dev/null 2>&1; code=$?
ok "no test cases exits 2" '[ $code -eq 2 ]'
./tinyeval -n 0 test/fixtures/basics.sh >/dev/null 2>&1; code=$?
ok "bad -n exits 2" '[ $code -eq 2 ]'
./tinyeval test/fixtures/missing.sh >/dev/null 2>&1; code=$?
ok "missing file exits 2" '[ $code -eq 2 ]'

out=$(./tinyeval -k EQUALS -o "$tmp/k.json" test/fixtures/basics.sh); code=$?
ok "-k runs only matching test cases" '[ $code -eq 0 ] && [[ $out == *"All 1 evals passed"* ]] && [ "$(jqr ".evals[0].key" "$tmp/k.json")" = "\"equals\"" ]'
out=$(./tinyeval -k nothing -o "$tmp/k.json" test/fixtures/basics.sh 2>&1); code=$?
ok "-k with no match exits 2" '[ $code -eq 2 ] && [[ $out == *"no test case name contains \"nothing\""* ]]'

start=$SECONDS
out=$(./tinyeval -t 1 -o "$tmp/slow.json" test/fixtures/slow.sh 2>&1); code=$?
ok "-t stops a slow AI call" '[ $code -eq 1 ] && [[ $out == *"ask took longer than 1s"* ]] && [ $((SECONDS - start)) -lt 5 ]'
ok "-t prints no job notices" '[[ $out != *Terminated* ]] && [[ $out == *"reply: (empty)"* ]]'
out=$(./tinyeval -t 2 -j 4 -o "$tmp/fast.json" test/fixtures/fast.sh 2>&1); code=$?
ok "a fast AI call never waits out -t" '[[ $out != *Terminated* ]] && [ $code -eq 0 ] && [[ $out == *"All 200 evals passed"* ]] && ! grep -qE " ([2-9]|[1-9][0-9]+)\.[0-9]s$" <<<"$out"'

out=$(./tinyeval -j 1 -o "$tmp/worker.json" test/fixtures/worker.sh 2>&1); code=$?
ok "worker: one process answers every input" '[ $code -eq 0 ] && [[ $out == *"All 3 evals passed"* ]]'
out=$(./tinyeval -j 2 -o "$tmp/worker2.json" test/fixtures/worker.sh 2>&1); code=$?
ok "worker: one per -j" '[ $code -eq 1 ] && [ "$(jqr "[.evals[] | select(.passed)] | length" "$tmp/worker2.json")" -eq 1 ]'
start=$SECONDS
out=$(./tinyeval -j 1 -t 2 -o "$tmp/breaks.json" test/fixtures/worker_breaks.sh 2>&1); code=$?
ok "worker: a crash couldn't run, with its stderr" '[[ $out == *"the worker stopped: out of memory"* ]]'
ok "worker: a hang stops at -t" '[[ $out == *"the worker took longer than 2s"* ]] && [ $((SECONDS - start)) -lt 10 ]'
ok "worker: a new one after each" '[ $code -eq 1 ] && [[ $out == *"2 of 4 evals couldn'"'"'t run"* ]] && jqr -e "[.evals[] | select(.passed) | .key] == [\"after a crash\", \"after a hang\"]" "$tmp/breaks.json" >/dev/null'

out=$(PATH="$(dirname "$real_jq"):$PATH" ./tinyeval -o "$tmp/json.json" test/fixtures/json.sh 2>&1); code=$?
ok "json: passes and fails on the filter" '[ $code -eq 1 ] && [[ $out == *"1 of 2 evals failed"* ]] && [[ $out == *"json: .category == \"transfer\" is false"* ]]'
out=$(PATH="$(dirname "$real_jq"):$PATH" ./tinyeval -o "$tmp/notjson.json" test/fixtures/notjson.sh 2>&1); code=$?
ok "json: a reply that isn't JSON fails" '[ $code -eq 1 ] && [[ $out == *"1 of 1 evals failed"* ]] && [[ $out == *"json: "* ]]'
out=$(PATH="$(dirname "$real_jq"):$PATH" ./tinyeval -o "$tmp/problems.json" test/fixtures/problems.sh 2>&1); code=$?
ok "problems: an empty list passes, each item fails" '[ $code -eq 1 ] && [[ $out == *"4 of 5 evals failed"* ]] && jqr -e ".evals[1].failure == \"tweet 2 has a hashtag\nquotes \$59, not an input price\" and .evals[2].failure == \"description is empty\"" "$tmp/problems.json" >/dev/null'
ok "problems: a misspelled field or a reply that isn't JSON fails" '[[ $out == *"problems: .problem is null, not a list"* ]] && jqr -e ".evals[4].failure | startswith(\"problems: \")" "$tmp/problems.json" >/dev/null'
out=$(./tinyeval -o "$tmp/checks.json" -x "$tmp/checks.xml" test/fixtures/checks.sh 2>&1); code=$?
ok "check: one reply, an eval per check" '[ $code -eq 1 ] && [ "$(jqr -c "[.evals[] | [.key, .passed]]" "$tmp/checks.json")" = "[[\"braise\",true],[\"braise / servings\",true],[\"braise / units\",false],[\"only checks / coverage\",true],[\"only checks / nothing\",false],[\"down\",false],[\"down / servings\",false]]" ]'
ok "check: a check with no lines fails, and an AI call that broke can't run any" '[[ $out == *"2 of 7 evals failed, 2 couldn'"'"'t run"* ]] && [[ $out == *"nothing grades this check"* ]] && jqr -e "[.evals[] | select(.metadata.couldnt_run) | .key] == [\"down\", \"down / servings\"]" "$tmp/checks.json" >/dev/null'
ok "check: a testcase each in JUnit" '[ "$(grep -c "<testcase " "$tmp/checks.xml")" -eq 7 ] && grep -q "name=\"braise / units\"" "$tmp/checks.xml"'
out=$(./tinyeval -n 3 -o "$tmp/checks3.json" test/fixtures/checks.sh 2>&1)
ok "check: -n 3 gives each check 3 runs" '[ "$(jqr "[.evals[] | select(.key | startswith(\"braise\"))] | length" "$tmp/checks3.json")" -eq 9 ] && [[ $out == *"✗ units 0/3"* ]]'
ok "target: kept in the results file"'jqr -e ".evals[0].targets == [\"app/bot.rb#reply\", \"src/tags.ts#generateTags\"] and .evals[1].targets == null" "$tmp/problems.json" >/dev/null'

out=$(./tinyeval -o "$tmp/x.json" -x "$tmp/junit.xml" test/fixtures/basics.sh test/fixtures/failing.sh 2>&1)
ok "-x: JUnit XML with a testsuite per file" '[ "$(grep -c "<testsuite " "$tmp/junit.xml")" -eq 2 ] && [ "$(grep -c "<testcase " "$tmp/junit.xml")" -eq "$(jqr ".evals | length" "$tmp/x.json")" ]'
ok "-x: failures and couldn't run" 'grep -q "<failure message=" "$tmp/junit.xml" && grep -q "<error message=" "$tmp/junit.xml" && grep -q "<testsuites tests=" "$tmp/junit.xml"'
GITHUB_STEP_SUMMARY="$tmp/markup.md" ./tinyeval -o "$tmp/m.json" -x "$tmp/markup.xml" test/fixtures/markup.sh >/dev/null 2>&1
ok "-x and job summary: escaped (bash 5.2 reads & in a replacement as the match)" 'grep -qF "name=\"x &amp; &lt;y&gt; &quot;z&quot; | w\"" "$tmp/markup.xml" && grep -qF "x & &lt;y> \"z\" \\| w" "$tmp/markup.md"'
# On stdin, as Git Bash's xmllint is a Windows program that can't open /tmp paths.
if command -v xmllint >/dev/null; then ok "-x: well-formed" 'xmllint --noout - <"$tmp/junit.xml"'; fi

start=$SECONDS
./tinyeval -o "$tmp/long.json" -x "$tmp/long.xml" test/fixtures/long.sh >/dev/null 2>&1; code=$?
(i=0; while [ $i -lt 1000 ]; do printf 'line %s: naïve 日本語 "q" back\\slash\ttab <b>&amp;</b>\n' $i; i=$((i + 1)); done) >"$tmp/long.want"
jqr -r '.evals[0].input' "$tmp/long.json" | tr -d '\r' >"$tmp/long.input"
ok "a long input and reply: escaped in seconds, exactly" '[ $code -eq 1 ] && [ $((SECONDS - start)) -lt 10 ] && cmp -s "$tmp/long.input" "$tmp/long.want" && jqr -e ".evals[0].output == .evals[0].input" "$tmp/long.json" >/dev/null'
ok "a long failure: escaped in the JUnit file" 'grep -qF "naïve 日本語 &quot;q&quot; back\\slash" "$tmp/long.xml" && ! grep -qF "<b>" "$tmp/long.xml"'
if command -v xmllint >/dev/null; then ok "a long failure: the JUnit file is well-formed" 'xmllint --noout - <"$tmp/long.xml"'; fi

out=$(GITHUB_STEP_SUMMARY="$tmp/summary.md" ./tinyeval -o "$tmp/s.json" test/fixtures/failing.sh 2>&1)
ok "job summary: heading and a row per failing test case" 'grep -q "^### tinyeval: " "$tmp/summary.md" && [ "$(grep -cE "^\| (✗|!) \|" "$tmp/summary.md")" -ge 2 ]'
GITHUB_STEP_SUMMARY="$tmp/summary2.md" ./tinyeval -o "$tmp/s2.json" test/fixtures/basics.sh >/dev/null 2>&1
ok "job summary: one line when all pass" '[ "$(cat "$tmp/summary2.md")" = "### tinyeval: All 6 evals passed" ]'

start=$SECONDS
out=$(./tinyeval -j 4 -t 291 -o "$tmp/par.json" test/fixtures/parallel.sh); code=$?
ok "-j 4 runs four 1s test cases at once" '[ $code -eq 0 ] && [ $((SECONDS - start)) -lt 3 ]'
if command -v pgrep >/dev/null; then ok "finished AI calls leave no timer running" '! pgrep -f "sleep 291" >/dev/null'; fi
ok "-j keeps file order" '[[ $out == *one*two*three*four* ]] && [ "$(jqr -r "[.evals[].key] | join(\",\")" "$tmp/par.json" | tr -d "\r")" = "one,two,three,four" ]'

# TERM (what Ctrl-C becomes) stops tinyeval and the AI calls it started. set -m gives it its own process group.
set -m
./tinyeval -o "$tmp/hang.json" test/fixtures/hang.sh >/dev/null 2>&1 &
pid=$!
set +m
sleep 1
start=$SECONDS
kill -TERM "$pid"
wait "$pid"; code=$?
ok "TERM exits 130 right away" '[ $code -eq 130 ] && [ $((SECONDS - start)) -lt 3 ]'
sleep 1
if command -v pgrep >/dev/null; then ok "TERM stops running AI calls" '! pgrep -f "sleep 37" >/dev/null'; fi

# A previous run where both test cases passed: line 2 of the file is its first eval.
sed -e '2,3s/"passed":false/"passed":true/' -e '3s/,"metadata":{[^}]*}//' "$tmp/failing.json" >"$tmp/prev.json"
out=$(./tinyeval -o "$tmp/prev.json" test/fixtures/failing.sh)
ok "since last run: names the new failure" '[[ $out == *"Since the last run"*"failing › wrong reply fails now"* ]]'
ok "since last run: a test case that couldn't run isn't a new failure" '[[ $out != *"ask fails fails now"* ]]'

version=$(sed -n 's/^_te_version=//p' tinyeval)
# The latest release, faked with a file: a copy of tinyeval that says it's 9.9.9.
sed 's/^_te_version=.*/_te_version=9.9.9/' tinyeval >"$tmp/release"
printf '<html>Not Found</html>\n' >"$tmp/broken"

mkdir "$tmp/repo" && printf '#!/usr/bin/env bash\necho "repo copy $*${TINYEVAL_PACKAGE_UPDATE+ from a package}"\n' >"$tmp/repo/tinyeval" && chmod +x "$tmp/repo/tinyeval"
here=$PWD
out=$(cd "$tmp/repo" && "$here/tinyeval" -k x)
ok "on PATH: runs the repo's ./tinyeval" '[ "$out" = "repo copy -k x" ]'
out=$(cd "$tmp/repo" && TINYEVAL_PACKAGE_UPDATE="gem update tinyeval" "$here/tinyeval" -k x)
ok "on PATH: a package's copy runs the repo's ./tinyeval as the repo's own" '[ "$out" = "repo copy -k x" ]'

mkdir "$tmp/up" && cp tinyeval "$tmp/up/tinyeval"
out=$(cd "$tmp/up" && TINYEVAL_DOWNLOAD_URL=$(furl "$tmp/release") ./tinyeval update); code=$?
ok "update: installs a newer release" '[ $code -eq 0 ] && [[ $out == *"from $version to 9.9.9"* ]] && [ "$(cd "$tmp/up" && ./tinyeval -v)" = "tinyeval 9.9.9" ]'
out=$(cd "$tmp/up" && TINYEVAL_DOWNLOAD_URL=$(furl "$tmp/release") ./tinyeval update); code=$?
ok "update: says when it's the latest" '[ $code -eq 0 ] && [[ $out == *"9.9.9 is the latest version"* ]]'
cp tinyeval "$tmp/up/tinyeval"
(cd "$tmp/up" && TINYEVAL_DOWNLOAD_URL=$(furl "$tmp/broken") ./tinyeval update >/dev/null 2>&1); code=$?
ok "update: keeps the file when the download isn't tinyeval" '[ $code -eq 2 ] && cmp -s tinyeval "$tmp/up/tinyeval" && [ ! -e "$tmp/up/tinyeval.download" ]'
out=$(cd "$tmp/up" && TINYEVAL_PACKAGE_UPDATE="bundle update tinyeval" TINYEVAL_DOWNLOAD_URL=$(furl "$tmp/release") ./tinyeval update 2>&1); code=$?
ok "update: a package's copy says to update through its package manager" '[ $code -eq 2 ] && [[ $out == *"Update it with: bundle update tinyeval" ]] && cmp -s tinyeval "$tmp/up/tinyeval"'

# A fake curl answers for evalship.com as its share API does: the body, then -w's status code.
mkdir "$tmp/fakecurl" && cat >"$tmp/fakecurl/curl" <<'SH' && chmod +x "$tmp/fakecurl/curl"
#!/usr/bin/env bash
printf '%s\n' "$@" >"$SHARE_ARGS"
printf '%s\n\n%s' "$SHARE_BODY" "$SHARE_CODE"
SH
share() { PATH="$tmp/fakecurl:$PATH" SHARE_ARGS="$tmp/share.args" ./tinyeval share "$@"; }
summary="$tmp/share-summary.md"
out=$(GITHUB_STEP_SUMMARY=$summary SHARE_CODE=201 SHARE_BODY=$'Shared 6 evals: https://evalship.com/r/abc\nAnyone with the link can see them.' share "$tmp/basics.json"); code=$?
ok "share: prints the link" '[ $code -eq 0 ] && [ "$out" = "$(printf "Shared 6 evals: https://evalship.com/r/abc\nAnyone with the link can see them.")" ]'
ok "share: sends the file as tinyeval" 'grep -qx "@$tmp/basics.json" "$tmp/share.args" && grep -qx "tinyeval/$version" "$tmp/share.args" && grep -qx "https://evalship.com/api/v1/shares" "$tmp/share.args"'
ok "share: links them in the job summary" 'grep -qx "Shared results: https://evalship.com/r/abc" "$summary"'
out=$(SHARE_CODE=429 SHARE_BODY="Retry later" share "$tmp/basics.json" 2>&1); code=$?
ok "share: says why it couldn't" '[ $code -eq 2 ] && [ "$out" = "tinyeval: couldn'"'"'t share $tmp/basics.json: Retry later" ]'
out=$(cd "$tmp" && "$here/tinyeval" share 2>&1); code=$?
ok "share: needs a results file" '[ $code -eq 2 ] && [[ $out == *"no eval-results.json to share"* ]]'

# The update check runs only in a terminal, which script gives. Git Bash has no script.
tty_run() { if [ "$(uname)" = Darwin ]; then script -q /dev/null "$@"; else script -qc "$(printf '%q ' "$@")" /dev/null; fi </dev/null; }
if command -v script >/dev/null && ! command -v cygpath >/dev/null; then
  tty_run env CI= TINYEVAL_DOWNLOAD_URL="$(furl "$tmp/release")" ./tinyeval -o "$tmp/tty.json" test/fixtures/basics.sh >/dev/null
  sleep 1
  ok "update check: saves the latest version" '[ "$(cat "$tmp/cache/tinyeval/latest" 2>/dev/null)" = 9.9.9 ]'
  out=$(tty_run env CI= TINYEVAL_DOWNLOAD_URL="$(furl "$tmp/release")" ./tinyeval -o "$tmp/tty.json" test/fixtures/basics.sh)
  ok "update check: the next run names the release" '[[ $out == *"tinyeval 9.9.9 is out. Run ./tinyeval update"* ]]'
  rm -rf "$tmp/cache"
  tty_run env CI=true TINYEVAL_DOWNLOAD_URL="$(furl "$tmp/release")" ./tinyeval -o "$tmp/tty.json" test/fixtures/basics.sh >/dev/null
  sleep 1
  ok "update check: never in CI" '[ ! -e "$tmp/cache/tinyeval" ]'
fi

GITHUB_STEP_SUMMARY="$tmp/summary3.md" TINYEVAL_DOWNLOAD_URL="$(furl "$tmp/release")" ./tinyeval -o "$tmp/s3.json" test/fixtures/basics.sh >/dev/null 2>&1
ok "update check: the GitHub Actions job summary names the release" 'grep -qF "tinyeval 9.9.9 is out. Run ./tinyeval update and commit it." "$tmp/summary3.md"'
GITHUB_STEP_SUMMARY="$tmp/summary5.md" TINYEVAL_PACKAGE_UPDATE="npm update tinyeval" TINYEVAL_DOWNLOAD_URL="$(furl "$tmp/release")" ./tinyeval -o "$tmp/s5.json" test/fixtures/basics.sh >/dev/null 2>&1
ok "update check: a package's job summary names its update command" 'grep -qxF "tinyeval 9.9.9 is out. Run npm update tinyeval." "$tmp/summary5.md"'
GITHUB_STEP_SUMMARY="$tmp/summary4.md" TINYEVAL_DOWNLOAD_URL="$(furl "$tmp/broken")" ./tinyeval -o "$tmp/s4.json" test/fixtures/basics.sh >/dev/null 2>&1
ok "update check: nothing in the job summary when the download fails" '[ "$(cat "$tmp/summary4.md")" = "### tinyeval: All 6 evals passed" ]'

ok "plugin: the skill pins its runner and pages (packages/plugin/pin.sh)" '! grep -rqE "releases/latest|tinyeval update|curl -fsSL https" plugin'

[ $fails -eq 0 ] && echo "all tests passed" || { echo "$fails failed"; exit 1; }
