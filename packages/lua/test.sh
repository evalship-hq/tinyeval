#!/usr/bin/env bash
# The rock's tests (packages/SPEC.md, Tests): writes tinyeval-X.Y.Z-1.rockspec, runs the helper's unit tests, then
# installs the rock with luarocks make into an empty project's tree and runs packages/e2e.sh through its tinyeval
# command. The release job uploads the rockspec it leaves here.
set -euo pipefail
cd "$(dirname "$0")"
version=$(sed -n 's/^_te_version=//p' ../../tinyeval)
rockspec=tinyeval-$version-1.rockspec
rm -f tinyeval-*.rockspec
sed "s/@VERSION@/$version/g" tinyeval.rockspec.in >"$rockspec"
luarocks lint "$rockspec"
lua=$(luarocks config variables.LUA)
"$lua" test/worker_test.lua

project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
# From the repo root, as luarocks install builds from a checkout of the tag.
(cd ../.. && luarocks --tree "$project/lua_modules" make "packages/lua/$rockspec" >/dev/null)
mkdir "$project/evals"
cp ../e2e.sh "$project/evals/"
cat >"$project/evals/worker.lua" <<'LUA'
local tinyeval = require("tinyeval")
print("app loaded")
tinyeval.worker(function(input)
  print("app called")
  if input == "crash" then error("boom") end
  return "You said: " .. input
end)
LUA
cd "$project"
[ "$(lua_modules/bin/tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v doesn't print $version" >&2; exit 1; }
code=0 && out=$(lua_modules/bin/tinyeval update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $out == *"luarocks install --tree lua_modules tinyeval"* ]] || { echo "tinyeval update: exit $code, $out" >&2; exit 1; }
E2E_WORKER="$lua evals/worker.lua" lua_modules/bin/tinyeval
