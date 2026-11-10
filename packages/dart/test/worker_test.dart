// The worker helper, run as tinyeval runs it: inputs and NUL bytes on stdin,
// replies on stdout.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Starts test/worker.dart, writes each chunk to its stdin with a pause
/// between them, and returns what it wrote.
Future<({String stdout, String stderr, int code})> run(
  List<List<int>> chunks,
) async {
  final worker = await Process.start(Platform.resolvedExecutable, [
    'test/worker.dart',
  ]);
  final out = worker.stdout.transform(utf8.decoder).join();
  final err = worker.stderr.transform(utf8.decoder).join();
  for (final chunk in chunks) {
    worker.stdin.add(chunk);
    await worker.stdin.flush();
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  await worker.stdin.close();
  return (stdout: await out, stderr: await err, code: await worker.exitCode);
}

void main() {
  test('several inputs in one chunk, and UTF-8 input split across chunks',
      () async {
    final split = utf8.encode('naïve 日本語 ✓\x00');
    final r = await run([
      utf8.encode('one\x00two\x00'),
      split.sublist(0, 8), // byte 8 is inside 日
      split.sublist(8),
    ]);
    expect(
      r.stdout,
      'You said: one\x00You said: two\x00You said: naïve 日本語 ✓\x00',
    );
    expect(r.code, 0);
  });

  test("the app's output goes to stderr, and NUL bytes leave the reply",
      () async {
    final r = await run([utf8.encode('nul\x00')]);
    expect(r.stdout, 'ab\x00');
    expect(r.stderr, 'app loaded\napp called\nstdout.writeln\nafter await\n');
  });

  test('CouldntRun couldn\'t run, and an API error the app left alone fails',
      () async {
    final r = await run([utf8.encode('key\x00limit\x00')]);
    expect(r.stdout.split('\x00'), [
      '#tinyeval couldnt_run no ANTHROPIC_API_KEY set it\n',
      'ApiException: 429', // only the app knows its status codes
      '',
    ]);
  });

  test(
      'an app error becomes the reply, its stack goes to stderr, and the worker keeps going',
      () async {
    final r = await run([utf8.encode('crash\x00again\x00')]);
    expect(r.stdout, 'Bad state: boom\x00You said: again\x00');
    expect(r.stderr, contains('Bad state: boom\n#0'));
    expect(r.code, 0);
  });

  test("pubspec.yaml's version is tinyeval's _te_version", () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version =
        RegExp(r'^version: (.+)$', multiLine: true).firstMatch(pubspec)![1];
    expect(
      File('lib/src/tinyeval').readAsStringSync(),
      contains('\n_te_version=$version\n'),
      reason: 'run ./prepare.sh',
    );
  });
}
