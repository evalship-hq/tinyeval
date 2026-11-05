#!/bin/sh
# Adds tinyeval to the repo you run it in: curl -fsSL https://tinyeval.com/install.sh | sh
# Downloads ./tinyeval, starts evals/ with an example, and keeps eval-results.json out of git. Nothing else.
set -eu
version=${TINYEVAL_VERSION:-v0.2.0}

curl -fsSL "https://raw.githubusercontent.com/evalship-hq/tinyeval/$version/tinyeval" -o tinyeval.download
mv tinyeval.download tinyeval
chmod +x tinyeval
echo "Added ./tinyeval ($version). Commit it with your code."

if [ ! -d evals ]; then
  mkdir evals
  cat >evals/example.sh <<'EVAL'
# Your first suite. Replace ask with your AI call: it gets the input as $1 and on stdin,
# and prints the reply. Python, Ruby, Go, Rust and HTTP examples:
# https://github.com/evalship-hq/tinyeval#writing-evals
ask() { echo "Hello! You said: $1"; }

test_case "greets back" "Hi there"
  contains "hello"
EVAL
  echo "Added evals/example.sh"
fi

if [ -d .git ] && ! grep -qx 'eval-results.json' .gitignore 2>/dev/null; then
  # A .gitignore without a final newline would glue the entry onto its last line.
  if [ -s .gitignore ] && [ -n "$(tail -c 1 .gitignore)" ]; then echo >>.gitignore; fi
  echo eval-results.json >>.gitignore
  echo "Added eval-results.json to .gitignore"
fi

command -v bash >/dev/null || echo "tinyeval runs on bash, which this machine doesn't have. On Alpine: apk add bash"
echo
echo "Run ./tinyeval, then replace ask in evals/example.sh with your AI call."
echo "Or have your coding agent do it: Set up evals with https://tinyeval.com/setup.md"
