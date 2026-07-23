import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_constants.dart';
import 'package:qr/qr.dart';

/// Rasterize schedule QR symbols — matches ScheduleQRShareActivity and
/// build_70k_schedule_poster_pdf.py encode_qr_raster.
class ScheduleQrRaster {
  const ScheduleQrRaster._();

  static Uint8List encodeBinaryPayloadPng(Uint8List payload) {
    final qrCode = QrCode.fromUint8List(
      data: payload,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    return _encodeQrRasterPng(qrCode, scheduleQrTargetPx);
  }

  static Uint8List encodeGuideTextPng(String guideUrl) {
    final qrCode = QrCode.fromData(
      data: guideUrl,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );
    return _encodeQrRasterPng(qrCode, scheduleQrGuideTargetPx);
  }

  static Uint8List _encodeQrRasterPng(QrCode qrCode, int targetPx) {
    final qrImage = QrImage(qrCode);
    final n = qrImage.moduleCount;
    final scale = [
      scheduleQrMinPixelsPerModule,
      targetPx ~/ n,
      1,
    ].reduce((a, b) => a > b ? a : b);
    final symbolPx = n * scale;
    final borderPx = scheduleQrQuietZoneModules * scale;
    final total = symbolPx + 2 * borderPx;

    final image = img.Image(width: total, height: total);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final color = qrImage.isDark(y, x)
            ? img.ColorRgb8(0, 0, 0)
            : img.ColorRgb8(255, 255, 255);
        final x0 = borderPx + x * scale;
        final y0 = borderPx + y * scale;
        for (var dy = 0; dy < scale; dy++) {
          for (var dx = 0; dx < scale; dx++) {
            image.setPixel(x0 + dx, y0 + dy, color);
          }
        }
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }
}
