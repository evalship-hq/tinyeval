#!/bin/sh
# Adds tinyeval to the repo you run it in: curl -fsSL https://tinyeval.com/install.sh | sh
# Downloads ./tinyeval, starts evals/ with an example, keeps eval-results.json out of git, and puts a
# tinyeval command in ~/.local/bin that runs the repo's ./tinyeval. Nothing else.
set -eu
if [ -n "${TINYEVAL_VERSION-}" ]; then
  url="https://raw.githubusercontent.com/evalship-hq/tinyeval/$TINYEVAL_VERSION/tinyeval"
else
  url=https://github.com/evalship-hq/tinyeval/releases/latest/download/tinyeval
fi

curl -fsSL "$url" -o tinyeval.download
version=$(sed -n 's/^_te_version=//p' tinyeval.download)
[ -n "$version" ] || { rm -f tinyeval.download; echo "install.sh: $url isn't tinyeval" >&2; exit 1; }
mv tinyeval.download tinyeval
chmod +x tinyeval
echo "Added ./tinyeval $version. Commit it with your code."

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

mkdir -p "$HOME/.local/bin"
cp tinyeval "$HOME/.local/bin/tinyeval"
echo "Added the tinyeval command to ~/.local/bin"

command -v bash >/dev/null || echo "tinyeval runs on bash, which this machine doesn't have. On Alpine: apk add bash"
echo
case ":$PATH:" in
  *":$HOME/.local/bin:"*) echo "Run tinyeval, then replace ask in evals/example.sh with your AI call." ;;
  *)
    echo "To type tinyeval, add ~/.local/bin to your PATH in your shell's startup file (~/.zshrc on a Mac):"
    # shellcheck disable=SC2016 # the line to paste, unexpanded
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    echo "Until then, run ./tinyeval. Then replace ask in evals/example.sh with your AI call."
    ;;
esac
echo "Or have your coding agent do it: Set up evals with https://tinyeval.com/setup.md"
