#!/usr/bin/env bash
# Tags the module in a scratch git repo the way a release does, so go fetches it as it would from GitHub. Then, in an
# empty module, installs the tinyeval command with go get -tool and runs packages/e2e.sh with a worker on the helper.
set -euo pipefail
cd "$(dirname "$0")"
here=$PWD
./prepare.sh
version=$(sed -n 's/^_te_version=//p' cmd/tinyeval/tinyeval)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
native() { if command -v cygpath >/dev/null; then cygpath -m "$1"; else echo "$1"; fi; } # Git Bash: go wants C:/ paths

# The release's tag: go/ with the runner and LICENSE that main's .gitignore leaves out.
mkdir "$tmp/repo" && cp -R . "$tmp/repo/go" && cd "$tmp/repo"
git init -q && git add . && git add -f go/LICENSE go/cmd/tinyeval/tinyeval
git -c user.name=e2e -c user.email=e2e@localhost commit -qm "tinyeval $version" && git tag "go/v$version"

# go reads the module from that repo instead of GitHub, into a module cache of its own.
export GOMODCACHE="$(native "$tmp/mod")" GOFLAGS=-modcacherw GOPRIVATE=github.com/evalship-hq/tinyeval GOWORK=off
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$(native "$tmp/repo").insteadOf" GIT_CONFIG_VALUE_0=https://github.com/evalship-hq/tinyeval

mkdir "$tmp/app" && cd "$tmp/app"
go mod init example.com/app 2>/dev/null
go get -tool "github.com/evalship-hq/tinyeval/go/cmd/tinyeval@v$version"
grep -q "github.com/evalship-hq/tinyeval/go v$version" go.mod || { cat go.mod >&2; exit 1; }
mkdir -p evals cmd/worker && cp "$here/../packages/e2e.sh" evals/
cat >cmd/worker/main.go <<'GO'
package main

import (
	"errors"
	"fmt"

	"github.com/evalship-hq/tinyeval/go"
)

type app struct{}

func load() app {
	fmt.Println("app loaded")
	return app{}
}

func (app) call(input string) (string, error) {
	fmt.Println("app called")
	if input == "crash" {
		return "", errors.New("boom")
	}
	return "You said: " + input, nil
}

func main() {
	tinyeval.Worker(load().call)
}
GO
worker=$PWD/worker$(go env GOEXE)
go build -o "$worker" ./cmd/worker
E2E_WORKER=$worker go tool tinyeval

[ "$(go tool tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $(go tool tinyeval -v)" >&2; exit 1; }
status=0 && said=$(go tool tinyeval update 2>&1) || status=$?
[ "$status" = 2 ] && [[ $said == *"go get -tool github.com/evalship-hq/tinyeval/go/cmd/tinyeval@latest"* ]] ||
  { echo "tinyeval update exited $status: $said" >&2; exit 1; }
cd "$tmp" && said=$(go run "github.com/evalship-hq/tinyeval/go/cmd/tinyeval@v$version" -v)
[ "$said" = "tinyeval $version" ] || { echo "go run ...@v$version -v printed $said" >&2; exit 1; }
echo "e2e: ok"
