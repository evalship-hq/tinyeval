#!/usr/bin/env bash
# Pushes the package to a local mirror as the release job does, installs it from there into an empty Composer
# project, as Packagist would, and runs packages/e2e.sh with vendor/bin/tinyeval (packages/SPEC.md, Tests).
set -euo pipefail
pkg=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
version=$(sed -n 's/^_te_version=//p' "$pkg/../../tinyeval")

git init -q --bare "$tmp/mirror.git"
"$pkg/mirror.sh" "$tmp/mirror.git" "v$version"
[[ $("$pkg/mirror.sh" "$tmp/mirror.git" "v$version") == *"has v$version already"* ]] || { echo "a second push didn't skip" >&2; exit 1; }

mkdir -p "$tmp/app/evals"
cd "$tmp/app"
url=$(cygpath -m "$tmp/mirror.git" 2>/dev/null || echo "$tmp/mirror.git") # a path php.exe reads, on Git Bash
printf '{"repositories": [{"type": "vcs", "url": "%s"}, {"packagist.org": false}]}\n' "$url" >composer.json
composer require --quiet --no-interaction --dev "evalship/tinyeval:$version"
cp "$pkg/../e2e.sh" evals/
cat >app.php <<'PHP'
<?php
echo "app loaded\n";

function answer(string $input): string
{
    echo "app called\n";
    if ($input === 'crash') {
        throw new RuntimeException('boom');
    }
    return "You said: $input";
}
PHP
cat >evals/worker.php <<'PHP'
<?php
require __DIR__ . '/../vendor/evalship/tinyeval/worker.php';
require __DIR__ . '/../vendor/autoload.php';
require __DIR__ . '/../app.php';

Tinyeval\worker('answer');
PHP

E2E_WORKER="php evals/worker.php" vendor/bin/tinyeval
[ "$(vendor/bin/tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $(vendor/bin/tinyeval -v)" >&2; exit 1; }
code=0 && said=$(vendor/bin/tinyeval update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $said == *"composer update evalship/tinyeval"* ]] || { echo "tinyeval update exited $code: $said" >&2; exit 1; }
echo "end to end: ok"
