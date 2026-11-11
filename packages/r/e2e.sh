#!/usr/bin/env bash
# Builds the source package as R-universe does, installs it into an empty project's own library, and runs
# packages/e2e.sh through tinyeval::run(), with a worker on tinyeval::worker() (packages/SPEC.md, Tests).
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
native() { if command -v cygpath >/dev/null; then cygpath -m "$1"; else echo "$1"; fi; } # Git Bash: R wants C:/ paths

(cd "$tmp" && R CMD build --no-manual "$(native "$here")" >/dev/null)
mkdir "$tmp/lib"
R CMD INSTALL --library="$(native "$tmp/lib")" "$(native "$(echo "$tmp"/tinyeval_*.tar.gz)")" >"$tmp/install.log" 2>&1 ||
  { cat "$tmp/install.log" >&2; exit 1; }
version=$(sed -n 's/^Version: //p' DESCRIPTION)
mkdir -p "$tmp/app/evals" && cp ../e2e.sh "$tmp/app/evals/"
cat >"$tmp/app/evals/worker.R" <<'R'
library(tinyeval)
cat("app loaded\n")
worker(function(input) {
  cat("app called\n")
  if (input == "crash") stop("boom")
  paste("You said:", input)
})
R

cd "$tmp/app"
export R_LIBS=$(native "$tmp/lib")
tinyeval() { Rscript -e 'quit(status = tinyeval::run(commandArgs(TRUE)))' "$@"; }
[ "$(tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $(tinyeval -v)" >&2; exit 1; }
code=0 && said=$(tinyeval update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $said == *'install.packages("tinyeval"'* ]] || { echo "tinyeval update exited $code: $said" >&2; exit 1; }
touch renv.lock
said=$(tinyeval update 2>&1 || true)
rm renv.lock
[[ $said == *'"https://evalship-hq.r-universe.dev"); renv::snapshot()'* ]] || { echo "tinyeval update in an renv project said: $said" >&2; exit 1; }
E2E_WORKER="Rscript --vanilla evals/worker.R" tinyeval
echo "e2e: ok"
