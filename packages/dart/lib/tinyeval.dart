/// tinyeval's worker helper: `await worker(answer)` answers each input from an
/// eval file's `worker` line with your Dart code.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Throw it when the AI call couldn't run, such as without an API key or on a
/// rate limit. tinyeval counts the test case apart from the failures, and
/// still exits 1.
class CouldntRun implements Exception {
  CouldntRun(this.reason);

  final String reason;

  @override
  String toString() => 'CouldntRun: $reason';
}

/// Calls [answer] with each input tinyeval sends, one at a time, replies with
/// what it returns, and exits when tinyeval is done.
///
/// [answer] runs in a zone whose `print` and `stdout` go to stderr, so your
/// app's output can't mix into the replies. A [CouldntRun] makes the test case
/// couldn't run. Any other error becomes the reply, so the eval fails.
Future<Never> worker(FutureOr<String> Function(String input) answer) async {
  final replies = stdout; // the real stdout, taken before the zone hides it
  final quiet = ZoneSpecification(
    print: (self, parent, zone, line) => stderr.writeln(line),
  );
  var rest = <int>[];
  await for (final chunk in stdin) {
    rest.addAll(chunk);
    for (var i = rest.indexOf(0); i >= 0; i = rest.indexOf(0)) {
      // Decoded once whole, so a character split across reads survives.
      final input = utf8.decode(rest.sublist(0, i), allowMalformed: true);
      rest = rest.sublist(i + 1);
      String reply;
      try {
        reply = await IOOverrides.runZoned(
          () => runZoned(
            () => Future.sync(() => answer(input)),
            zoneSpecification: quiet,
          ),
          stdout: () => stderr,
        );
      } catch (e, stack) {
        stderr.writeln('$e\n$stack');
        reply = e is CouldntRun
            ? '#tinyeval couldnt_run ${e.reason.replaceAll(RegExp(r'\s+'), ' ').trim()}\n'
            : '$e';
      }
      replies.add([...utf8.encode(reply.replaceAll('\x00', '')), 0]);
      await replies.flush();
    }
  }
  await stderr.flush();
  exit(0);
}
