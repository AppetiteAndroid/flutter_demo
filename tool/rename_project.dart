import 'dart:io';

class RenameOptions {
  const RenameOptions({
    required this.appName,
    required this.packageName,
    required this.bundleId,
    this.deepLinkScheme,
    this.domain,
    this.dryRun = false,
  });
  final String appName, packageName, bundleId;
  final String? deepLinkScheme, domain;
  final bool dryRun;
  String get resolvedScheme =>
      deepLinkScheme ?? packageName.replaceAll('_', '');
  String get resolvedDomain =>
      domain ?? 'links.${bundleId.split('.').reversed.join('.')}';
}

String? validateRenameOptions(RenameOptions options) {
  if (options.appName.trim().isEmpty) {
    return 'App name must not be empty.';
  }
  if (!RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$')
      .hasMatch(options.packageName)) {
    return 'Package name must be valid snake_case.';
  }
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*){2,}$')
      .hasMatch(options.bundleId)) {
    return 'Bundle ID must be a reverse-domain identifier with at least three parts.';
  }
  if (options.deepLinkScheme != null &&
      !RegExp(r'^[a-z][a-z0-9+.-]*$').hasMatch(options.deepLinkScheme!)) {
    return 'Deep-link scheme must be lowercase and URI-safe.';
  }
  if (options.domain != null &&
      !RegExp(r'^[a-z0-9.-]+\.[a-z]{2,}$').hasMatch(options.domain!)) {
    return 'Domain must be a valid lowercase hostname.';
  }
  return null;
}

String transformProjectText(
  String input,
  RenameOptions options, {
  required String path,
}) {
  var output = input
      .replaceAll('package:flutter_starter/', 'package:${options.packageName}/')
      .replaceAll('com.example.flutterstarter', options.bundleId)
      .replaceAll(
        'package com.example.flutterstarter',
        'package ${options.bundleId}',
      )
      .replaceAll('com.example.flutterDemo', options.bundleId)
      .replaceAll('flutterstarter', options.resolvedScheme)
      .replaceAll('example.invalid', options.resolvedDomain)
      .replaceAll('Flutter Starter', options.appName);
  if (path.endsWith('pubspec.yaml')) {
    output = output.replaceFirst(
      RegExp(r'^name:\s*flutter_starter\s*$', multiLine: true),
      'name: ${options.packageName}',
    );
  }
  if (path.endsWith('build.gradle.kts')) {
    output = output.replaceAll('com.example.flutter_demo', options.bundleId);
  }
  return output;
}

RenameOptions parseRenameOptions(List<String> args) {
  String? value(String name) {
    final index = args.indexOf(name);
    return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
  }

  return RenameOptions(
    appName: value('--app-name') ?? '',
    packageName: value('--package-name') ?? '',
    bundleId: value('--bundle-id') ?? '',
    deepLinkScheme: value('--deep-link-scheme'),
    domain: value('--domain'),
    dryRun: args.contains('--dry-run'),
  );
}

Future<List<String>> renameProject(
  Directory root,
  RenameOptions options,
) async {
  final error = validateRenameOptions(options);
  if (error != null) {
    throw FormatException(error);
  }
  const skipped = {'.git', '.dart_tool', 'build', 'Pods', '.idea'};
  const extensions = {
    '.dart',
    '.yaml',
    '.yml',
    '.json',
    '.md',
    '.kts',
    '.gradle',
    '.xml',
    '.plist',
    '.pbxproj',
    '.xcconfig',
    '.xcscheme',
    '.entitlements',
    '.kt',
    '.swift',
    '.properties',
  };
  final changed = <String>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final relative = entity.path.substring(root.path.length + 1);
    if (relative.split(Platform.pathSeparator).any(skipped.contains)) {
      continue;
    }
    if (!extensions.any(relative.endsWith)) {
      continue;
    }
    final bytes = await entity.readAsBytes();
    if (bytes.contains(0)) {
      continue;
    }
    final before = String.fromCharCodes(bytes);
    final after = transformProjectText(before, options, path: relative);
    if (after == before) {
      continue;
    }
    changed.add(relative);
    if (!options.dryRun) {
      await entity.writeAsString(after);
    }
  }
  await _moveAndroidMainActivity(root, options, changed);
  final unique = changed.toSet().toList()..sort();
  changed
    ..clear()
    ..addAll(unique);
  return changed;
}

Future<void> _moveAndroidMainActivity(
  Directory root,
  RenameOptions options,
  List<String> changed,
) async {
  final androidRoot = Directory('${root.path}/android/app/src/main/kotlin');
  if (!await androidRoot.exists()) return;
  File? activity;
  await for (final entity in androidRoot.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File && entity.path.endsWith('/MainActivity.kt')) {
      activity = entity;
      break;
    }
  }
  if (activity == null) return;
  final relativeSource = activity.path.substring(root.path.length + 1);
  final destination = File(
    '${androidRoot.path}/${options.bundleId.replaceAll('.', '/')}/MainActivity.kt',
  );
  if (activity.path == destination.path) return;
  final relativeDestination = destination.path.substring(root.path.length + 1);
  changed
    ..add(relativeSource)
    ..add(relativeDestination);
  if (options.dryRun) return;
  await destination.parent.create(recursive: true);
  await activity.rename(destination.path);
  var parent = activity.parent;
  while (parent.path != androidRoot.path) {
    if (await parent.list().isEmpty) {
      final next = parent.parent;
      await parent.delete();
      parent = next;
    } else {
      break;
    }
  }
}

Future<void> main(List<String> args) async {
  try {
    final options = parseRenameOptions(args);
    final files = await renameProject(Directory.current, options);
    stdout.writeln(options.dryRun ? 'Dry run; would change:' : 'Changed:');
    for (final file in files) {
      stdout.writeln('  $file');
    }
    stdout.writeln('${files.length} file(s).');
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } catch (error) {
    stderr.writeln('Rename failed: $error');
    exitCode = 1;
  }
}
