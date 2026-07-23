import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_constants.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';

/// Full schedule CSV for QR export, with unofficial/cruiser rows removed.
class ScheduleQrCsv {
  const ScheduleQrCsv._();

  static String fromEvents(List<ScheduleEvent> events) {
    return stripUnofficialCruiserRows(ScheduleService.toCsv(events));
  }

  /// Remove rows where Type is Unofficial Event or Cruiser Organized.
  static String stripUnofficialCruiserRows(String csv) {
    final lines = csv.split('\n');
    if (lines.isEmpty) return csv;
    final out = <String>[lines.first];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        out.add(line);
        continue;
      }
      final fields = parseCsvLine(line.trim());
      if (fields.length <= 6) {
        out.add(line);
        continue;
      }
      if (scheduleQrUnofficialTypes.contains(fields[6].trim())) {
        continue;
      }
      out.add(line);
    }
    return out.join('\n');
  }
}
