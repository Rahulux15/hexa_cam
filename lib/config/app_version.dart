import 'package:package_info_plus/package_info_plus.dart';

/// Version and build from [pubspec.yaml] via [PackageInfo.fromPlatform].
abstract final class AppVersion {
  AppVersion._();

  static String formatLabel(PackageInfo info) {
    final b = info.buildNumber.trim();
    if (b.isEmpty) return info.version;
    return '${info.version} ($b)';
  }
}
