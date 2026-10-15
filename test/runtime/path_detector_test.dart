import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_pos_qa_agent/runtime/path_detector.dart';

void main() {
  group('PathDetector', () {
    test('detectFlutterPath resolves non-empty flutter path', () async {
      final path = await PathDetector.detectFlutterPath();
      expect(path, isNotEmpty);
      expect(await PathDetector.isValidFlutterExecutable(path), isTrue);
    });

    test('detectAppRoot detects valid penguin_pos if present', () async {
      final appRoot = await PathDetector.detectAppRoot();
      expect(appRoot, isNotEmpty);
      final hasPubspec = await File('$appRoot/pubspec.yaml').exists();
      if (hasPubspec) {
        expect(await PathDetector.isValidAppRoot(appRoot), isTrue);
      }
    });

    test('isValidAppRoot returns false for invalid directory', () async {
      expect(await PathDetector.isValidAppRoot('/non/existent/path'), isFalse);
      expect(await PathDetector.isValidAppRoot(''), isFalse);
    });

    test('isValidFlutterExecutable validates correctly', () async {
      expect(await PathDetector.isValidFlutterExecutable('flutter'), isTrue);
      expect(await PathDetector.isValidFlutterExecutable(''), isFalse);
      expect(
        await PathDetector.isValidFlutterExecutable(
          '/non/existent/flutter_bin',
        ),
        isFalse,
      );
    });
  });
}
