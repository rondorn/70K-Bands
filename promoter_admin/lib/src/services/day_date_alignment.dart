import 'package:promoter_admin/src/services/schedule_validation.dart';

/// Ordered Days/Dates alignment for schedule entry auto-fill.
///
/// Days and Dates are parallel by **line order** (names are labels only):
/// - Day[i] → Date[i] when start is on/after [dateRolloverTime]
/// - Day[i] → Date[i+1] when start is from midnight until rollover
/// - Dates must have exactly one more entry than Days (last date = final overnight)
class DayDateAlignment {
  DayDateAlignment._();

  static const defaultRolloverTime = '8:00';

  /// Non-blank vocabulary lines (ignores empty / single-space placeholders).
  static List<String> meaningful(Iterable<String> raw) {
    final out = <String>[];
    for (final s in raw) {
      final t = s.trim();
      if (t.isEmpty) continue;
      out.add(t);
    }
    return out;
  }

  /// Parse M/D/Y or Y/M/D festival date strings.
  static DateTime? parseDate(String raw) {
    final parts = raw.trim().split(RegExp(r'[/-]'));
    if (parts.length != 3) return null;
    final a = int.tryParse(parts[0].trim());
    final b = int.tryParse(parts[1].trim());
    final c = int.tryParse(parts[2].trim());
    if (a == null || b == null || c == null) return null;
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
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Format as M/D/YYYY with no leading zeros on month/day.
  static String formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';

  /// Dedupe 01/13 vs 1/13, keep short form, sort chronologically.
  /// Unparseable lines are dropped (they cannot participate in alignment).
  static List<String> normalizeDates(Iterable<String> raw) {
    final byKey = <String, DateTime>{};
    for (final s in meaningful(raw)) {
      final dt = parseDate(s);
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
      byKey.putIfAbsent(key, () => dt);
    }
    final sorted = byKey.values.toList()..sort((a, b) => a.compareTo(b));
    return sorted.map(formatDate).toList();
  }

  /// Preserve day label order; trim blanks only.
  static List<String> normalizeDays(Iterable<String> raw) => meaningful(raw);

  /// True when each date is exactly one calendar day after the previous.
  static bool datesAreConsecutive(List<String> dates) {
    final list = meaningful(dates);
    if (list.length < 2) return true;
    DateTime? prev;
    for (final s in list) {
      final dt = parseDate(s);
      if (dt == null) return false;
      if (prev != null) {
        final expected = prev.add(const Duration(days: 1));
        if (dt.year != expected.year ||
            dt.month != expected.month ||
            dt.day != expected.day) {
          return false;
        }
      }
      prev = dt;
    }
    return true;
  }

  /// Days N and Dates N+1 (after normalizing blanks).
  static bool hasAlignedCounts(List<String> days, List<String> dates) {
    final d = meaningful(days);
    final t = meaningful(dates);
    if (d.isEmpty) return t.isEmpty;
    return t.length == d.length + 1;
  }

  /// Human-readable problems for Settings save / Load feedback.
  ///
  /// Days and Dates must be 1:1 by line order, plus exactly one trailing date
  /// for overnight on the last day (`dates.length == days.length + 1`).
  /// Both empty is allowed (festival not using schedule vocabulary yet).
  static List<String> validateLists({
    required List<String> days,
    required List<String> dates,
  }) {
    final d = normalizeDays(days);
    final t = normalizeDates(dates);
    final errors = <String>[];
    if (d.isEmpty && t.isEmpty) return errors;

    if (d.isEmpty && t.isNotEmpty) {
      errors.add(
        'Days and Dates must align 1:1 with one extra Date. '
        'Days is empty but Dates has ${t.length} '
        '${t.length == 1 ? 'entry' : 'entries'}.',
      );
      return errors;
    }
    if (t.isEmpty && d.isNotEmpty) {
      errors.add(
        'Days and Dates must align 1:1 with one extra Date. '
        'Have ${d.length} ${d.length == 1 ? 'Day' : 'Days'} but no Dates. '
        'Add ${d.length + 1} consecutive Dates (last = overnight buffer).',
      );
      return errors;
    }
    if (t.length != d.length + 1) {
      final need = d.length + 1;
      errors.add(
        'Days and Dates must align 1:1 with one extra Date. '
        'Have ${d.length} ${d.length == 1 ? 'Day' : 'Days'} and '
        '${t.length} ${t.length == 1 ? 'Date' : 'Dates'}; '
        'need exactly $need Dates (one overnight buffer after the last Day).',
      );
    }
    if (t.length >= 2 && !datesAreConsecutive(t)) {
      errors.add(
        'Dates must be consecutive calendar days in order '
        '(e.g. 1/13/2027 then 1/14/2027).',
      );
    }
    return errors;
  }

  /// Throws [StateError] when Days/Dates counts are not aligned.
  static void requireAlignedLists({
    required List<String> days,
    required List<String> dates,
  }) {
    final errors = validateLists(days: days, dates: dates);
    if (errors.isNotEmpty) {
      throw StateError(errors.join('\n'));
    }
  }

  /// Parse rollover like `8:00`, `8`, `08:00`. Defaults to 8:00.
  static (int hour, int minute) parseRolloverTime(String? raw) {
    final t = (raw ?? '').trim();
    final candidate = t.isEmpty ? defaultRolloverTime : t;
    try {
      final (h, m) = ScheduleValidation.parseTimeParts(
        candidate.contains(':') ? candidate : '$candidate:00',
      );
      if (h < 0 || h > 23 || m < 0 || m > 59) return (8, 0);
      return (h, m);
    } catch (_) {
      return (8, 0);
    }
  }

  static String formatRolloverTime(int hour, int minute) {
    if (minute == 0) return '$hour:00';
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }

  /// Resolve calendar Date for a Day label + start time.
  ///
  /// Returns null when lists are not aligned or [day] is not in the Days list.
  static String? resolveDate({
    required List<String> days,
    required List<String> dates,
    required String day,
    required String startHour,
    required String startMin,
    String rolloverTime = defaultRolloverTime,
  }) {
    final dList = normalizeDays(days);
    final dateList = normalizeDates(dates);
    if (dList.isEmpty || dateList.length != dList.length + 1) return null;

    final dayKey = day.trim();
    if (dayKey.isEmpty) return null;
    final i = dList.indexWhere((d) => d == dayKey);
    if (i < 0) return null;

    final hour = int.tryParse(startHour.trim());
    final minute = int.tryParse(startMin.trim()) ?? 0;
    if (hour == null) {
      // No start yet — use base (daytime) date.
      return dateList[i];
    }

    final (rollH, rollM) = parseRolloverTime(rolloverTime);
    final startMins = hour * 60 + minute;
    final rollMins = rollH * 60 + rollM;
    if (startMins < rollMins) {
      return dateList[i + 1];
    }
    return dateList[i];
  }

  /// If Load found N days and N dates, append the next calendar day as overnight buffer.
  static List<String> ensureOvernightBuffer({
    required List<String> days,
    required List<String> dates,
  }) {
    final d = normalizeDays(days);
    final t = normalizeDates(dates);
    if (d.isEmpty || t.isEmpty) return t;
    if (t.length == d.length + 1) return t;
    if (t.length == d.length) {
      final last = parseDate(t.last);
      if (last == null) return t;
      return [...t, formatDate(last.add(const Duration(days: 1)))];
    }
    return t;
  }
}
