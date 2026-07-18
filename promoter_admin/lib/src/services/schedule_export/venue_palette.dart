import 'dart:math' as math;

import 'package:pdf/pdf.dart';

/// Shared venue accent palette for running-order exports.
///
/// Colors are **not** generated per festival — they cycle by venue index.
/// The list is ordered by aesthetic preference: the first entries are used most
/// often (typical festivals have few venues); later entries are intentional
/// overkill for huge multi-stage days.
///
/// PDF and HTML use different treatments of the same accents:
///
/// - **HTML (dark page):** saturated fills with light text.
/// - **PDF (white page):** saturated accents for borders / venue titles, and
///   opaque pastel fills mixed onto white so black event text stays readable.
///
/// Do not rely on [PdfColor] alpha for fills — many PDF viewers ignore it and
/// paint the full accent behind black text.
class VenuePalette {
  const VenuePalette._();

  /// Saturated accents (ARGB), ranked for everyday use then rarer venues.
  ///
  /// First eight match the original running-order palette.
  static const accents = <int>[
    // Preferred (original eight)
    0xFF2049B5, // 1  blue
    0xFF087757, // 2  green
    0xFFA64A08, // 3  burnt orange
    0xFF9A20B5, // 4  purple
    0xFF37465A, // 5  slate
    0xFFDF4C08, // 6  vivid orange
    0xFF8B2030, // 7  crimson
    0xFF176D87, // 8  teal
    // Extended overkill (rarely needed; hue-spaced off the lead eight)
    0xFF8A6E00, // 9  gold
    0xFF491A8A, // 10 deep violet
    0xFF285918, // 11 fern
    0xFF0B636B, // 12 ocean
    0xFF33660F, // 13 chartreuse
    0xFF18611E, // 14 jade
    0xFF7A1B6A, // 15 magenta
    0xFF302B6B, // 16 indigo
    0xFF16594E, // 17 viridian
    0xFF1B5930, // 18 pine
    0xFF6B1B6B, // 19 grape
    0xFF6B1B43, // 20 rose
  ];

  static int accentArgb(int venueIndex) =>
      accents[venueIndex % accents.length];

  static String accentHex(int venueIndex) {
    final value = accentArgb(venueIndex) & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  static PdfColor accentPdf(int venueIndex) =>
      PdfColor.fromInt(accentArgb(venueIndex));

  /// Opaque pastel for PDF event-block fills (safe under black text).
  ///
  /// [strength] is how much accent to mix onto white (0 = white, 1 = full).
  static PdfColor pdfFill(int venueIndex, {double strength = 0.14}) {
    final accent = accentPdf(venueIndex);
    final t = strength.clamp(0.0, 1.0);
    return PdfColor(
      accent.red * t + (1 - t),
      accent.green * t + (1 - t),
      accent.blue * t + (1 - t),
    );
  }

  /// Relative luminance (0–1) for contrast checks.
  static double luminance(PdfColor color) {
    double channel(double c) {
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(color.red) +
        0.7152 * channel(color.green) +
        0.0722 * channel(color.blue);
  }

  /// Contrast ratio of black text on [background] (higher is better).
  static double blackTextContrast(PdfColor background) {
    final lighter = luminance(background);
    const darker = 0.0; // black text
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Contrast ratio of white text on [background] (higher is better).
  static double whiteTextContrast(PdfColor background) {
    const lighter = 1.0; // white text
    final darker = luminance(background);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// CSS rules for HTML color mode (saturated venue / event backgrounds).
  static String htmlVenueCss() {
    final buffer = StringBuffer();
    for (var i = 0; i < accents.length; i++) {
      buffer.writeln('.venue-$i { background: ${accentHex(i)}; }');
    }
    return buffer.toString();
  }
}
