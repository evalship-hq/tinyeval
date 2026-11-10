#!/usr/bin/env bash
# Gives pom.xml and the README's install lines tinyeval's _te_version, so a release changes one line. Run it before
# Maven builds the package.
set -euo pipefail
cd "$(dirname "$0")"
version=$(sed -n 's/^_te_version=//p' ../../tinyeval)
old=$(sed -n 's|.*<version>\([^<]*\)</version><!-- _te_version.*|\1|p' pom.xml)
sed "s|<version>$old</version><!-- _te_version|<version>$version</version><!-- _te_version|" pom.xml >pom.xml.new
sed "s/$old/$version/g" README.md >README.md.new
mv pom.xml.new pom.xml && mv README.md.new README.md
