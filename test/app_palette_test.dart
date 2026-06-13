import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noteheaven/theme/app_palette.dart';

void main() {
  group('AppPalette.fromHex', () {
    test('parses 6-digit hex and assumes opaque', () {
      expect(AppPalette.fromHex('#FF0000'), const Color(0xFFFF0000));
      expect(AppPalette.fromHex('00FF00'), const Color(0xFF00FF00));
    });

    test('falls back to white on garbage input', () {
      expect(AppPalette.fromHex('not-a-color'), const Color(0xFFFFFFFF));
    });
  });

  group('AppPalette.resolve', () {
    test('light mode returns the literal swatch', () {
      expect(AppPalette.resolve('#FFE5EC', Brightness.light),
          AppPalette.fromHex('#FFE5EC'));
    });

    test('dark mode maps the default/white note to a dark surface', () {
      final resolved = AppPalette.resolve('#FFFFFF', Brightness.dark);
      expect(resolved.computeLuminance(), lessThan(0.2));
    });

    test('dark mode keeps coloured notes dark and legible', () {
      final resolved = AppPalette.resolve('#E3F2FD', Brightness.dark);
      expect(resolved.computeLuminance(), lessThan(0.3));
    });
  });

  group('AppPalette.onColor', () {
    test('chooses black on light backgrounds and white on dark', () {
      expect(AppPalette.onColor(const Color(0xFFFFFFFF)), Colors.black);
      expect(AppPalette.onColor(const Color(0xFF000000)), Colors.white);
    });
  });
}
