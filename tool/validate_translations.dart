import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final directory = Directory('assets/translations');
  final files =
      await directory
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.json'))
            .cast<File>()
            .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.length < 2) {
    stderr.writeln('Expected at least two translation JSON files.');
    exitCode = 1;
    return;
  }

  final locales = <String, Map<String, String>>{};
  for (final file in files) {
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! Map<String, Object?>) {
        throw const FormatException('root must be an object');
      }
      locales[file.uri.pathSegments.last] = _flatten(value);
    } on Object catch (error) {
      stderr.writeln('${file.path}: invalid translation JSON: $error');
      exitCode = 1;
      return;
    }
  }

  final referenceName = locales.keys.first;
  final reference = locales[referenceName]!;
  var failed = false;
  for (final entry in locales.entries.skip(1)) {
    final missing = reference.keys.toSet().difference(entry.value.keys.toSet());
    final extra = entry.value.keys.toSet().difference(reference.keys.toSet());
    if (missing.isNotEmpty || extra.isNotEmpty) {
      failed = true;
      stderr.writeln('${entry.key}: missing=$missing extra=$extra');
    }
    for (final key in reference.keys.toSet().intersection(
      entry.value.keys.toSet(),
    )) {
      final expected = _placeholders(reference[key]!);
      final actual = _placeholders(entry.value[key]!);
      if (!_same(expected, actual)) {
        failed = true;
        stderr.writeln('${entry.key}: placeholder mismatch at $key');
      }
    }
  }
  if (failed) {
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Translations valid: ${locales.length} locales, '
    '${reference.length} matching leaf keys.',
  );
}

Map<String, String> _flatten(Map<String, Object?> input, [String prefix = '']) {
  final output = <String, String>{};
  for (final entry in input.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    final value = entry.value;
    if (value is Map<String, Object?>) {
      output.addAll(_flatten(value, key));
    } else if (value is String) {
      output[key] = value;
    } else {
      throw FormatException('$key must be a string or object');
    }
  }
  return output;
}

List<String> _placeholders(String value) =>
    RegExp(r'\{[^}]*\}')
        .allMatches(value)
        .map((match) => match.group(0)!)
        .toList()
      ..sort();

bool _same(List<String> left, List<String> right) =>
    left.length == right.length &&
    List.generate(
      left.length,
      (index) => left[index] == right[index],
    ).every((value) => value);
