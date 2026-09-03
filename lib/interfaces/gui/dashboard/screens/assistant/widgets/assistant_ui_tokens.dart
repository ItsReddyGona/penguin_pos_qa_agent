import 'package:flutter/material.dart';

/// Shared visual tokens for the assistant workspace.
///
/// Keeping these values here makes the PenguinPOS-inspired assistant UI easy
/// to tune without repeating literal colours throughout every widget.
abstract final class AssistantUiTokens {
  static const Color canvas = Color(0xFFFDFBF7);
  static const Color surface = Colors.white;
  static const Color mutedSurface = Color(0xFFF6F4F0);
  static const Color subtleSurface = Color(0xFFF8FAF9);
  static const Color border = Color(0xFFC7C9C4);
  static const Color subtleBorder = Color(0xFFD9DDD8);
  static const Color divider = Color(0xFFE8E6E1);
  static const Color text = Color(0xFF2C302E);
  static const Color secondaryText = Color(0xFF494C4A);
  static const Color mutedText = Color(0xFF787A76);
  static const Color accent = Color(0xFF658A7A);
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFC62828);

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius compactRadius = BorderRadius.all(
    Radius.circular(10),
  );
}
