import 'dart:io';

Future<void> main() async {
  final pubspec = await File('pubspec.yaml').readAsLines();
  final report = await File('docs/DEPENDENCIES.md').readAsString();
  final dependencies = <String>{};
  var section = '';
  for (final line in pubspec) {
    if (!line.startsWith(' ')) {
      final topLevel = line.trim();
      if (topLevel.isEmpty || topLevel.startsWith('#')) continue;
      section = switch (topLevel) {
        'dependencies:' => 'runtime',
        'dev_dependencies:' => 'development',
        'dependency_overrides:' => 'override',
        _ => '',
      };
      continue;
    }
    final match = RegExp(r'^  ([a-zA-Z0-9_]+):').firstMatch(line);
    if (match == null) continue;
    if (section == 'override') {
      stderr.writeln('Unjustified dependency override: ${match.group(1)}');
      exitCode = 1;
      return;
    }
    if (section == 'runtime' || section == 'development') {
      dependencies.add(match.group(1)!);
    }
  }

  const sdkOrTooling = {
    'flutter',
    'flutter_test',
    'flutter_lints',
    'build_runner',
    'drift_dev',
    'cupertino_icons',
  };
  final dartFiles = <File>[];
  for (final root in ['lib', 'test', 'tool']) {
    await for (final entity in Directory(root).list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity);
      }
    }
  }
  final source = (await Future.wait(
    dartFiles.map((file) => file.readAsString()),
  )).join('\n');
  final failures = <String>[];
  for (final dependency in dependencies) {
    if (!report.contains('| `$dependency` |')) {
      failures.add('$dependency is missing from docs/DEPENDENCIES.md');
    }
    if (!sdkOrTooling.contains(dependency) &&
        !source.contains('package:$dependency/')) {
      failures.add('$dependency has no source import');
    }
  }
  if (failures.isNotEmpty) {
    stderr.writeln(failures.join('\n'));
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Dependency audit passed: ${dependencies.length} direct SDK/package entries.',
  );
}
