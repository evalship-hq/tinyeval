# tinyeval

Test your Dart or Flutter app's AI replies on every pull request. Test cases go in a short bash file, and a worker sends each one to your Dart code.

## Install

```sh
dart pub add --dev tinyeval
```

In a Flutter app: `flutter pub add --dev tinyeval`.

## Example

`evals/support.sh` lists the test cases. Its `worker` line starts your Dart code once, not once per test case:

```bash
worker dart run evals/worker.dart

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  matches "30[- ]day"
  judge "Says a refund isn't possible anymore, politely"
```

`evals/worker.dart` passes each input to your app and returns its reply:

```dart
import 'dart:io';

import 'package:support/support.dart';
import 'package:tinyeval/tinyeval.dart';

final support = Support(); // built on the first input, inside the worker

Future<void> main() => worker((input) {
  if ((Platform.environment['ANTHROPIC_API_KEY'] ?? '').isEmpty) throw CouldntRun('no ANTHROPIC_API_KEY');
  return support.answer(input);
});
```

The function can return a `String` or a `Future<String>`. In a Flutter app, keep the AI call in a library without Flutter imports, so the Dart VM can run it without a device.

## Run it

```sh
dart run tinyeval
```

`dart run tinyeval -h` lists the options, such as `-n 3` to run each test case 3 times.

## Errors

- **`CouldntRun('reason')`** marks the test case as couldn't run. tinyeval counts it apart from the failures, and still exits 1.
- **Any other exception** becomes the reply, such as `Bad state: no order id`, so the eval fails. Its stack trace goes to stderr.

Dart has no official Anthropic or OpenAI SDK, so only your code knows which errors aren't its fault. With `package:http`, map a bad key, a rate limit, a server error, the network and a timeout to `CouldntRun`:

```dart
Future<void> main() => worker((input) async {
  try {
    return await support.answer(input);
  } on ApiException catch (e) { // your app's error for a response that isn't 200
    if (e.statusCode == 401 || e.statusCode == 429 || e.statusCode >= 500) throw CouldntRun('$e');
    rethrow; // a 400 means the request was wrong, so the eval fails
  } on http.ClientException catch (e) {
    throw CouldntRun('$e'); // the network: package:http's SocketException is one
  } on TimeoutException catch (e) {
    throw CouldntRun('$e'); // from .timeout()
  }
});
```

## Your app's output

tinyeval reads replies from the worker's stdout. `worker` runs your function in a zone where `print` and `stdout` write to stderr, so your app's logs can't mix in.

Dart can't move the process's stdout, so some output still reaches it: code in `main` before `worker`, other isolates, child processes started with `ProcessStartMode.inheritStdio`, and native code. Build your app in a top-level `final`, as above: Dart runs its initializer on the first input, inside the zone.

## Needs bash

tinyeval needs bash 3.2 or later. macOS and Linux have it. On Windows, install [Git for Windows](https://gitforwindows.org).

## Updating

```sh
dart pub upgrade --major-versions tinyeval
```

tinyeval sits in your `pubspec.lock`, so Dependabot and Renovate open pull requests for new versions.

## Links

- [tinyeval.com](https://tinyeval.com)
- [Writing evals](https://github.com/evalship-hq/tinyeval#writing-evals): every line an eval file can use, the judge included
- [dart-llm-evals](https://github.com/evalship-hq/dart-llm-evals): a Dart support bot with its evals, run on every pull request
