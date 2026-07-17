import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:promoter_admin/src/services/schedule_export/event_type_labeling.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_layout.dart';

/// PDF color accents. The printed running-order layout always uses a white
/// page (matching the official festival PDF); [colorful] only tints venue
/// headers and event borders.
class _PdfScheme {
  const _PdfScheme({
    required this.text,
    required this.muted,
    required this.grid,
    required this.halfGrid,
    required this.blockBorder,
    required this.blockFill,
    required this.blockText,
    required this.colorful,
  });

  final PdfColor text;
  final PdfColor muted;
  final PdfColor grid;
  final PdfColor halfGrid;
  final PdfColor blockBorder;
  final PdfColor blockFill;
  final PdfColor blockText;
  final bool colorful;

  static const monochrome = _PdfScheme(
    text: PdfColors.black,
    muted: PdfColors.black,
    grid: PdfColors.black,
    halfGrid: PdfColors.black,
    blockBorder: PdfColors.black,
    blockFill: PdfColors.white,
    blockText: PdfColors.black,
    colorful: false,
  );

  static const color = _PdfScheme(
    text: PdfColors.black,
    muted: PdfColor.fromInt(0xFF333333),
    grid: PdfColor.fromInt(0xFF222222),
    halfGrid: PdfColor.fromInt(0xFF666666),
    blockBorder: PdfColor.fromInt(0xFF222222),
    blockFill: PdfColors.white,
    blockText: PdfColors.black,
    colorful: true,
  );
}

class PdfExporter {
  const PdfExporter._();

  static const _venueColors = [
    PdfColor.fromInt(0xFF2049B5),
    PdfColor.fromInt(0xFF087757),
    PdfColor.fromInt(0xFFA64A08),
    PdfColor.fromInt(0xFF9A20B5),
    PdfColor.fromInt(0xFF37465A),
    PdfColor.fromInt(0xFFDF4C08),
    PdfColor.fromInt(0xFF8B2030),
    PdfColor.fromInt(0xFF176D87),
  ];

  static Future<Uint8List> build({
    required RunningOrderLayout layout,
    required String festivalName,
    Uint8List? logoBytes,
    bool useColor = false,
    EventTypeLabeling labeling = EventTypeLabeling.mixed,
  }) async {
    final scheme = useColor ? _PdfScheme.color : _PdfScheme.monochrome;
    final regularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
    final document = pw.Document(
      title: '$festivalName Running Order',
      author: festivalName,
      creator: 'Open Metal Fest Admin',
    );
    final preparedLogo = !useColor && logoBytes != null
        ? _grayscale(logoBytes)
        : logoBytes;
    final logo = preparedLogo == null ? null : pw.MemoryImage(preparedLogo);

    for (var index = 0; index < layout.pages.length; index++) {
      final page = layout.pages[index];
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.zero,
          theme: theme,
          build: (_) => _page(
            page,
            logo: logo,
            scheme: scheme,
            labeling: labeling,
            pageNumber: index + 1,
            pageCount: layout.pages.length,
          ),
        ),
      );
    }
    return document.save();
  }

  static pw.Widget _page(
    RunningOrderPage page, {
    required pw.MemoryImage? logo,
    required _PdfScheme scheme,
    required EventTypeLabeling labeling,
    required int pageNumber,
    required int pageCount,
  }) {
    // US Letter portrait — matches the official running-order PDF.
    const pageWidth = 612.0;
    const pageHeight = 792.0;
    const margin = 28.0;
    const gutterWidth = 28.0;
    // Logo sits to the left of the day title (not stacked above it) so the
    // schedule grid keeps the vertical space.
    const logoColumnWidth = 110.0;
    final typeHeaderHeight = labeling.pageHeaderLabel == null ? 0.0 : 16.0;
    final titleHeight = 72.0 + typeHeaderHeight;
    const venueHeight = 28.0;
    const footerHeight = 16.0;
    final scheduleTop = margin + titleHeight + venueHeight;
    final scheduleHeight = pageHeight - scheduleTop - margin - footerHeight;
    final contentLeft = margin + gutterWidth;
    final contentWidth = pageWidth - (margin * 2) - (gutterWidth * 2);
    final venueCount = page.venues.isEmpty ? 1 : page.venues.length;
    final venueWidth = contentWidth / venueCount;
    final minuteHeight = scheduleHeight / page.durationMinutes;
    final venueNameSize = venueCount > 6 ? 7.0 : (venueCount > 4 ? 8.0 : 10.0);

    final dayBlock = <pw.Widget>[
      if (labeling.pageHeaderLabel != null) ...[
        pw.Text(
          labeling.pageHeaderLabel!,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: scheme.text,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        pw.SizedBox(height: 2),
      ],
      pw.Text(
        page.day.toUpperCase(),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: scheme.text,
          fontSize: 36,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.5,
          lineSpacing: 0,
        ),
      ),
      if (page.displayDate.isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          page.displayDate,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            color: scheme.text,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ];

    final children = <pw.Widget>[
      pw.Positioned(
        left: margin,
        top: margin,
        right: margin,
        child: pw.SizedBox(
          height: titleHeight,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: logoColumnWidth,
                height: titleHeight - 4,
                child: logo == null
                    ? pw.SizedBox()
                    : pw.Image(
                        logo,
                        fit: pw.BoxFit.contain,
                        alignment: pw.Alignment.centerLeft,
                      ),
              ),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: dayBlock,
                ),
              ),
              // Matching spacer keeps DAY visually centered on the page.
              pw.SizedBox(width: logoColumnWidth),
            ],
          ),
        ),
      ),
    ];

    for (var venueIndex = 0; venueIndex < page.venues.length; venueIndex++) {
      final venue = page.venues[venueIndex];
      final headerColor = scheme.colorful
          ? _venueColors[venueIndex % _venueColors.length]
          : scheme.text;
      // Deck/location subtitles are omitted until we have a real data source;
      // venue strings may still contain "(Deck …)" but we only show the name.
      children.add(
        pw.Positioned(
          left: contentLeft + venueIndex * venueWidth,
          top: margin + titleHeight,
          child: pw.SizedBox(
            width: venueWidth,
            height: venueHeight,
            child: pw.Align(
              alignment: pw.Alignment.bottomCenter,
              child: pw.Text(
                venue.name.toUpperCase(),
                textAlign: pw.TextAlign.center,
                maxLines: 2,
                style: pw.TextStyle(
                  color: headerColor,
                  fontSize: venueNameSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Half-hour dashed lines first so solid hour lines paint on top.
    for (
      var minute = page.startMinute + 30;
      minute < page.endMinute;
      minute += 60
    ) {
      final top = scheduleTop + (minute - page.startMinute) * minuteHeight;
      children.add(
        pw.Positioned(
          left: contentLeft,
          top: top,
          child: pw.CustomPaint(
            size: PdfPoint(contentWidth, 1),
            painter: (canvas, size) {
              canvas
                ..setStrokeColor(scheme.halfGrid)
                ..setLineWidth(0.45)
                ..setLineDashPattern(const <num>[2.5, 1.8])
                ..drawLine(0, 0.5, size.x, 0.5)
                ..strokePath()
                ..setLineDashPattern();
            },
          ),
        ),
      );
    }

    for (
      var minute = page.startMinute;
      minute <= page.endMinute;
      minute += 60
    ) {
      final top = scheduleTop + (minute - page.startMinute) * minuteHeight;
      final label = _hourLabel(minute);
      children.addAll([
        pw.Positioned(
          left: margin,
          top: top - 4,
          child: pw.SizedBox(
            width: gutterWidth - 4,
            child: pw.Text(
              label,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(color: scheme.text, fontSize: 7),
            ),
          ),
        ),
        pw.Positioned(
          right: margin,
          top: top - 4,
          child: pw.SizedBox(
            width: gutterWidth - 4,
            child: pw.Text(
              label,
              style: pw.TextStyle(color: scheme.text, fontSize: 7),
            ),
          ),
        ),
        pw.Positioned(
          left: contentLeft,
          top: top,
          child: pw.SizedBox(
            width: contentWidth,
            height: 0.7,
            child: pw.Container(color: scheme.grid),
          ),
        ),
      ]);
    }

    for (var venueIndex = 0; venueIndex <= page.venues.length; venueIndex++) {
      children.add(
        pw.Positioned(
          left: contentLeft + venueIndex * venueWidth,
          top: scheduleTop,
          child: pw.SizedBox(
            width: 0.55,
            height: scheduleHeight,
            child: pw.Container(color: scheme.grid),
          ),
        ),
      );
    }

    // Draw later events first so earlier blocks (which may grow to fit names)
    // stay readable on top when slots are short.
    final drawOrder = [...page.events]
      ..sort((a, b) {
        final byStart = b.startMinute.compareTo(a.startMinute);
        if (byStart != 0) return byStart;
        return b.laneIndex.compareTo(a.laneIndex);
      });

    for (final event in drawOrder) {
      final top =
          scheduleTop + (event.startMinute - page.startMinute) * minuteHeight;
      final slotHeight = event.durationMinutes * minuteHeight;
      final laneCount = event.laneCount < 1 ? 1 : event.laneCount;
      final laneWidth = (venueWidth - 3) / laneCount;
      final left =
          contentLeft +
          event.venueIndex * venueWidth +
          1.5 +
          event.laneIndex * laneWidth;

      final typeLabel = labeling.eventLabel(event.source.type);
      final timeLines = event.timeLine(formatClock: _clock).split('\n');
      final bands = event.displayTitles
          .map((name) => name.toUpperCase())
          .toList();
      final notes = event.noteLines;
      final contentLines =
          timeLines.length +
          (typeLabel == null ? 0 : 1) +
          bands.length +
          notes.length;

      // Prefer fitting inside the time slot; never clip names — grow the box
      // when a narrow column wraps text on a long day (short minuteHeight).
      final available = slotHeight < 14 ? 14.0 : slotHeight - 1.2;
      var nameSize = venueCount > 6 ? 6.5 : (venueCount > 4 ? 7.0 : 8.0);
      var timeSize = 6.0;
      var noteSize = 5.5;
      if (contentLines > 3 || laneCount > 1 || available < 28) {
        nameSize = 5.5;
        timeSize = 5.0;
        noteSize = 4.8;
      }
      if (contentLines > 5 || available < 20 || venueCount > 5) {
        nameSize = 5.0;
        timeSize = 4.6;
        noteSize = 4.4;
      }
      // Rough wrap estimate for narrow lanes (avg ~4.5pt per glyph at 5–6pt).
      final avgCharWidth = nameSize * 0.55;
      final charsPerLine = math.max(6, ((laneWidth - 6) / avgCharWidth).floor());
      var wrappedBandLines = 0;
      for (final band in bands) {
        wrappedBandLines += math.max(1, (band.length / charsPerLine).ceil());
      }
      final estimated =
          4.0 +
          (timeLines.length + (typeLabel == null ? 0 : 1) + notes.length) *
              (timeSize + 1.4) +
          wrappedBandLines * (nameSize + 1.4);

      final border = scheme.colorful
          ? _venueColors[event.venueIndex % _venueColors.length]
          : scheme.blockBorder;
      final fill = scheme.colorful
          ? PdfColor(border.red, border.green, border.blue, 0.08)
          : scheme.blockFill;

      children.add(
        pw.Positioned(
          left: left,
          top: top + 0.6,
          child: pw.Container(
            width: laneWidth - 0.5,
            // Min height follows the time slot; no max height so band names
            // are never clipped when text wraps in a short slot.
            constraints: pw.BoxConstraints(
              minHeight: math.max(available, estimated),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: pw.BoxDecoration(
              color: fill,
              border: pw.Border.all(color: border, width: 0.9),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              mainAxisAlignment: pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                for (final line in timeLines)
                  pw.Text(
                    line,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: scheme.blockText,
                      fontSize: timeSize,
                    ),
                  ),
                if (typeLabel != null)
                  pw.Text(
                    typeLabel,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: scheme.blockText,
                      fontSize: timeSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                for (var i = 0; i < bands.length; i++)
                  pw.Text(
                    i < bands.length - 1 ? '${bands[i]} /' : bands[i],
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: scheme.blockText,
                      fontSize: nameSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  for (final note in notes)
                    if (event.bandNames.isNotEmpty ||
                        !event.displayTitles.contains(note))
                      pw.Text(
                        note,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: scheme.blockText,
                          fontSize: noteSize,
                        ),
                      ),
              ],
            ),
          ),
        ),
      );
    }

    if (pageCount > 1) {
      children.add(
        pw.Positioned(
          left: margin,
          right: margin,
          bottom: 8,
          child: pw.Text(
            '$pageNumber of $pageCount',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(color: scheme.muted, fontSize: 7),
          ),
        ),
      );
    }

    return pw.Container(
      width: pageWidth,
      height: pageHeight,
      color: PdfColors.white,
      child: pw.Stack(children: children),
    );
  }

  static String _hourLabel(int timelineMinute) {
    final hour = (timelineMinute ~/ 60) % 24;
    return '${hour.toString().padLeft(2, '0')}:00';
  }

  static String _clock(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    // Keep non-clock labels (e.g. Sunrise) readable; otherwise use dotted times.
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (match == null) return trimmed;
    return '${match.group(1)!.padLeft(2, '0')}.${match.group(2)}';
  }

  static Uint8List _grayscale(Uint8List bytes) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null) return bytes;
    return Uint8List.fromList(image.encodePng(image.grayscale(decoded)));
  }
}
