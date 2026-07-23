import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_compression.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_constants.dart';

void main() {
  group('PointerFile QR support', () {
    test('reads QRCodeSupport and guide URL from Current', () {
      const text = '''
Current::QRCodeSupport::Yes
Current::scheduleQRGuideURL::bands70k://schedule-scan
Current::artistUrl::https://example.com/lineup.csv
''';
      final pointer = PointerFile.parse(text);
      expect(pointer.qrCodeSupport, isTrue);
      expect(pointer.scheduleQRGuideURL, 'bands70k://schedule-scan');
    });
  });

  group('ScheduleQrCompression', () {
    const bands = ['Absolute Darkness', 'Exhumed'];
    const venues = ['Rink', 'Pool', 'Theater', 'Ale & Anchor Pub'];

    test('round-trips slash dates through single QR payload', () {
      const csv = ''
          'Band,Location,Date,Day,Start Time,End Time,Type,Notes\n'
          'Absolute Darkness,Rink,01/26/2027,1/26,13:00,13:45,Show,\n'
          'Exhumed,Pool,01/26/2027,1/26,20:00,20:45,Show,\n';

      final payloads = ScheduleQrCompression.compressScheduleOneOrTwoQrs(
        csv,
        bands,
        venues,
      );
      expect(payloads, hasLength(1));
      expect(payloads.first.first, scheduleQrTypeFull);
      expect(payloads.first.length, lessThanOrEqualTo(scheduleQrMaxBytesPerBinaryQr));

      final body = payloads.first.sublist(1);
      final size = ByteData.sublistView(body).getUint32(0, Endian.little);
      expect(size, greaterThan(0));
      final inflated = ZLibCodec(raw: true).decode(body.sublist(4));
      final restored = utf8.decode(inflated);
      expect(restored, contains('01,01'));
      expect(restored, contains('02,02'));
      expect(restored, contains('13:'));
      expect(restored, contains('20:'));
    });

    test('shortens ISO dates like the mobile apps', () {
      expect(
        ScheduleQrCompression.shortenDateForQr('2027-01-26'),
        '1/26/27',
      );
    });

    test('strips trailing commas during preprocess', () {
      expect(
        ScheduleQrCompression.preprocessCsvForCompression('Show,,,'),
        'Show',
      );
    });
  });
}
