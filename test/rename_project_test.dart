import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/rename_project.dart';

void main() {
  const valid = RenameOptions(
    appName: 'My App',
    packageName: 'my_app',
    bundleId: 'com.company.myapp',
  );
  test('validates rename input', () {
    expect(validateRenameOptions(valid), isNull);
    expect(
      validateRenameOptions(
        const RenameOptions(
          appName: '',
          packageName: 'Bad Name',
          bundleId: 'bad',
        ),
      ),
      isNotNull,
    );
  });
  test('transforms Dart and native identifiers', () {
    expect(
      transformProjectText(
        "name: flutter_starter\nimport 'package:flutter_starter/a.dart';\nFlutter Starter\ncom.example.flutterstarter",
        valid,
        path: 'pubspec.yaml',
      ),
      contains(
        "name: my_app\nimport 'package:my_app/a.dart';\nMy App\ncom.company.myapp",
      ),
    );
    expect(
      transformProjectText(
        'namespace = "com.example.flutter_demo"',
        valid,
        path: 'android/app/build.gradle.kts',
      ),
      contains('com.company.myapp'),
    );
  });
  test('renames flavor fixture idempotently', () async {
    final root = await Directory.systemTemp.createTemp('rename_v02_');
    addTearDown(() => root.delete(recursive: true));
    await File('${root.path}/pubspec.yaml')
        .writeAsString('name: flutter_starter\n');
    final native = File('${root.path}/flavors.xml');
    await native.writeAsString(
      'Flutter Starter Dev com.example.flutterstarter.dev flutterstarter-dev dev.example.invalid',
    );
    const options = RenameOptions(
      appName: 'My App',
      packageName: 'my_app',
      bundleId: 'com.company.myapp',
    );
    final changed = await renameProject(root, options);
    expect(changed, containsAll(['pubspec.yaml', 'flavors.xml']));
    expect(
      await native.readAsString(),
      contains('My App Dev com.company.myapp.dev myapp-dev'),
    );
    expect(
      await renameProject(
        root,
        const RenameOptions(
          appName: 'My App',
          packageName: 'my_app',
          bundleId: 'com.company.myapp',
          dryRun: true,
        ),
      ),
      isEmpty,
    );
  });

  test('moves Android activity to the renamed package path', () async {
    final root = await Directory.systemTemp.createTemp('rename_android_');
    addTearDown(() => root.delete(recursive: true));
    final activity = File(
      '${root.path}/android/app/src/main/kotlin/com/example/old/MainActivity.kt',
    );
    await activity.parent.create(recursive: true);
    await activity.writeAsString(
      'package com.example.flutterstarter\nclass MainActivity',
    );
    final changed = await renameProject(root, valid);
    final moved = File(
      '${root.path}/android/app/src/main/kotlin/com/company/myapp/MainActivity.kt',
    );
    expect(await moved.exists(), isTrue);
    expect(await activity.exists(), isFalse);
    expect(
      changed,
      contains('android/app/src/main/kotlin/com/company/myapp/MainActivity.kt'),
    );
    expect(await moved.readAsString(), contains('package com.company.myapp'));
    expect(await renameProject(root, valid), isEmpty);
  });
}
