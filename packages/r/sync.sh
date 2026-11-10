#!/usr/bin/env bash
# R-universe builds from git, so the package commits its copy of the runner, inst/tinyeval, and DESCRIPTION's Version.
# This writes both from the repo's tinyeval, and fails when either was behind, so CI and a release catch a version
# bump that missed them. Commit what it changed.
set -euo pipefail
cd "$(dirname "$0")"
version=$(sed -n 's/^_te_version=//p' ../../tinyeval)
behind=
cmp -s ../../tinyeval inst/tinyeval || { cp ../../tinyeval inst/tinyeval && behind=1; }
grep -qx "Version: $version" DESCRIPTION || { sed -i.bak "s/^Version: .*/Version: $version/" DESCRIPTION && rm DESCRIPTION.bak && behind=1; }
[ -z "$behind" ] || { echo "packages/r was behind tinyeval $version: sync.sh updated it, so commit inst/tinyeval and DESCRIPTION" >&2; exit 1; }
