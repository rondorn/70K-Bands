import 'package:promoter_admin/src/services/schedule_service.dart';

/// Port of data_entry/schedule_logic.py validation + show-stats helpers.
class ScheduleValidation {
  ScheduleValidation._();

  /// Show-like types get the 2-show cap and 30–120 minute length rules.
  static bool isShowType(String type) {
    final t = type.trim().toLowerCase();
    return t == 'show' || t == 'metal show';
  }

  /// Official / fan non-performance events: title lives in Band column; Notes unused.
  static const nonBandEventTypes = {'Special Event', 'Unofficial Event'};

  /// Always available in schedule entry for every festival.
  static const defaultEventTypes = [
    'Show',
    'Clinic',
    'Meet and Greet',
    'Special Event',
    'Unofficial Event',
  ];

  /// Defaults first, then any extra festival-specific types (deduped).
  static List<String> withDefaultEventTypes(Iterable<String> existing) {
    final out = <String>[];
    final seen = <String>{};
    for (final t in defaultEventTypes) {
      if (seen.add(t)) out.add(t);
    }
    for (final t in existing) {
      final v = t.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) out.add(v);
    }
    return out;
  }

  static bool isNonBandEventType(String type) =>
      nonBandEventTypes.contains(type.trim());

  static bool _isBlank(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty;
  }

  /// Returns human-readable errors. Empty when [verifyBypass] is true.
  /// [existing] should already exclude the row being edited.
  static List<String> validateEvent({
    required ScheduleEvent event,
    required List<ScheduleEvent> existing,
    bool verifyBypass = false,
  }) {
    if (verifyBypass) return const [];

    final errors = <String>[];
    final nonBand = isNonBandEventType(event.type);

    if (_isBlank(event.band)) {
      errors.add(
        nonBand
            ? 'Event title must be assigned a value'
            : 'Band Name must be assigned a value',
      );
    }
    if (_isBlank(event.type)) {
      errors.add('Event Type must be assigned a value');
    }
    if (_isBlank(event.location)) {
      errors.add('The Venue must be assigned a value');
    }
    if (_isBlank(event.date)) {
      errors.add('Date must be assigned a value');
    }
    if (_isBlank(event.day)) {
      errors.add('Day must be assigned a value');
    }

    if (_isBlank(event.startTime) || event.startTime.trim() == ':') {
      errors.add('Complete Start Time information must be provided');
    }
    if (_isBlank(event.endTime) || event.endTime.trim() == ':') {
      errors.add('Complete End Time information must be provided');
    }

    // Per-band type caps: Shows up to 2; everything else up to 1.
    final bandCounts = <String, int>{};
    for (final row in existing) {
      if (row.band != event.band) continue;
      final t = row.type.trim();
      bandCounts[t] = (bandCounts[t] ?? 0) + 1;
    }
    final type = event.type.trim();
    if (isShowType(type)) {
      final shows = existing.where((r) =>
          r.band == event.band && isShowType(r.type)).length;
      if (shows >= 2) {
        errors.add(
          '${event.band} already has 2 shows, you can not book a third',
        );
      }
    } else if ((bandCounts[type] ?? 0) >= 1) {
      errors.add(
        '${event.band} already has a $type booked, '
        'you can not book a second $type',
      );
    }

    late final int startEpoch;
    late final int endEpoch;
    try {
      final start = parseTimeParts(event.startTime);
      final end = parseTimeParts(event.endTime);
      startEpoch = epochSeconds(event.date, start.$1, start.$2);
      endEpoch = epochSeconds(
        event.date,
        end.$1,
        end.$2,
        startHour: start.$1,
      );
    } catch (e) {
      errors.add(e.toString());
      return errors;
    }

    for (final row in existing) {
      late final int rowStart;
      late final int rowEnd;
      try {
        final rs = parseTimeParts(row.startTime);
        final re = parseTimeParts(row.endTime);
        rowStart = epochSeconds(row.date, rs.$1, rs.$2);
        rowEnd = epochSeconds(row.date, re.$1, re.$2, startHour: rs.$1);
      } catch (_) {
        continue;
      }

      if (row.location == event.location) {
        if (startEpoch < rowEnd && endEpoch > rowStart) {
          errors.add(
            '${event.location} Already has a show booked for that timeslot '
            '(overlaps with existing booking)',
          );
          break;
        }
      }
    }

    for (final row in existing) {
      if (row.band != event.band) continue;
      late final int rowStart;
      late final int rowEnd;
      try {
        final rs = parseTimeParts(row.startTime);
        final re = parseTimeParts(row.endTime);
        rowStart = epochSeconds(row.date, rs.$1, rs.$2);
        rowEnd = epochSeconds(row.date, re.$1, re.$2, startHour: rs.$1);
      } catch (_) {
        continue;
      }
      if (startEpoch < rowEnd && endEpoch > rowStart) {
        errors.add(
          '${event.band} Already has a show booked for that timeslot '
          '(overlaps with existing booking)',
        );
        break;
      }
    }

    if (isShowType(type)) {
      final lengthSec = endEpoch - startEpoch;
      if (lengthSec < 30 * 60) {
        errors.add('Show is to short. Should be at least 30 min');
      } else if (lengthSec > 120 * 60) {
        errors.add('Show is to Long. Should not exceed 2 hours');
      }
    }

    return errors;
  }

  /// Band → event-type → count, for the Stats matrix.
  static Map<String, Map<String, int>> buildStats(List<ScheduleEvent> events) {
    final stats = <String, Map<String, int>>{};
    for (final event in events) {
      final band = event.band.trim();
      final type = event.type.trim();
      if (band.isEmpty) continue;
      final byType = stats.putIfAbsent(band, () => <String, int>{});
      if (type.isEmpty) continue;
      byType[type] = (byType[type] ?? 0) + 1;
    }
    return stats;
  }

  static List<String> statsBandRows({
    required List<String> lineupNames,
    required List<ScheduleEvent> events,
  }) {
    final names = <String>{};
    for (final n in lineupNames) {
      final v = n.trim();
      if (v.isNotEmpty) names.add(v);
    }
    for (final e in events) {
      final v = e.band.trim();
      if (v.isNotEmpty) names.add(v);
    }
    final list = names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<String> statsTypeColumns({
    required List<String> configuredTypes,
    required List<ScheduleEvent> events,
  }) {
    final out = <String>[];
    final seen = <String>{};
    for (final t in configuredTypes) {
      final v = t.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) out.add(v);
    }
    for (final e in events) {
      final v = e.type.trim();
      if (v.isEmpty) continue;
      if (seen.add(v)) out.add(v);
    }
    if (out.isEmpty) {
      return List<String>.from(defaultEventTypes);
    }
    return withDefaultEventTypes(out);
  }

  static (int, int) parseTimeParts(String timeStr) {
    final match = RegExp(r'(\d+)\s*:\s*(\d+)').firstMatch(timeStr.trim());
    if (match == null) {
      throw FormatException('Invalid time: $timeStr');
    }
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  /// Festival dates (M/D/Y, or Y/M/D if first part is a year) → epoch seconds.
  /// When [startHour] is afternoon and end hour is morning, roll end to next day.
  static int epochSeconds(
    String dateStr,
    int hour,
    int minute, {
    int? startHour,
  }) {
    final parts = dateStr.trim().split(RegExp(r'[/-]'));
    if (parts.length != 3) {
      throw FormatException('Invalid date: $dateStr');
    }
    final a = int.parse(parts[0]);
    final b = int.parse(parts[1]);
    final c = int.parse(parts[2]);
    late final int year;
    late final int month;
    late final int day;
    if (a >= 1000) {
      year = a;
      month = b;
      day = c;
    } else {
      month = a;
      day = b;
      year = c;
    }

    var h = hour;
    var y = year;
    var m = month;
    var d = day;
    if (h == 24) {
      h = 0;
      final next = DateTime(y, m, d).add(const Duration(days: 1));
      y = next.year;
      m = next.month;
      d = next.day;
    }
    if (startHour != null && startHour > 12 && h < 12) {
      final next = DateTime(y, m, d).add(const Duration(days: 1));
      y = next.year;
      m = next.month;
      d = next.day;
    }
    return DateTime(y, m, d, h, minute).millisecondsSinceEpoch ~/ 1000;
  }
}
