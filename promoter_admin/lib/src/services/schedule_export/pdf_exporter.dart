import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as image;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:promoter_admin/src/services/schedule_export/event_type_labeling.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_layout.dart';
import 'package:promoter_admin/src/services/schedule_export/venue_palette.dart';

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
          ? VenuePalette.accentPdf(venueIndex)
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

    // Later events first so an earlier block that shares a boundary paints on
    // top. Boxes are hard-capped at the next same-venue/lane start so short
    // slots (e.g. a 5-minute raffle) never spill over the following set.
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

      final nextStart = _nextBlockingStart(event, page);
      final freeUntilNext =
          (nextStart - event.startMinute) * minuteHeight - 1.2;
      // Grow into unused gap before the next event, but never past it.
      final maxHeight = math.max(8.0, freeUntilNext);
      final minSlot = math.max(8.0, slotHeight - 1.2);

      final typeLabel = labeling.eventLabel(event.source.type);
      final timeLines = event.timeLine(formatClock: _clock).split('\n');
      final bands = event.displayTitles
          .map((name) => name.toUpperCase())
          .toList();
      final notes = [
        for (final note in event.noteLines)
          if (event.bandNames.isNotEmpty ||
              !event.displayTitles.contains(note))
            note,
      ];

      // Name first (cuts favor the name); time/notes drop before names do.
      var showType = typeLabel != null;
      var showTime = true;
      var showNotes = notes.isNotEmpty;
      var nameSize = venueCount > 6 ? 6.5 : (venueCount > 4 ? 7.0 : 8.0);
      var timeSize = 6.0;
      var noteSize = 5.5;

      double estimate() => _estimateBoxHeight(
        laneWidth: laneWidth,
        nameSize: nameSize,
        timeSize: timeSize,
        noteSize: noteSize,
        timeLines: showTime ? timeLines.length : 0,
        typeLabel: showType,
        bands: bands,
        notes: showNotes ? notes.length : 0,
      );

      var estimated = estimate();
      while (estimated > maxHeight && nameSize > 3.6) {
        nameSize = math.max(3.6, nameSize - 0.4);
        timeSize = math.max(3.2, timeSize - 0.35);
        noteSize = math.max(3.0, noteSize - 0.3);
        estimated = estimate();
      }
      if (estimated > maxHeight && showNotes) {
        showNotes = false;
        estimated = estimate();
      }
      if (estimated > maxHeight && showType) {
        showType = false;
        estimated = estimate();
      }
      if (estimated > maxHeight && showTime) {
        showTime = false;
        estimated = estimate();
      }
      // Last resort: shrink name-only block a bit more.
      while (estimated > maxHeight && nameSize > 3.2) {
        nameSize = math.max(3.2, nameSize - 0.3);
        estimated = estimate();
      }
      final boxHeight = math.min(maxHeight, math.max(minSlot, estimated));

      final border = scheme.colorful
          ? VenuePalette.accentPdf(event.venueIndex)
          : scheme.blockBorder;
      // Opaque pastel — PdfColor alpha is unreliable in fills and was painting
      // full-strength accents under black text.
      final fill = scheme.colorful
          ? VenuePalette.pdfFill(event.venueIndex)
          : scheme.blockFill;

      children.add(
        pw.Positioned(
          left: left,
          top: top + 0.6,
          child: pw.Container(
            width: laneWidth - 0.5,
            height: boxHeight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: pw.BoxDecoration(
              color: fill,
              border: pw.Border.all(color: border, width: 0.9),
            ),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              mainAxisAlignment: pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < bands.length; i++)
                  pw.Text(
                    i < bands.length - 1 ? '${bands[i]} /' : bands[i],
                    textAlign: pw.TextAlign.center,
                    maxLines: 2,
                    style: pw.TextStyle(
                      color: scheme.blockText,
                      fontSize: nameSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                if (showType && typeLabel != null)
                  pw.Text(
                    typeLabel,
                    textAlign: pw.TextAlign.center,
                    maxLines: 1,
                    style: pw.TextStyle(
                      color: scheme.blockText,
                      fontSize: timeSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                if (showTime)
                  for (final line in timeLines)
                    pw.Text(
                      line,
                      textAlign: pw.TextAlign.center,
                      maxLines: 1,
                      style: pw.TextStyle(
                        color: scheme.blockText,
                        fontSize: timeSize,
                      ),
                    ),
                if (showNotes)
                  for (final note in notes)
                    pw.Text(
                      note,
                      textAlign: pw.TextAlign.center,
                      maxLines: 2,
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

  /// Earliest start of another event that must not be covered — same venue and
  /// overlapping lane — or the page end.
  static int _nextBlockingStart(
    RunningOrderEvent event,
    RunningOrderPage page,
  ) {
    var next = page.endMinute;
    for (final other in page.events) {
      if (identical(other, event)) continue;
      if (other.venueIndex != event.venueIndex) continue;
      if (other.startMinute <= event.startMinute) continue;
      // Different lanes can sit side by side; only same-lane (or full-width)
      // events block vertical growth.
      final sameLane =
          event.laneCount <= 1 ||
          other.laneCount <= 1 ||
          other.laneIndex == event.laneIndex;
      if (!sameLane) continue;
      next = math.min(next, other.startMinute);
    }
    return next;
  }

  static double _estimateBoxHeight({
    required double laneWidth,
    required double nameSize,
    required double timeSize,
    required double noteSize,
    required int timeLines,
    required bool typeLabel,
    required List<String> bands,
    required int notes,
  }) {
    final avgCharWidth = nameSize * 0.55;
    final charsPerLine = math.max(6, ((laneWidth - 6) / avgCharWidth).floor());
    var wrappedBandLines = 0;
    for (final band in bands) {
      wrappedBandLines += math.max(1, (band.length / charsPerLine).ceil());
    }
    return 3.0 +
        (timeLines + (typeLabel ? 1 : 0) + notes) * (timeSize + 1.2) +
        wrappedBandLines * (nameSize + 1.2);
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
