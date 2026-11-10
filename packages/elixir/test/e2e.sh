#!/usr/bin/env bash
# End to end (packages/SPEC.md, Tests): the package as Hex ships it, as a dependency of a fresh mix project.
set -euo pipefail
pkg=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

(cd "$pkg" && mix hex.build --output "$tmp/tinyeval.tar")
mkdir "$tmp/tinyeval" && tar -xOf "$tmp/tinyeval.tar" contents.tar.gz | tar -xzf - -C "$tmp/tinyeval"
version=$(tar -xOf "$tmp/tinyeval.tar" metadata.config | sed -n 's/^{<<"version">>,<<"\(.*\)">>}\.$/\1/p')

mkdir -p "$tmp/app/lib" "$tmp/app/evals" && cd "$tmp/app"
cp "$pkg/../e2e.sh" evals/
cat >mix.exs <<'MIX'
defmodule E2E.MixProject do
  use Mix.Project
  def project, do: [app: :e2e, version: "0.1.0", deps: [{:tinyeval, path: "../tinyeval", only: [:dev, :test], runtime: false}]]
  def application, do: [mod: {E2E, []}, extra_applications: [:logger]]
end
MIX
cat >lib/e2e.ex <<'APP'
defmodule E2E do
  use Application
  require Logger

  def start(_type, _args) do
    IO.puts("app loaded")
    Logger.info("app loaded")
    Supervisor.start_link([], strategy: :one_for_one)
  end

  def answer(input) do
    IO.puts("app called")
    if input == "crash", do: raise("boom"), else: "You said: " <> input
  end
end
APP
echo 'Tinyeval.worker(&E2E.answer/1)' >evals/worker.exs

mix compile
[ "$(mix tinyeval -v)" = "tinyeval $version" ] || { echo "mix tinyeval -v doesn't print $version" >&2; exit 1; }
status=0 && mix tinyeval update 2>"$tmp/update" || status=$?
[ "$status" = 2 ] && grep -q 'mix deps.update tinyeval' "$tmp/update" || { echo "mix tinyeval update: exit $status, $(cat "$tmp/update")" >&2; exit 1; }
E2E_WORKER='mix run --no-start evals/worker.exs' mix tinyeval
