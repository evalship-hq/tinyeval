#!/usr/bin/env bash
# The formula's tests (packages/SPEC.md, Tests): tap.sh pushes it to a local tap, around a tarball of this checkout
# built the way GitHub builds the tag's. Then brew style, audit, install and test, and packages/e2e.sh through the
# installed tinyeval command. The release job runs this before it pushes to the real tap.
set -euo pipefail
pkg=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$pkg/../.." && pwd)
version=$(sed -n 's/^_te_version=//p' "$root/tinyeval")
tap=tinyeval-test/tap
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_INSTALL_CLEANUP=1
# Homebrew keeps one tinyeval, whichever tap it's from, and the cleanup below would remove it.
if brew list --formula tinyeval >/dev/null 2>&1; then echo "tinyeval is installed already: brew uninstall tinyeval" >&2; exit 1; fi
tmp=$(mktemp -d)
trap 'brew uninstall -q --force "$tap/tinyeval" >/dev/null 2>&1; brew untap -q "$tap" >/dev/null 2>&1; rm -rf "$tmp"' EXIT

# GitHub's tarball is git archive with a tinyeval-X.Y.Z/ prefix. stash create adds uncommitted changes, when there are.
rev=$(git -C "$root" stash create)
git -C "$root" archive --prefix="tinyeval-$version/" -o "$tmp/v$version.tar.gz" "${rev:-HEAD}"
git init -q --bare -b main "$tmp/tap.git" # the branch the tap pushes, whatever init.defaultBranch says
"$pkg/tap.sh" "$tmp/tap.git" "v$version" "$tmp/v$version.tar.gz"
[[ $("$pkg/tap.sh" "$tmp/tap.git" "v$version" "$tmp/v$version.tar.gz") == *"has tinyeval $version already"* ]] ||
  { echo "a second push didn't skip" >&2; exit 1; }

brew tap -q "$tap" "$tmp/tap.git"
brew style "$tap"
brew install -q "$tap/tinyeval" # first: naming the tap's formula is what lets Homebrew 7 load it
brew audit --strict --formula "$tap/tinyeval"
brew test "$tap/tinyeval"

mkdir -p "$tmp/app/evals"
cp "$root/packages/e2e.sh" "$tmp/app/evals/"
# examples/workers/worker.py's loop around the fake app. With no helper, the worker keeps the app's prints off the
# replies itself: fd 1 points at stderr, and the replies go to a copy of the real stdout.
cat >"$tmp/app/evals/worker.py" <<'PY'
import os, sys

replies = os.fdopen(os.dup(1), "wb")
os.dup2(2, 1)
print("app loaded", flush=True)


def reply(input):
    print("app called", flush=True)
    if input == "crash":
        raise RuntimeError("boom")
    return "You said: " + input


rest = b""
while chunk := sys.stdin.buffer.read1():
    *inputs, rest = (rest + chunk).split(b"\0")
    for input in inputs:
        try:
            out = reply(input.decode())
        except Exception as e:
            out = f"{type(e).__name__}: {e}"
        replies.write(out.encode() + b"\0")
        replies.flush()
PY
cd "$tmp/app"
tinyeval=$(brew --prefix)/bin/tinyeval
E2E_WORKER="python3 evals/worker.py" "$tinyeval"
[ "$("$tinyeval" -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $("$tinyeval" -v)" >&2; exit 1; }
code=0 && said=$("$tinyeval" update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $said == *"brew upgrade tinyeval"* ]] || { echo "tinyeval update exited $code: $said" >&2; exit 1; }
echo "end to end: ok"
