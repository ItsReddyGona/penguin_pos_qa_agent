import 'dart:io';

/// Helper to auto-detect and validate Flutter executable and PenguinPOS project locations.
class PathDetector {
  /// Detects the path to the `flutter` binary on the host system.
  static Future<String> detectFlutterPath() async {
    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      '/opt/homebrew/bin/flutter',
      '/usr/local/bin/flutter',
      if (home.isNotEmpty) '$home/.fvm/default/bin/flutter',
      if (home.isNotEmpty) '$home/fvm/default/bin/flutter',
      if (home.isNotEmpty) '$home/flutter/bin/flutter',
      if (home.isNotEmpty) '$home/development/flutter/bin/flutter',
    ];

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    try {
      final result = await Process.run('which', ['flutter']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty && await File(path).exists()) {
          return path;
        }
      }
    } catch (_) {}

    return 'flutter';
  }

  /// Detects the root directory of the PenguinPOS app.
  static Future<String> detectAppRoot() async {
    final home = Platform.environment['HOME'] ?? '';
    final candidates = <String>[
      '/Users/reddygona/Documents/PenguinPOS/penguin_pos',
      if (home.isNotEmpty) '$home/Documents/PenguinPOS/penguin_pos',
      if (home.isNotEmpty) '$home/Documents/penguin_pos',
      if (home.isNotEmpty) '$home/Documents/PenguinPOS_App',
      '../penguin_pos',
    ];

    for (final candidate in candidates) {
      final dir = Directory(candidate);
      if (await dir.exists()) {
        final pubspec = File('${dir.path}/pubspec.yaml');
        if (await pubspec.exists()) {
          return dir.absolute.path;
        }
      }
    }

    return candidates.first;
  }

  /// Verifies if a given Flutter executable path is valid.
  static Future<bool> isValidFlutterExecutable(String path) async {
    if (path.isEmpty) return false;
    if (path == 'flutter') return true;
    return File(path).exists();
  }

  /// Verifies if a given directory path is a valid PenguinPOS app root.
  static Future<bool> isValidAppRoot(String path) async {
    if (path.isEmpty) return false;
    final dir = Directory(path);
    if (!await dir.exists()) return false;
    final pubspec = File('${dir.path}/pubspec.yaml');
    return pubspec.exists();
  }
}
