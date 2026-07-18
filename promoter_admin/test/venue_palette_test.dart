import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:promoter_admin/src/services/schedule_export/venue_palette.dart';

void main() {
  test('keeps twenty ranked accents with the original eight first', () {
    expect(VenuePalette.accents, hasLength(20));
    expect(VenuePalette.accents.take(8), [
      0xFF2049B5,
      0xFF087757,
      0xFFA64A08,
      0xFF9A20B5,
      0xFF37465A,
      0xFFDF4C08,
      0xFF8B2030,
      0xFF176D87,
    ]);
  });

  test('PDF fills keep strong contrast for black text', () {
    for (var i = 0; i < VenuePalette.accents.length; i++) {
      final fill = VenuePalette.pdfFill(i);
      final contrast = VenuePalette.blackTextContrast(fill);
      expect(
        contrast,
        greaterThan(7.0),
        reason: 'venue $i fill contrast was $contrast',
      );
    }
  });

  test('HTML accents keep usable contrast for white text', () {
    for (var i = 0; i < VenuePalette.accents.length; i++) {
      final accent = VenuePalette.accentPdf(i);
      final contrast = VenuePalette.whiteTextContrast(accent);
      // Original #6 vivid orange is a known ~4.0:1 (fine for bold/large labels).
      // Extended accents target normal-text AA (4.5:1).
      final minContrast = i < 8 ? 3.0 : 4.5;
      expect(
        contrast,
        greaterThanOrEqualTo(minContrast),
        reason: 'venue $i accent white-text contrast was $contrast '
            '(${VenuePalette.accentHex(i)})',
      );
    }
  });

  test('accents are pairwise distinct', () {
    final unique = VenuePalette.accents.toSet();
    expect(unique, hasLength(VenuePalette.accents.length));
  });

  test('HTML CSS lists every accent class', () {
    final css = VenuePalette.htmlVenueCss();
    for (var i = 0; i < VenuePalette.accents.length; i++) {
      expect(
        css,
        contains('.venue-$i { background: ${VenuePalette.accentHex(i)}; }'),
      );
    }
  });

  test('extended accents stay hue-separated from the rest of the palette', () {
    double hue(PdfColor c) {
      final r = c.red;
      final g = c.green;
      final b = c.blue;
      final max = math.max(r, math.max(g, b));
      final min = math.min(r, math.min(g, b));
      final d = max - min;
      if (d < 1e-9) return 0;
      double h;
      if (max == r) {
        h = ((g - b) / d) % 6;
      } else if (max == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h *= 60;
      if (h < 0) h += 360;
      return h;
    }

    double hueGap(double a, double b) {
      final d = (a - b).abs();
      return math.min(d, 360 - d);
    }

    for (var i = 8; i < VenuePalette.accents.length; i++) {
      final hi = hue(VenuePalette.accentPdf(i));
      for (var j = 0; j < VenuePalette.accents.length; j++) {
        if (i == j) continue;
        final gap = hueGap(hi, hue(VenuePalette.accentPdf(j)));
        expect(
          gap,
          greaterThanOrEqualTo(7.0),
          reason: 'venues $i and $j hue gap $gap° too small '
              '(${VenuePalette.accentHex(i)} vs ${VenuePalette.accentHex(j)})',
        );
      }
    }
  });
}
