#!/usr/bin/env bash
# Pins the skill in plugin/ to a release, e.g. packages/plugin/pin.sh v0.11.0 after tagging it. The skill then downloads
# that runner and checks its checksum, and carries a copy of setup.md and migrate.md, so it follows nothing that changes
# after a directory reviewed it (buildwithclaude's rule). Run it at the tag, so the pages match the runner, and commit
# what it changes. It lives outside plugin/,
# since the Claude directory takes no scripts in a plugin.
set -euo pipefail
cd "$(dirname "$0")/../.."
tag=$1 dir=plugin/skills/tinyeval
sum=$(git show "$tag:tinyeval" | shasum -a 256 | cut -d' ' -f1)
get="releases/download/$tag/tinyeval \&\& echo \"$sum  tinyeval\" | shasum -a 256 -c"
for f in setup.md migrate.md; do
  sed -E \
    -e '/^If what you.re reading is a summary/,/^$/d' \
    -e "s#releases/latest/download/tinyeval#$get#" \
    -e 's#`curl -fsSL https://raw.githubusercontent.com/evalship-hq/tinyeval/main/migrate.md`#[migrate.md](migrate.md)#' \
    -e 's#\(https://tinyeval.com/setup.md\)#(setup.md)#' \
    -e "s#\]\(examples/#](https://github.com/evalship-hq/tinyeval/tree/$tag/examples/#" \
    -e '/`\.\/tinyeval update`/d' "$f" >"$dir/$f"
done
sed -E "s#releases/download/v[0-9.]+/tinyeval && echo \"[0-9a-f]+  tinyeval\" \| shasum -a 256 -c#$get#" "$dir/SKILL.md" >"$dir/SKILL.md.new"
mv "$dir/SKILL.md.new" "$dir/SKILL.md"
sed -E "s#\"version\": \"[^\"]*\"#\"version\": \"${tag#v}\"#" plugin/.claude-plugin/plugin.json >plugin/.claude-plugin/plugin.json.new
mv plugin/.claude-plugin/plugin.json.new plugin/.claude-plugin/plugin.json
if grep -rnE 'releases/latest|tinyeval update|curl -fsSL https|\]\(https://tinyeval' plugin; then
  echo "pin.sh: the lines above still fetch or update a moving target; make its sed match them" >&2
  exit 1
fi
