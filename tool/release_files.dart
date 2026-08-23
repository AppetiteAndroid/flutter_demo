import 'dart:io';

const _excludedDirectories = {
  '.git',
  '.dart_tool',
  '.idea',
  '.vscode',
  'build',
  'coverage',
  'Pods',
  'ephemeral',
};

const _excludedFiles = {
  '.flutter-plugins-dependencies',
  'android/local.properties',
  'ios/Flutter/Generated.xcconfig',
  'ios/Flutter/flutter_export_environment.sh',
};

Future<List<String>> releaseFilePaths(Directory root) async {
  if (await Directory('${root.path}/.git').exists()) {
    final result = await Process.run('git', [
      'ls-files',
      '-z',
    ], workingDirectory: root.path);
    if (result.exitCode == 0) {
      return (result.stdout as String)
          .split('\u0000')
          .where((path) => path.isNotEmpty)
          .toList()
        ..sort();
    }
  }

  final paths = <String>[];
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = _relative(root, entity);
    final segments = relative.split(Platform.pathSeparator);
    if (segments.any(_excludedDirectories.contains) ||
        _excludedFiles.contains(relative) ||
        relative.endsWith('.iml')) {
      continue;
    }
    paths.add(relative);
  }
  return paths..sort();
}

Future<void> copyReleaseFiles(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  for (final relative in await releaseFilePaths(source)) {
    final from = File('${source.path}/$relative');
    if (!await from.exists()) continue;
    final to = File('${destination.path}/$relative');
    await to.parent.create(recursive: true);
    await from.copy(to.path);
  }
}

String _relative(Directory root, File file) =>
    file.path.substring(root.path.length + 1);

bool isAuditableTextFile(String path) {
  const extensions = {
    '.dart',
    '.json',
    '.yaml',
    '.yml',
    '.md',
    '.txt',
    '.kts',
    '.gradle',
    '.xml',
    '.plist',
    '.pbxproj',
    '.xcconfig',
    '.swift',
    '.kt',
    '.properties',
  };
  return extensions.any(path.endsWith) ||
      {'.gitignore', 'LICENSE', 'Makefile'}.contains(path);
}
