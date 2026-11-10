#!/usr/bin/env bash
# Copies the repo's tinyeval to inst/tinyeval and writes its version into DESCRIPTION. Run it before R builds or checks
# the package. Main keeps no copy: a release commits it on the r-universe branch, which R-universe builds.
set -euo pipefail
cd "$(dirname "$0")"
version=$(sed -n 's/^_te_version=//p' ../../tinyeval)
mkdir -p inst
cp ../../tinyeval inst/tinyeval
sed -i.bak "s/^Version: .*/Version: $version/" DESCRIPTION && rm DESCRIPTION.bak
