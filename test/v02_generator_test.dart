import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/create_feature.dart';

void main() {
  test('validates and builds minimal analyzer-friendly files', () {
    expect(
      validateFeatureOptions(const FeatureOptions(name: 'user_profile')),
      isNull,
    );
    expect(
      validateFeatureOptions(const FeatureOptions(name: 'Bad')),
      isNotNull,
    );
    final files = featureFiles(
      const FeatureOptions(name: 'profile', state: FeatureStateKind.none),
      'sample',
    );
    expect(
      files.keys,
      contains('lib/features/profile/presentation/profile_screen.dart'),
    );
    expect(files.keys.any((path) => path.contains('/domain/')), isFalse);
    expect(files.values.join(), contains('package:sample/'));
  });
  test('dry run and conflict protection use temporary fixture', () async {
    final root = await Directory.systemTemp.createTemp(
      'feature_generator_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/pubspec.yaml').writeAsString('name: fixture\n');
    final options = const FeatureOptions(name: 'profile', dryRun: true);
    final planned = await createFeature(root, options);
    expect(planned, isNotEmpty);
    expect(
      Directory('${root.path}/lib/features/profile').existsSync(),
      isFalse,
    );
    await createFeature(root, const FeatureOptions(name: 'profile'));
    await expectLater(
      createFeature(root, const FeatureOptions(name: 'profile')),
      throwsStateError,
    );
  });
}
