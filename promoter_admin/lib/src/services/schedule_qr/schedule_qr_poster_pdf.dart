import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Default Camera-app guide link for 70K when the pointer has QR support but no
/// explicit [scheduleQRGuideURL].
const scheduleQrDefaultGuideUrl = 'bands70k://schedule-scan';

/// Letter-size poster PDF for hallway printing — layout mirrors
/// build_70k_schedule_poster_pdf.py draw_poster_pdf.
class ScheduleQrPosterPdf {
  const ScheduleQrPosterPdf._();

  static const _printDpi = 300;
  static const _guidePosterWidthPt = 75.6; // 1.05 inch

  static Future<Uint8List> build({
    required String festivalName,
    required String scheduleChangeTitle,
    required List<Uint8List> qrImages,
    Uint8List? guideQrImage,
  }) async {
    if (qrImages.isEmpty) {
      throw StateError('At least one schedule QR image is required.');
    }

    final title = festivalName.trim().isEmpty
        ? 'Schedule QR Code'
        : '${festivalName.trim()} Schedule QR Code';
    final changeTitle = scheduleChangeTitle.trim().isEmpty
        ? 'Schedule Update'
        : scheduleChangeTitle.trim();

    final decodedQrs = qrImages.map(_decodePng).toList();
    final guideDecoded =
        guideQrImage == null ? null : _decodePng(guideQrImage);

    final regularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );

    final document = pw.Document(
      title: title,
      author: festivalName,
      creator: 'Open Metal Fest Admin',
      theme: theme,
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(56.16, 51.84, 56.16, 43.2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _HeaderSection(
                  title: title,
                  changeTitle: changeTitle,
                  includeGuideBullets: guideDecoded != null,
                ),
                pw.SizedBox(height: 20),
                pw.Expanded(
                  child: pw.LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints?.maxWidth ?? context.page.pageFormat.availableWidth;
                      final maxH = constraints?.maxHeight ?? context.page.pageFormat.availableHeight * 0.55;
                      return pw.Center(
                        child: _QrStack(
                          qrImages: decodedQrs,
                          guideImage: guideDecoded,
                          printDpi: _printDpi,
                          guidePosterWidthPt: _guidePosterWidthPt,
                          maxWidth: maxW * 0.96,
                          maxHeight: maxH * 0.96,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return document.save();
  }

  static img.Image _decodePng(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode QR PNG.');
    }
    return decoded;
  }
}

class _HeaderSection extends pw.StatelessWidget {
  _HeaderSection({
    required this.title,
    required this.changeTitle,
    required this.includeGuideBullets,
  });

  final String title;
  final String changeTitle;
  final bool includeGuideBullets;

  @override
  pw.Widget build(pw.Context context) {
    final bullets = includeGuideBullets
        ? const [
            'Launch the 70K Bands App',
            'Preferences > Scan QR Code Schedule',
            'Optional: scan the small Camera app QR, then the large schedule QR',
          ]
        : const [
            'Launch the 70K Bands App',
            'Preferences > Scan QR Code Schedule',
            'Scan the QR code below',
          ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Schedule update: $changeTitle',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'If your phone needs this schedule update and you do not have internet '
          'access:',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 10.5),
        ),
        pw.SizedBox(height: 8),
        for (final bullet in bullets)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              '•  $bullet',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10.5),
            ),
          ),
      ],
    );
  }
}

class _QrStack extends pw.StatelessWidget {
  _QrStack({
    required this.qrImages,
    required this.guideImage,
    required this.printDpi,
    required this.guidePosterWidthPt,
    required this.maxWidth,
    required this.maxHeight,
  });

  final List<img.Image> qrImages;
  final img.Image? guideImage;
  final int printDpi;
  final double guidePosterWidthPt;
  final double maxWidth;
  final double maxHeight;

  @override
  pw.Widget build(pw.Context context) {
    final baseRw = qrImages.map((im) => _physicalWidth(im)).toList();
    final baseRh = qrImages.map((im) => _physicalHeight(im)).toList();

    var guideRw = 0.0;
    var guideRh = 0.0;
    if (guideImage != null) {
      guideRw = guidePosterWidthPt;
      guideRh = _physicalHeight(guideImage!) *
          (guideRw / _physicalWidth(guideImage!));
    }

    final scaleFit = _fitScale(
      maxW: maxWidth,
      maxH: maxHeight,
      baseRw: baseRw,
      baseRh: baseRh,
      guideRw: guideRw,
      guideRh: guideRh,
      hasGuide: guideImage != null,
    );

    final labels = _scheduleLabels(
      qrCount: qrImages.length,
      hasGuide: guideImage != null,
    );

    final children = <pw.Widget>[];
    if (guideImage != null) {
      children.addAll([
        pw.Text(
          'Camera app',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Image(
          pw.MemoryImage(Uint8List.fromList(img.encodePng(guideImage!))),
          width: guideRw,
          height: guideRh,
        ),
        pw.SizedBox(height: 14),
      ]);
    }

    for (var i = 0; i < qrImages.length; i++) {
      if (qrImages.length > 1 || guideImage != null) {
        children.addAll([
          pw.Text(
            labels[i],
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
        ]);
      }
      final rw = baseRw[i] * scaleFit;
      final rh = baseRh[i] * scaleFit;
      children.add(
        pw.Image(
          pw.MemoryImage(Uint8List.fromList(img.encodePng(qrImages[i]))),
          width: rw,
          height: rh,
        ),
      );
      if (i < qrImages.length - 1) {
        children.add(pw.SizedBox(height: 18));
      }
    }

    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: children,
    );
  }

  double _physicalWidth(img.Image image) => image.width * 72.0 / printDpi;

  double _physicalHeight(img.Image image) => image.height * 72.0 / printDpi;

  List<String> _scheduleLabels({
    required int qrCount,
    required bool hasGuide,
  }) {
    if (qrCount == 1) {
      return [
        hasGuide ? 'Schedule data — scan this QR code.' : 'Scan this QR code.',
      ];
    }
    return hasGuide
        ? [
            'Schedule data — scan first QR code (chunk 1).',
            'Schedule data — scan second QR code (chunk 2).',
          ]
        : [
            'Scan first QR code (chunk 1).',
            'Scan second QR code (chunk 2).',
          ];
  }

  double _fitScale({
    required double maxW,
    required double maxH,
    required List<double> baseRw,
    required List<double> baseRh,
    required double guideRw,
    required double guideRh,
    required bool hasGuide,
  }) {
    double stackWidth(double scale) {
      final widths = baseRw.map((rw) => rw * scale).toList();
      if (hasGuide) widths.add(guideRw);
      return widths.isEmpty ? 0 : widths.reduce(math.max);
    }

    double stackHeight(double scale) {
      var h = 0.0;
      if (hasGuide) {
        h += 10 * 1.12 + 6 + guideRh + 14;
      } else if (baseRh.length > 1) {
        h += 10 * 1.12 + 6;
      }
      for (var i = 0; i < baseRh.length; i++) {
        if (baseRh.length > 1 || hasGuide) {
          h += 10 * 1.12 + 6;
        }
        h += baseRh[i] * scale;
        if (i < baseRh.length - 1) h += 18;
      }
      return h;
    }

    var lo = 0.01;
    var hi = 2.5;
    var scaleFit = 0.5;
    for (var i = 0; i < 48; i++) {
      final mid = (lo + hi) / 2;
      if (stackWidth(mid) <= maxW && stackHeight(mid) <= maxH) {
        scaleFit = mid;
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return scaleFit;
  }
}
