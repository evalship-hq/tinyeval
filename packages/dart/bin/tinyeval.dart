// The tinyeval command: `dart run tinyeval` runs the bundled tinyeval with bash.
// It doesn't import the worker helper.
import 'dart:io';
import 'dart:isolate';

Future<void> main(List<String> args) async {
  final uri = Uri.parse('package:tinyeval/src/tinyeval');
  var runner = (await Isolate.resolvePackageUri(uri))!.toFilePath();
  var bash = 'bash';
  if (Platform.isWindows) {
    // Git for Windows' bash comes before a bash on PATH, which may be WSL's.
    final gitCmd = (Platform.environment['PATH'] ?? '').split(';').where(
          (dir) =>
              RegExp(r'[\\/]cmd[\\/]?$', caseSensitive: false).hasMatch(dir) &&
              File('$dir\\git.exe').existsSync(),
        );
    bash = [
      for (final dir in gitCmd) '$dir\\..\\bin\\bash.exe',
      r'C:\Program Files\Git\bin\bash.exe',
    ].firstWhere((file) => File(file).existsSync(), orElse: () => 'bash');
    runner = runner.replaceAll('\\', '/');
  }

  ProcessSignal.sigint.watch().listen(
      (_) {}); // Ctrl-C reaches bash too, which stops the run and says so
  final Process process;
  try {
    process = await Process.start(
      bash,
      [runner, ...args],
      environment: {
        'TINYEVAL_PACKAGE_UPDATE': 'dart pub upgrade --major-versions tinyeval'
      },
      mode: ProcessStartMode.inheritStdio,
    );
  } on ProcessException {
    stderr.writeln(Platform.isWindows
        ? 'tinyeval needs bash from Git for Windows: https://gitforwindows.org'
        : 'tinyeval needs bash');
    exit(2);
  }
  final code = await process.exitCode;
  exit(code < 0
      ? 128 - code
      : code); // a negative code is the signal that stopped bash
}
