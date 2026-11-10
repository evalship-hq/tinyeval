#!/usr/bin/env bash
# Writes the tag's source tarball, its URL and sha256, into tinyeval.rb, and pushes it to the tap as
# Formula/tinyeval.rb, with README.md. A tap with this version or a newer one is skipped, so a re-run of the release
# passes. Usage: tap.sh REMOTE vX.Y.Z [TARBALL]. The tests pass a local TARBALL, for a tag GitHub doesn't have yet.
set -euo pipefail
remote=$1 tag=$2 tarball=${3-}
pkg=$(cd "$(dirname "$0")" && pwd)
version=$(sed -n 's/^_te_version=//p' "$pkg/../../tinyeval")
[ "$tag" = "v$version" ] || { echo "$tag isn't the runner's version, v$version" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone -q "$remote" "$tmp/tap"
cd "$tmp/tap"
have=$(sed -n 's|^  url ".*/v\([0-9.]*\)\.tar\.gz"$|\1|p' Formula/tinyeval.rb 2>/dev/null || true)
if [ -n "$have" ] && [ "$(printf '%s\n' "$version" "$have" | sort -V | tail -n1)" = "$have" ]; then
  echo "The tap has tinyeval $have already"
  exit 0
fi

if [ -n "$tarball" ]; then
  url=file://$tarball
else
  url=https://github.com/evalship-hq/tinyeval/archive/refs/tags/$tag.tar.gz
  tarball=$tmp/$tag.tar.gz
  curl -fsSL -o "$tarball" "$url"
fi
sha=$(shasum -a 256 "$tarball" | cut -d' ' -f1)
mkdir -p Formula
sed -e "s|@URL@|$url|" -e "s|@SHA256@|$sha|" "$pkg/tinyeval.rb" >Formula/tinyeval.rb
cp "$pkg/README.md" .
git add -A
git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit -q -m "tinyeval $version" -m "From packages/homebrew in https://github.com/evalship-hq/tinyeval"
git push -q origin HEAD:refs/heads/main
echo "Pushed tinyeval $version to the tap"
