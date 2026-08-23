import 'dart:io';

import 'release_files.dart';

Future<void> main(List<String> args) async {
  final mode = _value(args, '--mode') ?? 'fresh';
  if (!{'fresh', 'rename'}.contains(mode)) {
    stderr.writeln('--mode must be fresh or rename');
    exitCode = 64;
    return;
  }
  final runAndroid = args.contains('--native') || args.contains('--android');
  final runIos = args.contains('--native') || args.contains('--ios');
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final flutter =
      _value(args, '--flutter') ??
      (flutterRoot == null ? 'flutter' : '$flutterRoot/bin/flutter');
  final keep = args.contains('--keep');
  final root = Directory.current.absolute;
  final temp = await Directory.systemTemp.createTemp('flutter_template_$mode');
  final fixture = Directory('${temp.path}/project');
  try {
    await copyReleaseFiles(root, fixture);
    _requireFiles(fixture);
    if (mode == 'rename') await _rename(fixture);
    await _verifyDart(fixture, flutter, normalizeFormat: mode == 'rename');
    if (runAndroid || runIos) {
      await _verifyNative(fixture, flutter, android: runAndroid, ios: runIos);
    }
    stdout.writeln('Template $mode verification passed in ${fixture.path}.');
  } finally {
    if (keep) {
      stdout.writeln('Kept fixture at ${fixture.path}.');
    } else {
      await temp.delete(recursive: true);
    }
  }
}

Future<void> _rename(Directory fixture) async {
  const options = [
    '--app-name',
    'Example Notes',
    '--package-name',
    'example_notes',
    '--bundle-id',
    'com.example.notes',
    '--deep-link-scheme',
    'example-notes',
    '--domain',
    'links.example.com',
  ];
  await _run(Platform.resolvedExecutable, [
    'run',
    'tool/rename_project.dart',
    ...options,
  ], fixture);
  final oldIdentifiers = <String, List<String>>{};
  const retainedFixtureReferences = {
    'FEATURE_V0.1.md',
    'FEATURE_V0.2.md',
    'FEATURE_V0.3.md',
    'FEATURE_V1.0.md',
    'test/rename_project_test.dart',
    'tool/rename_project.dart',
    'tool/verify_template.dart',
  };
  for (final path in await releaseFilePaths(fixture)) {
    if (retainedFixtureReferences.contains(path)) continue;
    if (!isAuditableTextFile(path)) continue;
    final text = await File('${fixture.path}/$path').readAsString();
    final hits = [
      'package:flutter_starter/',
      'name: flutter_starter',
      'com.example.flutterstarter',
    ].where(text.contains).toList();
    if (hits.isNotEmpty) oldIdentifiers[path] = hits;
  }
  if (oldIdentifiers.isNotEmpty) {
    throw StateError('Old active identifiers remain: $oldIdentifiers');
  }
  final dryRun = await _run(
    Platform.resolvedExecutable,
    ['run', 'tool/rename_project.dart', ...options, '--dry-run'],
    fixture,
    capture: true,
  );
  if (!dryRun.contains('0 file(s).')) {
    throw StateError('Second rename is not idempotent:\n$dryRun');
  }
  await _run(Platform.resolvedExecutable, [
    'run',
    'tool/validate_branding.dart',
  ], fixture);
}

Future<void> _verifyDart(
  Directory fixture,
  String flutter, {
  required bool normalizeFormat,
}) async {
  await _run(flutter, ['pub', 'get'], fixture);
  if (normalizeFormat) {
    await _run(Platform.resolvedExecutable, ['format', '.'], fixture);
  }
  await _run(Platform.resolvedExecutable, [
    'run',
    'build_runner',
    'build',
    '--delete-conflicting-outputs',
  ], fixture);
  await _run(Platform.resolvedExecutable, [
    'format',
    '--set-exit-if-changed',
    '.',
  ], fixture);
  await _run(flutter, ['analyze'], fixture);
  await _run(flutter, ['test'], fixture);
  await _run(Platform.resolvedExecutable, [
    'run',
    'tool/validate_translations.dart',
  ], fixture);
  await _run(Platform.resolvedExecutable, [
    'run',
    'tool/check_dependencies.dart',
  ], fixture);
  await _run(Platform.resolvedExecutable, [
    'run',
    'tool/scan_secrets.dart',
  ], fixture);
}

Future<void> _verifyNative(
  Directory fixture,
  String flutter, {
  required bool android,
  required bool ios,
}) async {
  final developmentTarget = 'lib/main_development.dart';
  if (android) {
    await _run(flutter, [
      'build',
      'apk',
      '--debug',
      '--flavor',
      'development',
      '-t',
      developmentTarget,
      '--dart-define-from-file=config/development.json',
    ], fixture);
    await _run(flutter, [
      'build',
      'apk',
      '--release',
      '--flavor',
      'production',
      '-t',
      'lib/main_production.dart',
      '--dart-define-from-file=config/production.json',
    ], fixture);
  }
  if (ios && Platform.isMacOS) {
    await _run(flutter, [
      'build',
      'ios',
      '--simulator',
      '--no-codesign',
      '--flavor',
      'development',
      '-t',
      developmentTarget,
      '--dart-define-from-file=config/development.json',
    ], fixture);
  } else if (ios) {
    throw UnsupportedError('iOS verification requires macOS.');
  }
}

void _requireFiles(Directory fixture) {
  for (final path in const [
    'pubspec.yaml',
    'pubspec.lock',
    'README.md',
    'config/development.json',
    'assets/translations/en.json',
    'lib/main_development.dart',
    'android/app/build.gradle.kts',
    'ios/Runner.xcodeproj/project.pbxproj',
  ]) {
    if (!File('${fixture.path}/$path').existsSync()) {
      throw StateError('Fresh copy is missing $path');
    }
  }
}

Future<String> _run(
  String executable,
  List<String> arguments,
  Directory workingDirectory, {
  bool capture = false,
}) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory.path,
    mode: capture ? ProcessStartMode.normal : ProcessStartMode.inheritStdio,
  );
  final output = capture
      ? await process.stdout.transform(SystemEncoding().decoder).join()
      : '';
  final error = capture
      ? await process.stderr.transform(SystemEncoding().decoder).join()
      : '';
  final code = await process.exitCode;
  if (code != 0) {
    throw ProcessException(executable, arguments, error, code);
  }
  return '$output$error';
}

String? _value(List<String> args, String name) {
  final index = args.indexOf(name);
  return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
}
