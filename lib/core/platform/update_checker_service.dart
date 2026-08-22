import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Details about an available app update, as published on MiarhPen's
/// GitHub Releases page (there is no Play Store listing to poll instead —
/// the app is distributed as a sideloaded APK).
class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String releaseUrl;
  final String? apkDownloadUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseUrl,
    this.apkDownloadUrl,
  });
}

/// Checks GitHub's "latest release" API for a newer MiarhPen version than
/// the one currently installed.
///
/// Only "checked successfully and you're already on the latest version" is
/// reported as a `null` result. A genuine failure to check (no internet,
/// GitHub unreachable, a non-200 response, a tag that doesn't parse as a
/// version) is thrown instead of also collapsing to `null` — those two
/// outcomes look identical to the user otherwise ("Unable to check" and
/// "you're up to date" would render the exact same way), which is exactly
/// what made a real connectivity problem invisible rather than reported.
/// This is only ever triggered by an explicit visit to the About screen —
/// never at app startup — so letting it throw can't break anything else.
class UpdateCheckerService {
  static const _repo = 'Eph0714/MiarhPen';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  Future<UpdateInfo?> checkForUpdate() async {
    final response = await http
        .get(
          Uri.parse(_apiUrl),
          // GitHub's API rejects requests with no User-Agent header.
          headers: const {
            'User-Agent': 'MiarhPen-UpdateChecker',
            'Accept': 'application/vnd.github+json',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'GitHub returned HTTP ${response.statusCode} for the latest release.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, Object?>;
    final tagName = body['tag_name'] as String?;
    final htmlUrl = body['html_url'] as String?;
    if (tagName == null || htmlUrl == null) {
      throw Exception(
        'GitHub\'s release response was missing expected fields.',
      );
    }

    final latestVersion = _parseSemver(tagName);
    if (latestVersion == null) {
      throw Exception('Could not parse a version number from tag "$tagName".');
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (!_isNewer(latestVersion, currentVersion)) return null;

    String? apkUrl;
    final assets = body['assets'] as List<Object?>?;
    if (assets != null) {
      for (final asset in assets) {
        final map = asset as Map<String, Object?>;
        final name = map['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = map['browser_download_url'] as String?;
          break;
        }
      }
    }

    return UpdateInfo(
      latestVersion: latestVersion,
      currentVersion: currentVersion,
      releaseUrl: htmlUrl,
      apkDownloadUrl: apkUrl,
    );
  }

  /// Extracts a clean `X.Y.Z` from a release tag like `v1.0.2` or
  /// `v1.0.1-947abf0` (older releases in this project's history appended
  /// a commit hash — tolerated here so update checks don't just start
  /// working from the next tag onward). Returns null if nothing
  /// version-shaped is found.
  static String? _parseSemver(String tagName) {
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(tagName);
    if (match == null) return null;
    return '${match[1]}.${match[2]}.${match[3]}';
  }

  /// Simple `X.Y.Z` comparison, missing/non-numeric parts treated as 0.
  static bool _isNewer(String latest, String current) {
    final latestParts = _parts(latest);
    final currentParts = _parts(current);
    for (var i = 0; i < 3; i++) {
      if (latestParts[i] != currentParts[i]) {
        return latestParts[i] > currentParts[i];
      }
    }
    return false;
  }

  static List<int> _parts(String version) {
    final segments = version.split('.');
    return List.generate(3, (i) {
      if (i >= segments.length) return 0;
      return int.tryParse(segments[i]) ?? 0;
    });
  }
}
