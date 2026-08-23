import 'dart:io';

Future<void> main(List<String> args) async {
  try {
    await _validate(args);
  } on StateError catch (error) {
    stderr.writeln('Release validation failed: ${error.message}');
    exitCode = 1;
  }
}

Future<void> _validate(List<String> args) async {
  final tagIndex = args.indexOf('--tag');
  final tag = tagIndex >= 0 && tagIndex + 1 < args.length
      ? args[tagIndex + 1]
      : null;
  final pubspec = await File('pubspec.yaml').readAsString();
  final match = RegExp(
    r'^version:\s*([^+\s]+)',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) throw StateError('pubspec.yaml version is missing');
  final version = match.group(1)!;
  if (version != '1.0.0') {
    throw StateError('Release version must be 1.0.0, found $version');
  }
  if (tag != null && tag != 'v$version') {
    throw StateError('Tag $tag does not match pubspec version v$version');
  }
  if (args.contains('--strict')) {
    final license = await File('LICENSE').readAsString();
    if (license.contains('OWNER ACTION REQUIRED')) {
      throw StateError('Repository owner must select a source license first.');
    }
  }
  stdout.writeln('Release metadata valid for v$version.');
}
