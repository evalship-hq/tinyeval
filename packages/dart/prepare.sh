#!/usr/bin/env bash
# Copies the repo's tinyeval and LICENSE into the package, and gives pubspec.yaml tinyeval's _te_version.
# Run it before dart tests or publishes the package.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p lib/src
cp ../../tinyeval lib/src/tinyeval
cp ../../LICENSE .
version=$(sed -n 's/^_te_version=//p' lib/src/tinyeval)
sed "s/^version: .*/version: $version/" pubspec.yaml >pubspec.yaml.new
mv pubspec.yaml.new pubspec.yaml
# pub.dev wants a changelog that names this version.
printf '## %s\n\n[Release notes](https://github.com/evalship-hq/tinyeval/releases/tag/v%s)\n' "$version" "$version" >CHANGELOG.md
