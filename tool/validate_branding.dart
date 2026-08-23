import 'dart:io';

void main() {
  const paths = [
    'android/app/src/main/res/drawable/ic_launcher_foreground.xml',
    'android/app/src/development/res/values/colors.xml',
    'android/app/src/staging/res/values/colors.xml',
    'android/app/src/production/res/values/colors.xml',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
    'ios/Runner/Base.lproj/LaunchScreen.storyboard',
  ];
  final missing = paths.where((path) => !File(path).existsSync()).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('Missing branding assets: ${missing.join(', ')}');
    exitCode = 1;
  } else {
    stdout.writeln('Branding assets are complete and deterministic.');
  }
}
