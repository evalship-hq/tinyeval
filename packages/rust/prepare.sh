#!/usr/bin/env bash
# Copies the repo's tinyeval and LICENSE into the crate, and gives Cargo.toml tinyeval's _te_version.
# Run it before cargo builds, tests or packages the crate.
set -euo pipefail
cd "$(dirname "$0")"
cp ../../tinyeval ../../LICENSE .
version=$(sed -n 's/^_te_version=//p' tinyeval)
sed "s/^version = \"[^\"]*\"/version = \"$version\"/" Cargo.toml >Cargo.toml.new
mv Cargo.toml.new Cargo.toml
