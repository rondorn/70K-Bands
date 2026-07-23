import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_poster_pdf.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_raster.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleQrPosterPdf', () {
    test('embeds guide and schedule QR images in one page', () async {
      final guide = ScheduleQrRaster.encodeGuideTextPng('bands70k://schedule-scan');
      final schedule =
          ScheduleQrRaster.encodeGuideTextPng('schedule-payload-placeholder');

      final bytes = await ScheduleQrPosterPdf.build(
        festivalName: '70,000 Tons',
        scheduleChangeTitle: 'Test update',
        qrImages: [schedule],
        guideQrImage: guide,
      );

      expect(bytes.sublist(0, 4), equals('%PDF'.codeUnits));
      final pdfText = String.fromCharCodes(bytes);
      expect(pdfText, contains('/Image'));
      expect(
        RegExp(r'/Subtype\s*/Image').allMatches(pdfText).length,
        greaterThanOrEqualTo(2),
      );
    });
  });
}
