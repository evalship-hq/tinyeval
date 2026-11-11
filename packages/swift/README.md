# tinyeval

Test the AI calls in your Swift package with evals, with `swift run` on your Mac and in CI.

## Install

SwiftPM has no dev dependencies, so add the `Tinyeval` library to the executable target your evals start, and keep it out of your app's targets:

```swift
dependencies: [
    .package(url: "https://github.com/evalship-hq/tinyeval-swift", from: "0.11.0"),
],
targets: [
    .target(name: "Support"),
    .executableTarget(name: "evalworker", dependencies: [
        "Support",
        .product(name: "Tinyeval", package: "tinyeval-swift"),
    ]),
]
```

## Write an eval

`evals/support.sh` lists the test cases and how to check each reply:

```bash
worker swift run -q -c release evalworker

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`Sources/evalworker/main.swift` builds your app once, then answers every test case:

```swift
import Foundation
import Support
import Tinyeval

let support = Support()
await Tinyeval.worker { input in
    guard !(ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? "").isEmpty else {
        throw Tinyeval.CouldntRun("ANTHROPIC_API_KEY isn't set")
    }
    return try await support.answer(input)
}
```

## Run it

```sh
swift run tinyeval
```

## When the AI call fails

Swift has no official Anthropic or OpenAI SDK, so your worker says when a call couldn't run. Throw `Tinyeval.CouldntRun(reason)` for a missing key, a 401, a 429, a 5xx, a timeout or a lost connection. tinyeval counts those test cases as couldn't run, apart from the failures, and the run still exits 1.

With URLSession, catch the `URLError` and the status your app throws:

```swift
do {
    return try await support.answer(input)
} catch let error as URLError {
    throw Tinyeval.CouldntRun("anthropic: \(error.code)")
} catch let Support.Failure.api(status, message) where status == 401 || status == 429 || status >= 500 {
    throw Tinyeval.CouldntRun("anthropic: \(status) \(message)")
}
```

Any other error becomes the reply, as `TypeName: description`, so the eval fails. The worker goes on with the next test case.

## Your app's output

Linking `Tinyeval` points stdout at stderr as the worker starts, before `main.swift` runs. So `print`, `FileHandle.standardOutput`, C libraries and child processes all write to stderr, and only the replies reach tinyeval.

## Needs bash

tinyeval is one bash script, and needs bash 3.2 or later. macOS and Linux have it. The package runs on macOS and Linux, not yet on Windows.

## Updating

```sh
swift package update tinyeval-swift
```

Dependabot and Renovate see new versions of the package. A repo that commits its own `./tinyeval` file keeps running that file.

## More

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every check line, the judge and the options
- [evalship-hq/swift-llm-evals](https://github.com/evalship-hq/swift-llm-evals): a Swift support bot with its evals in CI
- This package is built from `packages/swift` in [evalship-hq/tinyeval](https://github.com/evalship-hq/tinyeval). Send issues and pull requests there.
