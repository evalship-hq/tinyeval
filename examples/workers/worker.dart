// tinyeval worker in Dart. In your eval file:
//   worker dart run evals/worker.dart
// Import your app's libraries at the top, so they load once per worker.
import 'dart:convert';
import 'dart:io';

Future<String> reply(String input) async {
  return 'You said: $input'; // your app's AI call goes here
}

Future<void> main() async {
  var rest = <int>[];
  await for (final chunk in stdin) {
    rest.addAll(chunk);
    for (var i = rest.indexOf(0); i >= 0; i = rest.indexOf(0)) {
      final input = utf8.decode(rest.sublist(0, i));
      rest = rest.sublist(i + 1);
      stdout.add([...utf8.encode(await reply(input)), 0]);
      await stdout.flush();
    }
  }
}
