#!/usr/bin/env bash
# The package's tests (packages/SPEC.md, Tests): the helper's unit tests, then the end to end run. That pushes the
# package to a local mirror as the release job does, depends on it by URL from an empty package, and runs
# packages/e2e.sh with swift run tinyeval.
set -euo pipefail
pkg=$(cd "$(dirname "$0")" && pwd)
cd "$pkg"
version=$(sed -n 's/^_te_version=//p' ../../tinyeval)
cp ../../tinyeval Sources/TinyevalCommand/tinyeval # the command's resource
swift test

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git init -q --bare -b main "$tmp/tinyeval-swift.git" # named as on GitHub, since SwiftPM names a package by its URL
./mirror.sh "$tmp/tinyeval-swift.git" "v$version"
[[ $(./mirror.sh "$tmp/tinyeval-swift.git" "v$version") == *"has $version already"* ]] || { echo "a second push didn't skip" >&2; exit 1; }

mkdir -p "$tmp/app/Sources/worker" "$tmp/app/evals"
cd "$tmp/app"
cat >Package.swift <<SWIFT
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "app",
    platforms: [.macOS(.v13)],
    dependencies: [.package(url: "file://$tmp/tinyeval-swift.git", from: "$version")],
    targets: [.executableTarget(name: "worker", dependencies: [.product(name: "Tinyeval", package: "tinyeval-swift")])]
)
SWIFT
cat >Sources/worker/main.swift <<'SWIFT'
import Foundation
import Tinyeval

enum AppError: Error { case boom }

print("app loaded")
FileHandle.standardOutput.write(Data("app loaded, at the file descriptor\n".utf8))
let child = try Process.run(URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "echo app loaded, in a child process"])
child.waitUntilExit()
await Tinyeval.worker { input in
    print("app called")
    if input == "crash" { throw AppError.boom }
    return "You said: \(input)"
}
SWIFT
cp "$pkg/../e2e.sh" evals/

E2E_WORKER="swift run -q worker" swift run tinyeval
[ "$(swift run -q tinyeval -v)" = "tinyeval $version" ] || { echo "tinyeval -v printed $(swift run -q tinyeval -v)" >&2; exit 1; }
code=0 && said=$(swift run -q tinyeval update 2>&1) || code=$?
[ "$code" = 2 ] && [[ $said == *"swift package update tinyeval-swift"* ]] || { echo "tinyeval update exited $code: $said" >&2; exit 1; }
echo "end to end: ok"
