import 'package:flutter/material.dart';

/// Palette lifted from the React/Tailwind blueprint
/// (deep emerald headers, soft mint background, slate body text).
class AppColors {
  const AppColors._();

  // Brand greens
  static const Color primary = Color(0xFF1F7A4C); // emerald-700-ish brand
  static const Color primaryDark = Color(0xFF14512F);
  static const Color primaryDeep = Color(0xFF173326); // header text
  static const Color primarySoft = Color(0xFFE8F5EE);
  static const Color primaryBorder = Color(0xFFBBE5CE);

  // Surface
  static const Color background = Color(0xFFF6FAF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF1E293B); // slate-800
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color textMuted = Color(0xFF94A3B8); // slate-400

  // Accents (one per feature area, matching the web cards)
  static const Color crop = Color(0xFF059669);
  static const Color health = Color(0xFFE11D48);
  static const Color water = Color(0xFF0284C7);
  static const Color livestock = Color(0xFF9333EA);
  static const Color map = Color(0xFFEA580C);
  static const Color calendar = Color(0xFFCA8A04);
  static const Color soil = Color(0xFF0D9488);

  // Semantic
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF2563EB);
  static const Color neutral = Color(0xFF64748B);

  /// Lightweight alpha helper (kept dependency-free so the theme compiles on
  /// every Flutter 3.x version regardless of `Color` API deprecations).
  static Color faint(Color color, double opacity) => Color.fromARGB(
        (255 * opacity.clamp(0.0, 1.0)).round(),
        (color.value >> 16) & 0xff,
        (color.value >> 8) & 0xff,
        color.value & 0xff,
      );

  static Color shade(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
