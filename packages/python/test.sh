#!/usr/bin/env bash
# The package's tests (packages/SPEC.md, Tests): the helper's unit tests, then the wheel, installed into an
# empty project, runs packages/e2e.sh through its tinyeval command. The release job publishes the wheel in dist/.
set -euo pipefail
cd "$(dirname "$0")"
python=${PYTHON:-python3}
export PIP_DISABLE_PIP_VERSION_CHECK=1
"$python" -m unittest discover -s tests

project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
"$python" -m venv "$project/.venv"
bin=$project/.venv/bin
[ -d "$bin" ] || bin=$project/.venv/Scripts # Windows
rm -rf dist
"$bin/python" -m pip -q install -U pip # pip before 21.3 builds from a copy, away from ../../tinyeval
"$bin/python" -m pip -q wheel --no-deps -w dist .
"$bin/python" -m pip -q install dist/*.whl
mkdir "$project/evals"
cp ../e2e.sh "$project/evals/"
cat >"$project/evals/worker.py" <<'PY'
from tinyeval import worker

print("app loaded")


def answer(text):
    print("app called")
    if text == "crash":
        raise RuntimeError("boom")
    return "You said: " + text


worker(answer)
PY
cd "$project"
version=$("$bin/python" -c 'import importlib.metadata; print(importlib.metadata.version("tinyeval-cli"))')
[ "$("$bin/tinyeval" -v)" = "tinyeval $version" ] || { echo "tinyeval -v doesn't print $version" >&2; exit 1; }
set +e
"$bin/tinyeval" update 2>update.err
status=$?
set -e
[ "$status" = 2 ] && grep -q "pip install -U tinyeval-cli" update.err || { echo "tinyeval update exited $status: $(cat update.err)" >&2; exit 1; }
E2E_WORKER="$bin/python evals/worker.py" "$bin/tinyeval"
