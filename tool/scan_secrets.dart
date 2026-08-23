import 'dart:io';

import 'release_files.dart';

final _secretPatterns = <String, RegExp>{
  'private key': RegExp(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
  'AWS access key': RegExp(r'AKIA[0-9A-Z]{16}'),
  'GitHub token': RegExp(r'gh[pousr]_[A-Za-z0-9]{30,}'),
  'Stripe live key': RegExp(r'[spr]k_live_[A-Za-z0-9]{16,}'),
  'JWT': RegExp(
    r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
  ),
};

const _forbiddenNames = {
  'google-services.json',
  'GoogleService-Info.plist',
  'key.properties',
};

Future<void> main() async {
  final root = Directory.current;
  final findings = <String>[];
  for (final path in await releaseFilePaths(root)) {
    final name = path.split(Platform.pathSeparator).last;
    final lower = name.toLowerCase();
    if (_forbiddenNames.contains(name) ||
        lower.endsWith('.jks') ||
        lower.endsWith('.keystore') ||
        lower.endsWith('.p12') ||
        lower.endsWith('.mobileprovision')) {
      findings.add('$path: forbidden credential/signing file');
      continue;
    }
    if (!isAuditableTextFile(path)) continue;
    final content = await File('${root.path}/$path').readAsString();
    for (final pattern in _secretPatterns.entries) {
      if (pattern.value.hasMatch(content)) {
        findings.add('$path: ${pattern.key} signature');
      }
    }
  }
  for (final config in const [
    'config/development.json',
    'config/staging.json',
    'config/production.json',
  ]) {
    final content = await File(config).readAsString();
    if (!content.contains('example.invalid')) {
      findings.add('$config: sample backend must remain under .invalid');
    }
  }
  if (findings.isNotEmpty) {
    stderr.writeln('Potential secrets found:\n${findings.join('\n')}');
    exitCode = 1;
    return;
  }
  stdout.writeln('Secret scan passed for release-visible files.');
}
