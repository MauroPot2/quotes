import 'dart:io';

Future<void> main() async {
  // flutter_launcher_icons 0.14.4 rewrites unrelated ASSETCATALOG settings.
  // This project already uses AppIcon, so preserve its Xcode configuration.
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  final original = await project.readAsBytes();
  try {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'flutter_launcher_icons'],
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await process.exitCode;
  } finally {
    await project.writeAsBytes(original);
  }
}
