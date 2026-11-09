#!/bin/sh
# Runs the tinyeval skill's tests on your Claude subscription: whether it fires on prompt and model changes, and what the
# agent does then. They live outside plugin/, since the Claude directory takes no scripts in a plugin from an unverified
# organization, so this runs a copy of the plugin with them inside. Arguments go on to claude plugin eval, e.g.
# test/plugin/run.sh --case model-switch --runs 1
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/plugin" "$tmp/plugin"
cp -R "$root/test/plugin" "$tmp/plugin/evals"
rm -rf "$tmp/plugin/evals/results"
cp "$root/tinyeval" "$tmp/tinyeval" # sign-off-with-evals copies the runner from three folders up
status=0
env -u ANTHROPIC_API_KEY claude plugin eval "$tmp/plugin" --eval-dir evals --scaffold --trust-plugin --no-publish --model opus --allow-tools Bash Write Edit "$@" || status=$?
rm -rf "$root/test/plugin/results"
cp -R "$tmp/plugin/evals/results" "$root/test/plugin/results" 2>/dev/null || true
exit $status
