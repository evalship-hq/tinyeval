#!/usr/bin/env bash
# Runs each worker in examples/workers through tinyeval, for every language whose toolchain is on PATH.
# With REQUIRE_ALL=1, as CI runs it, a missing toolchain fails.
cd "$(dirname "$0")/.." || exit 1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
w=examples/workers
fails=0

# The 50 KB input repeats multi-byte characters, so a worker's reads split some of them.
big=$(i=0; while [ $i -lt 2000 ]; do printf 'line %s: naïve 日本語 ✓\n' $i; i=$((i + 1)); done)
printf '%s' "$big" >"$tmp/big.in"
printf 'You said: %s' "$big" >"$tmp/big.reply"
cat >"$tmp/cases.sh" <<EOF
test_case "hello" "hello"
  equals "You said: hello"
test_case "two lines" "one
two"
  equals "You said: one
two"
test_case "UTF-8" "naïve 日本語 ✓"
  equals "You said: naïve 日本語 ✓"
test_case "50 KB" "\$(cat "$tmp/big.in")"
  expect cmp - "$tmp/big.reply"
EOF

# check LANGUAGE "TOOL ARGS" "COMMAND" ["BUILD"]: TOOL ARGS succeeds when the toolchain is there.
check() {
  local lang=$1 tool=$2 cmd=$3 build=$4 out
  if ! $tool >/dev/null 2>&1; then
    if [ -n "$REQUIRE_ALL" ]; then echo "FAIL $lang (no ${tool%% *})"; fails=$((fails + 1)); else echo "skip $lang (no ${tool%% *})"; fi
    return
  fi
  if [ -n "$build" ] && ! out=$(eval "$build" 2>&1); then
    printf 'FAIL %s (build)\n%s\n' "$lang" "$out"; fails=$((fails + 1)); return
  fi
  { echo "worker $cmd"; cat "$tmp/cases.sh"; } >"$tmp/workers.sh"
  if out=$(./tinyeval -j 2 -t 60 -o "$tmp/x.json" "$tmp/workers.sh" 2>&1); then
    echo "ok   $lang"
  else
    printf 'FAIL %s\n%s\n' "$lang" "$out"; fails=$((fails + 1))
  fi
}

check Ruby "ruby -v" "ruby $w/worker.rb"
check Python "python3 -V" "python3 $w/worker.py"
check "JavaScript (Node)" "node -v" "node $w/worker.mjs"
check "JavaScript (Bun)" "bun -v" "bun $w/worker.mjs"
check Go "go version" "go run $w/worker.go"
check Rust "rustc -V" "$tmp/rust" "rustc --edition 2021 -o $tmp/rust $w/worker.rs"
check PHP "php -v" "php $w/worker.php"
check Java "java -version" "java $w/Worker.java"
check Kotlin "kotlinc -version" "java -jar $tmp/kotlin.jar" "kotlinc $w/worker.kt -include-runtime -d $tmp/kotlin.jar"
# The first run builds; two at once would build into the same place.
check "C#" "dotnet --version" "dotnet run $w/worker.cs" "dotnet run $w/worker.cs </dev/null"
check Elixir "elixir -v" "elixir $w/worker.exs"
check Swift "swift --version" "swift $w/worker.swift"
check Dart "dart --version" "dart run $w/worker.dart"
check Perl "perl -v" "perl $w/worker.pl"
check Lua "lua -v" "lua $w/worker.lua"

[ $fails -eq 0 ]
