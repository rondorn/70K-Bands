import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_constants.dart';

/// Binary schedule QR payloads — mirrors ScheduleQRCompression.java and
/// build_70k_schedule_poster_pdf.py.
class ScheduleQrCompression {
  const ScheduleQrCompression._();

  static final _trailingCommas = RegExp(r',+$');

  static Uint8List compressForQr(Uint8List source) {
    final compressed = ZLibCodec(raw: true).encode(source);
    final header = ByteData(4)..setUint32(0, source.length, Endian.little);
    return Uint8List.fromList([
      ...header.buffer.asUint8List(),
      ...compressed,
    ]);
  }

  static String preprocessCsvForCompression(String csv) {
    final out = csv.replaceAll(scheduleQrDropboxPrefix, scheduleQrDropboxPlaceholder);
    return out
        .split('\n')
        .map((line) => line.replaceAll(_trailingCommas, ''))
        .join('\n');
  }

  static String shortenDateForQr(String date) {
    final trimmed = date.trim();
    if (trimmed.isEmpty) return date;

    final isoParts = trimmed.split('-');
    if (isoParts.length == 3) {
      final y = int.tryParse(isoParts[0].trim());
      final m = int.tryParse(isoParts[1].trim());
      final d = int.tryParse(isoParts[2].trim());
      if (y != null &&
          m != null &&
          d != null &&
          y >= 2000 &&
          y <= 2099 &&
          m >= 1 &&
          m <= 12 &&
          d >= 1 &&
          d <= 31) {
        return '$m/$d/${y % 100}';
      }
    }

    final parts = trimmed.split('/');
    if (parts.length != 3) return date;
    final m = int.tryParse(parts[0].trim());
    final d = int.tryParse(parts[1].trim());
    final y = int.tryParse(parts[2].trim());
    if (m == null ||
        d == null ||
        y == null ||
        m < 1 ||
        m > 12 ||
        d < 1 ||
        d > 31 ||
        y < 2000 ||
        y > 2099) {
      return date;
    }
    return '$m/$d/${y % 100}';
  }

  static String shortenTimeForQr(String time) {
    final trimmed = time.trim();
    if (trimmed.isEmpty) return time;
    final parts = trimmed.split(':');
    if (parts.length != 2) return time;
    final h = int.tryParse(parts[0].trim());
    if (h == null || h < 0 || h > 23) return time;
    final m = int.tryParse(parts[1].trim());
    if (m == null || m < 0 || m > 59) return time;
    return switch (m) {
      0 => '$h:',
      15 => '$h:1',
      30 => '$h:2',
      45 => '$h:3',
      _ => time,
    };
  }

  static String shortenDayForQr(String day) {
    final trimmed = day.trim();
    if (trimmed.startsWith('Day ') && trimmed.length > 4) {
      final suffix = trimmed.substring(4).trim();
      if (int.tryParse(suffix) != null) return suffix;
    }
    return day;
  }

  static String twoDigitCode(int index) {
    final n = index + 1;
    if (n < 1 || n > 99) return '';
    return n.toString().padLeft(2, '0');
  }

  static String oneDigitCodeForType(int index) {
    if (index >= 0 && index < 9) return '${index + 1}';
    return '';
  }

  static String compressBandColumn(String value, List<String> bandNames) {
    final trimmed = value.trim();
    for (var i = 0; i < bandNames.length; i++) {
      if (trimmed.toLowerCase() == bandNames[i].trim().toLowerCase()) {
        return twoDigitCode(i);
      }
    }
    return value;
  }

  static String compressLocationColumn(String value, List<String> venueNames) {
    for (var i = 0; i < venueNames.length; i++) {
      if (value.toLowerCase() == venueNames[i].toLowerCase()) {
        return twoDigitCode(i);
      }
    }
    return value;
  }

  static String compressTypeColumn(String value, List<String> eventTypes) {
    for (var i = 0; i < eventTypes.length; i++) {
      if (value.toLowerCase() == eventTypes[i].toLowerCase()) {
        return oneDigitCodeForType(i);
      }
    }
    return value;
  }

  static String buildCsvLine(List<String> fields) =>
      fields.map(escapeCsv).join(',');

  static Uint8List compressScheduleForQrData(
    String csvString,
    List<String> bandNames,
    List<String> venueNames,
  ) {
    final preprocessed = preprocessCsvForCompression(csvString);
    final lines = preprocessed.split('\n');
    final outLines = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) continue;
      final fields = parseCsvLine(trimmed);
      if (fields.length < 7) {
        outLines.add(lines[i]);
        continue;
      }
      if (i == 0 && fields.isNotEmpty && fields[0].toLowerCase() == 'band') {
        outLines.add(scheduleQrHeader);
        continue;
      }
      final notes = fields.length > 8 ? fields[8] : '';
      outLines.add(
        buildCsvLine([
          compressBandColumn(fields[0], bandNames),
          compressLocationColumn(fields[1], venueNames),
          shortenDateForQr(fields[2]),
          shortenDayForQr(fields[3]),
          shortenTimeForQr(fields[4]),
          shortenTimeForQr(fields[5]),
          compressTypeColumn(fields[6], scheduleQrEventTypeOrder),
          notes,
        ]),
      );
    }
    final csvData = utf8.encode(outLines.join('\n'));
    return compressForQr(Uint8List.fromList(csvData));
  }

  static Uint8List wrapType(int type, Uint8List body) =>
      Uint8List.fromList([type & 0xFF, ...body]);

  static List<Uint8List> compressScheduleOneOrTwoQrs(
    String fullScheduleCsv,
    List<String> bandNames,
    List<String> venueNames,
  ) {
    final singleBody = compressScheduleForQrData(
      fullScheduleCsv,
      bandNames,
      venueNames,
    );
    final fullPayload = wrapType(scheduleQrTypeFull, singleBody);
    if (fullPayload.length <= scheduleQrMaxBytesPerBinaryQr) {
      return [fullPayload];
    }

    final preprocessed = preprocessCsvForCompression(fullScheduleCsv);
    final lines = preprocessed.split('\n');
    String? headerLine;
    final dataLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final fields = parseCsvLine(trimmed);
      if (fields.length >= 7 && fields[0].toLowerCase() == 'band') {
        headerLine = trimmed;
        continue;
      }
      dataLines.add(trimmed);
    }
    if (headerLine == null || dataLines.length < 2) {
      throw StateError('Schedule needs at least 2 data rows for two-QR split.');
    }

    final mid = dataLines.length ~/ 2;
    final chunk1 = [headerLine, ...dataLines.sublist(0, mid)].join('\n');
    final chunk2 = dataLines.sublist(mid).join('\n');
    final p1 = compressScheduleForQrData(chunk1, bandNames, venueNames);
    final p2 = compressScheduleForQrData(chunk2, bandNames, venueNames);
    final out1 = wrapType(scheduleQrTypeChunk1, p1);
    final out2 = wrapType(scheduleQrTypeChunk2, p2);
    if (out1.length > scheduleQrMaxBytesPerBinaryQr ||
        out2.length > scheduleQrMaxBytesPerBinaryQr) {
      throw StateError('Schedule too large for two QRs; shrink data or split manually.');
    }
    return [out1, out2];
  }
}
