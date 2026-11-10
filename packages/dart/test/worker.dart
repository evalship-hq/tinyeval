// A worker on the helper, around a fake app, which worker_test.dart runs.
import 'dart:io';

import 'package:tinyeval/tinyeval.dart';

class ApiException implements Exception {
  ApiException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'ApiException: $statusCode';
}

// Built on the first call, inside the worker's zone, like an app's client.
final app = () {
  print('app loaded');
  return 'app';
}();

Future<void> main() => worker((input) async {
      print('$app called');
      stdout.writeln('stdout.writeln');
      await Future<void>.delayed(Duration.zero);
      print('after await');
      return switch (input) {
        'key' => throw CouldntRun('no ANTHROPIC_API_KEY\nset it'),
        'limit' => throw ApiException(429),
        'crash' => throw StateError('boom'),
        'nul' => 'a\x00b',
        _ => 'You said: $input',
      };
    });
