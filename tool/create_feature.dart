import 'dart:io';

enum FeatureStateKind { bloc, cubit, none }

class FeatureOptions {
  const FeatureOptions({
    required this.name,
    this.state = FeatureStateKind.bloc,
    this.withDomain = false,
    this.withRoute = false,
    this.dryRun = false,
    this.force = false,
  });
  final String name;
  final FeatureStateKind state;
  final bool withDomain, withRoute, dryRun, force;
}

String? validateFeatureOptions(FeatureOptions options) =>
    RegExp(r'^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$').hasMatch(options.name)
    ? null
    : 'Feature name must be valid snake_case.';
String pascalCase(String value) => value
    .split('_')
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join();
Map<String, String> featureFiles(FeatureOptions options, String packageName) {
  final name = options.name, type = pascalCase(name);
  final files = <String, String>{
    'lib/features/$name/data/README.md':
        '# $type data\n\nAdd concrete data sources or repositories only when the feature needs them.\n',
    'lib/features/$name/presentation/${name}_screen.dart':
        "import 'package:flutter/material.dart';\n\nclass ${type}Screen extends StatelessWidget {\n  const ${type}Screen({super.key});\n\n  @override\n  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());\n}\n",
    'test/features/${name}_screen_test.dart':
        "import 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:$packageName/features/$name/presentation/${name}_screen.dart';\n\nvoid main() {\n  testWidgets('$type screen builds', (tester) async {\n    await tester.pumpWidget(const MaterialApp(home: ${type}Screen()));\n    expect(find.byType(${type}Screen), findsOneWidget);\n  });\n}\n",
  };
  if (options.withDomain) {
    files['lib/features/$name/domain/README.md'] =
        '# $type domain\n\nPlace feature policy and domain models here.\n';
  }
  if (options.state != FeatureStateKind.none) {
    final suffix = options.state.name;
    files['lib/features/$name/presentation/${name}_$suffix.dart'] =
        "import 'package:flutter_bloc/flutter_bloc.dart';\n\nclass $type${pascalCase(suffix)} extends ${options.state == FeatureStateKind.bloc ? 'Bloc<Object, int>' : 'Cubit<int>'} {\n  $type${pascalCase(suffix)}() : super(0)${options.state == FeatureStateKind.bloc ? ' { on<Object>((event, emit) {}); }' : ' ;'}\n}\n";
  }
  if (options.withRoute) {
    files['lib/features/$name/ROUTE_TODO.md'] =
        '# Route checklist\n\nRegister `${type}Screen` in `lib/app/router/app_router.dart` and its dependencies in DI.\n';
  }
  return files;
}

Future<List<String>> createFeature(
  Directory root,
  FeatureOptions options,
) async {
  final error = validateFeatureOptions(options);
  if (error != null) throw FormatException(error);
  final pubspec = await File('${root.path}/pubspec.yaml').readAsString();
  final match = RegExp(
    r'^name:\s*([a-z0-9_]+)',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    throw const FormatException(
      'Could not read package name from pubspec.yaml.',
    );
  }
  final files = featureFiles(options, match.group(1)!);
  final conflicts = files.keys
      .where((path) => File('${root.path}/$path').existsSync())
      .toList();
  if (conflicts.isNotEmpty && !options.force) {
    throw StateError('Refusing to overwrite: ${conflicts.join(', ')}');
  }
  if (!options.dryRun) {
    for (final entry in files.entries) {
      final file = File('${root.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }
  }
  return files.keys.toList();
}

FeatureOptions parseFeatureOptions(List<String> args) {
  String? value(String key) {
    final index = args.indexOf(key);
    return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
  }

  final state = FeatureStateKind.values
      .where((item) => item.name == (value('--state') ?? 'bloc'))
      .firstOrNull;
  if (state == null) {
    throw const FormatException('--state must be bloc, cubit, or none.');
  }
  return FeatureOptions(
    name: value('--name') ?? '',
    state: state,
    withDomain: args.contains('--with-domain'),
    withRoute: args.contains('--with-route'),
    dryRun: args.contains('--dry-run'),
    force: args.contains('--force'),
  );
}

Future<void> main(List<String> args) async {
  try {
    final options = parseFeatureOptions(args);
    final files = await createFeature(Directory.current, options);
    stdout.writeln(options.dryRun ? 'Dry run; would create:' : 'Created:');
    for (final path in files) {
      stdout.writeln('  $path');
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  }
}
