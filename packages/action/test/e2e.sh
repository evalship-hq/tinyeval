#!/usr/bin/env bash
# Pushes the action to a local mirror as the release job does, checks its files and tags, and runs action.yml's step
# by hand from the mirror, as GitHub runs it, in an empty project with packages/e2e.sh (packages/SPEC.md, Tests).
set -euo pipefail
pkg=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
version=$(sed -n 's/^_te_version=//p' "$pkg/../../tinyeval")
fail() { echo "$*" >&2; exit 1; }

git init -q --bare -b main "$tmp/mirror.git" # the branch mirror.sh pushes, whatever init.defaultBranch says
"$pkg/mirror.sh" "$tmp/mirror.git" "v$version"
[[ $("$pkg/mirror.sh" "$tmp/mirror.git" "v$version") == *"has v$version already"* ]] || fail "a second push didn't skip"
# A later release moves v0: pretend this one was the last, and push it again.
git -C "$tmp/mirror.git" tag v0.0.1 "v$version" && git -C "$tmp/mirror.git" tag -d "v$version" >/dev/null
"$pkg/mirror.sh" "$tmp/mirror.git" "v$version" >/dev/null
tags() { git -C "$tmp/mirror.git" rev-parse "$@"; }
[ "$(tags "v$version")" = "$(tags "v${version%%.*}")" ] && [ "$(tags "v$version")" != "$(tags v0.0.1)" ] ||
  fail "v${version%%.*} isn't on v$version"

git clone -q --branch "v$version" "$tmp/mirror.git" "$tmp/action" 2>/dev/null
action=$tmp/action
[ "$(git -C "$action" ls-files | tr '\n' ' ')" = "LICENSE README.md action.yml tinyeval " ] ||
  fail "the mirror has: $(git -C "$action" ls-files | tr '\n' ' ')"
cmp -s "$action/tinyeval" "$pkg/../../tinyeval" || fail "the mirror's tinyeval differs from ./tinyeval"
grep -q "evalship-hq/tinyeval-action@v$version$" "$action/README.md" || fail "the mirror's README doesn't pin v$version"

# Runs action.yml's step: its run line with its env, under GitHub's bash flags.
run=$(sed -n 's/^ *run: //p' "$action/action.yml")
update=$(sed -n 's/^ *TINYEVAL_PACKAGE_UPDATE: //p' "$action/action.yml")
step() {
  GITHUB_ACTION_PATH=$action TINYEVAL_ARGS="$*" TINYEVAL_PACKAGE_UPDATE=$update GITHUB_STEP_SUMMARY=$tmp/summary.md \
    bash --noprofile --norc -eo pipefail -c "$run"
}

mkdir -p "$tmp/app/evals"
cp "$pkg/../e2e.sh" "$tmp/app/evals/"
cd "$tmp/app"
furl() { if command -v cygpath >/dev/null; then echo "file:///$(cygpath -m "$1")"; else echo "file://$1"; fi; }
export TINYEVAL_DOWNLOAD_URL=$(furl "$tmp/no-release") # offline, but for the one check that wants a release
printf '_te_version=9.9.9\n' >"$tmp/release"
E2E_WORKER="perl $pkg/test/worker.pl" TINYEVAL_DOWNLOAD_URL=$(furl "$tmp/release") step
grep -qxF "### tinyeval: All 2 evals passed" "$tmp/summary.md" || fail "job summary: $(cat "$tmp/summary.md")"
grep -qxF "tinyeval 9.9.9 is out. Run the latest evalship-hq/tinyeval-action." "$tmp/summary.md" ||
  fail "job summary: $(cat "$tmp/summary.md")"
[ "$(step -v)" = "tinyeval $version" ] || fail "tinyeval -v printed $(step -v)"
code=0 && said=$(step update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $said == *"Update it with: the latest evalship-hq/tinyeval-action" ]] ||
  fail "tinyeval update exited $code: $said"
said=$(E2E_WORKER="perl $pkg/test/worker.pl" step -k error -o other.json evals/e2e.sh 2>&1) &&
  [[ $said == *"All 1 evals passed (other.json)"* ]] || fail "args didn't pass through: $said"
echo "end to end: ok"
