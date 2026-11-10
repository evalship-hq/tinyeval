#!/usr/bin/env bash
# Builds the archive pub.dev would get, installs it into an empty project, and runs packages/e2e.sh through
# dart run tinyeval. Run ./prepare.sh first.
set -euo pipefail
pkg=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
# --to-archive is hidden from the help. It validates like a publish, and writes what the upload would send.
dart pub publish -C "$pkg" --to-archive=tinyeval.tar.gz >/dev/null
mkdir tinyeval && tar xzf tinyeval.tar.gz -C tinyeval
cat >pubspec.yaml <<'YAML'
name: app
environment:
  sdk: ^3.0.0
dev_dependencies:
  tinyeval:
    path: tinyeval
YAML
mkdir lib evals
cp "$pkg/../e2e.sh" evals/
cat >lib/app.dart <<'DART'
class App {
  App() {
    print('app loaded');
  }

  String answer(String input) {
    print('app called');
    if (input == 'crash') throw Exception('boom');
    return 'You said: $input';
  }
}
DART
cat >evals/worker.dart <<'DART'
import 'package:app/app.dart';
import 'package:tinyeval/tinyeval.dart';

final app = App(); // built on the first call, inside the worker
Future<void> main() => worker((input) => app.answer(input));
DART
dart pub get >/dev/null
E2E_WORKER="dart run evals/worker.dart" dart run tinyeval

version=$(sed -n 's/^version: //p' tinyeval/pubspec.yaml)
[ "$version" = "$(sed -n 's/^_te_version=//p' "$pkg/../../tinyeval")" ] || { echo "pubspec.yaml has $version" >&2; exit 1; }
[ "$(dart run tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $(dart run tinyeval -v)" >&2; exit 1; }
code=0; said=$(dart run tinyeval update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $said == *"dart pub upgrade --major-versions tinyeval"* ]] || { echo "tinyeval update exited $code: $said" >&2; exit 1; }
echo "end to end: ok"
