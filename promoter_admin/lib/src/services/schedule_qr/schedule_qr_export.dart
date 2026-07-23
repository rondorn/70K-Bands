import 'dart:typed_data';

import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_compression.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_constants.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_csv.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_poster_pdf.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_raster.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';

/// Build a printable schedule QR poster PDF from the current testing schedule.
class ScheduleQrExport {
  const ScheduleQrExport._();

  static Future<Uint8List> buildPosterPdf({
    required List<ScheduleEvent> events,
    required List<String> bandNames,
    required String festivalName,
    required String scheduleChangeTitle,
    String? guideUrl,
    List<String>? venueNames,
  }) async {
    if (events.isEmpty) {
      throw StateError('No schedule events to export.');
    }
    if (bandNames.isEmpty) {
      throw StateError(
        'Artist lineup is required for QR band codes. Load the lineup first.',
      );
    }

    final csv = ScheduleQrCsv.fromEvents(events);
    final dataRows = csv
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    if (dataRows <= 1) {
      throw StateError('No schedule events remain after filtering unofficial rows.');
    }

    final venues = venueNames ?? scheduleQrVenueNames;
    final payloads = ScheduleQrCompression.compressScheduleOneOrTwoQrs(
      csv,
      bandNames,
      venues,
    );
    final qrImages = [
      for (final payload in payloads)
        ScheduleQrRaster.encodeBinaryPayloadPng(payload),
    ];

    Uint8List? guideImage;
    final trimmedGuide = (guideUrl?.trim().isNotEmpty ?? false)
        ? guideUrl!.trim()
        : scheduleQrDefaultGuideUrl;
    guideImage = ScheduleQrRaster.encodeGuideTextPng(trimmedGuide);

    return ScheduleQrPosterPdf.build(
      festivalName: festivalName,
      scheduleChangeTitle: scheduleChangeTitle,
      qrImages: qrImages,
      guideQrImage: guideImage,
    );
  }
}
