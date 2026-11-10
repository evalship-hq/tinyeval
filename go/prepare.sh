#!/usr/bin/env bash
# Copies the repo's tinyeval and LICENSE into the module. Run it before go builds or tests it.
# Main keeps no copy: a release commits these two on the go/vX.Y.Z tag, which is what the Go proxy reads.
set -euo pipefail
cd "$(dirname "$0")"
cp ../tinyeval cmd/tinyeval/tinyeval
cp ../LICENSE LICENSE
