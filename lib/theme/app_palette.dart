import 'package:flutter/material.dart';

/// Centralised colour logic for note backgrounds.
///
/// Notes store a light `#RRGGBB` hex value. In dark mode we derive a deep,
/// legible variant from the same hue instead of just darkening the pastel
/// (which previously left "white" notes near-white and unreadable on a dark
/// background).
class AppPalette {
  AppPalette._();

  static const Color seed = Color(0xFF6750A4);

  /// Curated note background swatches (light-mode hex values).
  static const List<String> noteColors = [
    '#FFFFFF', // default / surface
    '#FFE5EC', // rose
    '#FFF3D6', // amber
    '#E8F5E9', // green
    '#E3F2FD', // blue
    '#F3E5F5', // purple
    '#FFE0CC', // peach
    '#E0F7FA', // teal
  ];

  /// Text colour swatches for the in-note title/body colour pickers.
  static const List<Color> textColors = [
    Color(0xFF1C1B1F),
    Color(0xFFB3261E),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF6A1B9A),
    Color(0xFFE65100),
    Color(0xFF00838F),
    Color(0xFFC2185B),
  ];

  static Color fromHex(String hex) {
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return Color(parsed ?? 0xFFFFFFFF);
  }

  static bool isDefault(String hex) =>
      hex.toUpperCase() == '#FFFFFF' || hex.isEmpty;

  /// Resolves the actual card/background colour for the current brightness.
  static Color resolve(String hex, Brightness brightness) {
    final base = fromHex(hex);
    if (brightness == Brightness.light) return base;

    // Dark mode: keep the hue, drop to a deep tone with gentle saturation.
    final hsl = HSLColor.fromColor(base);
    if (isDefault(hex) || hsl.saturation < 0.05) {
      return const Color(0xFF26242B); // neutral dark surface
    }
    return hsl
        .withSaturation((hsl.saturation * 0.55).clamp(0.0, 1.0))
        .withLightness(0.22)
        .toColor();
  }

  /// Best-contrast on-colour (black/white) for text drawn over [background].
  static Color onColor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
