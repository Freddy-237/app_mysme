import 'package:flutter/material.dart';

/// MystMe colour palette — light / white theme
abstract class AppColors {
  // Background
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5FA);
  static const Color surfaceVariant = Color(0xFFEDEDF3);

  // Primary accent — violet mystique
  static const Color primary = Color(0xFF5A2EBE);
  static const Color primaryLight = Color(0xFF7B5CF0);
  static const Color primaryDark = Color(0xFF431FA3);

  // Secondary accent — cyan spectral
  static const Color secondary = Color(0xFF0EA5C9);
  static const Color secondaryDark = Color(0xFF0284A8);

  // Semantic
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B80);
  static const Color textDisabled = Color(0xFFAAAAAA);

  // Chat bubbles
  static const Color bubbleSelf = Color(0xFF5A2EBE);
  static const Color bubbleOther = Color(0xFFEDEDF3);

  // Border / divider
  static const Color border = Color(0xFFE0E0E8);
  static const Color divider = Color(0xFFE8E8F0);

  // Gradient — header / cards
  static const Color primaryStart = Color(0xFF6A1BDB);
  static const Color primaryEnd = Color(0xFF9B59B6);
  static const Color deepPurple = Color(0xFF3A0D7A);

  // Overlay
  static const Color overlay = Color(0x33000000);
  static const Color shimmer = Color(0xFFE0E0E8);
}
