import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

const rosidLatestReleaseUrl =
    'https://github.com/tanzir71/rosid/releases/latest';

class AppMetadata {
  const AppMetadata({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  String get displayVersion =>
      buildNumber.isEmpty ? version : '$version+$buildNumber';
}

final appMetadataProvider = FutureProvider<AppMetadata>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return AppMetadata(
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );
});
