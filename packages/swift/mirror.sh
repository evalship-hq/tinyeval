#!/usr/bin/env bash
# Pushes the package to the repo SwiftPM and the Swift Package Index read, and tags it: this folder at its root, with
# the runner as the command's resource and LICENSE from the repo root. SwiftPM reads v0.11.0 and 0.11.0 alike; the
# tag is 0.11.0, as Swift packages tag. A tag the mirror has already is skipped, so a re-run of the release passes.
# Usage: mirror.sh REMOTE vX.Y.Z
set -euo pipefail
remote=$1 tag=$2
pkg=$(cd "$(dirname "$0")" && pwd)
root=$pkg/../..
version=$(sed -n 's/^_te_version=//p' "$root/tinyeval")
[ "$tag" = "v$version" ] || { echo "$tag isn't the runner's version, v$version" >&2; exit 1; }
if git ls-remote --exit-code --tags "$remote" "refs/tags/$version" >/dev/null; then
  echo "The mirror has $version already"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone -q "$remote" "$tmp/mirror"
cd "$tmp/mirror"
git rm -rq --ignore-unmatch .
cp -R "$pkg"/{Package.swift,README.md,Sources,Tests} "$root/LICENSE" .
cp "$root/tinyeval" Sources/TinyevalCommand/
git add -A
git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -q --allow-empty -m "tinyeval $version" -m "From packages/swift in https://github.com/evalship-hq/tinyeval"
git tag "$version"
git push -q --atomic origin HEAD:refs/heads/main "refs/tags/$version"
echo "Pushed $version to the mirror"
