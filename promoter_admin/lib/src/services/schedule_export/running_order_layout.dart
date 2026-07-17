import 'dart:math' as math;

import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/day_date_alignment.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';

class RunningOrderLayout {
  const RunningOrderLayout({required this.pages});

  final List<RunningOrderPage> pages;

  /// Counts underlying schedule rows (merged multi-band slots still count each).
  int get eventCount => pages.fold(
    0,
    (total, page) =>
        total +
        page.events.fold<int>(0, (sum, event) => sum + event.sources.length),
  );

  static List<ScheduleEvent> filterByTypes(
    Iterable<ScheduleEvent> events,
    Set<String> includedTypes,
  ) {
    final normalized = includedTypes
        .map((type) => type.trim().toLowerCase())
        .toSet();
    return events
        .where((event) => normalized.contains(event.type.trim().toLowerCase()))
        .toList();
  }

  static RunningOrderLayout build(
    Iterable<ScheduleEvent> source,
    FestivalWorkspace workspace,
  ) {
    final events = source.toList();
    final grouped = <String, List<ScheduleEvent>>{};
    for (final event in events) {
      final day = event.day.trim().isEmpty
          ? 'Unspecified day'
          : event.day.trim();
      grouped.putIfAbsent(day, () => []).add(event);
    }

    final configuredDays = workspace.days.map((day) => day.trim()).toList();
    final dayOrder = <String>[
      ...configuredDays.where(grouped.containsKey),
      ...grouped.keys.where((day) => !configuredDays.contains(day)).toList()
        ..sort(),
    ];
    final rollover = DayDateAlignment.parseRolloverTime(
      workspace.dateRolloverTime,
    );
    final rolloverMinutes = rollover.$1 * 60 + rollover.$2;

    final pages = <RunningOrderPage>[];
    for (final day in dayOrder) {
      final dayEvents = grouped[day]!;
      final configuredVenues = workspace.venues
          .map((venue) => venue.trim())
          .toList();
      final presentVenues = dayEvents
          .map((event) => event.location.trim())
          .toSet();
      final unknownVenues =
          presentVenues
              .where((venue) => !configuredVenues.contains(venue))
              .toList()
            ..sort();
      final venueNames = <String>[
        ...configuredVenues.where(presentVenues.contains),
        ...unknownVenues,
      ];
      if (venueNames.isEmpty) venueNames.add('Unspecified venue');

      final layoutEvents =
          dayEvents.map((event) {
            final start = _timelineMinutes(event.startTime, rolloverMinutes);
            var finish = _timelineMinutes(event.endTime, rolloverMinutes);
            if (finish <= start) finish += 24 * 60;
            return RunningOrderEvent(
              sources: [event],
              venueIndex: math.max(
                0,
                venueNames.indexOf(event.location.trim()),
              ),
              startMinute: start,
              endMinute: finish,
            );
          }).toList()..sort((a, b) {
            final byStart = a.startMinute.compareTo(b.startMinute);
            if (byStart != 0) return byStart;
            return a.venueIndex.compareTo(b.venueIndex);
          });

      final packed = _coalesceAndPack(layoutEvents);
      final earliest = packed
          .map((event) => event.startMinute)
          .reduce(math.min);
      final latest = packed.map((event) => event.endMinute).reduce(math.max);
      final startHour = earliest ~/ 60;
      final endHour = (latest / 60).ceil();
      final date = _dateForDay(day, dayEvents, workspace);

      pages.add(
        RunningOrderPage(
          day: day,
          date: date,
          venues: venueNames.map(RunningOrderVenue.parse).toList(),
          startMinute: startHour * 60,
          endMinute: math.max(endHour * 60, (startHour + 1) * 60),
          events: packed,
        ),
      );
    }
    return RunningOrderLayout(pages: pages);
  }

  /// Merge identical same-venue time slots (multi-band Meet & Greets) and
  /// assign side-by-side lanes when times only partially overlap.
  static List<RunningOrderEvent> _coalesceAndPack(
    List<RunningOrderEvent> events,
  ) {
    if (events.isEmpty) return const [];

    final byVenue = <int, List<RunningOrderEvent>>{};
    for (final event in events) {
      byVenue.putIfAbsent(event.venueIndex, () => []).add(event);
    }

    final packed = <RunningOrderEvent>[];
    for (final venueEvents in byVenue.values) {
      packed.addAll(_packVenue(_mergeIdenticalSlots(venueEvents)));
    }
    packed.sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      if (byStart != 0) return byStart;
      final byVenueCmp = a.venueIndex.compareTo(b.venueIndex);
      if (byVenueCmp != 0) return byVenueCmp;
      return a.laneIndex.compareTo(b.laneIndex);
    });
    return packed;
  }

  static List<RunningOrderEvent> _mergeIdenticalSlots(
    List<RunningOrderEvent> venueEvents,
  ) {
    final groups = <String, RunningOrderEvent>{};
    final order = <String>[];
    for (final event in venueEvents) {
      final key = '${event.startMinute}:${event.endMinute}';
      final existing = groups[key];
      if (existing == null) {
        groups[key] = event;
        order.add(key);
        continue;
      }
      groups[key] = existing.copyWith(
        sources: [...existing.sources, ...event.sources],
      );
    }
    return [for (final key in order) groups[key]!];
  }

  static List<RunningOrderEvent> _packVenue(List<RunningOrderEvent> events) {
    final sorted = [...events]
      ..sort((a, b) {
        final byStart = a.startMinute.compareTo(b.startMinute);
        if (byStart != 0) return byStart;
        return a.endMinute.compareTo(b.endMinute);
      });

    final laneEnds = <int>[];
    final withLanes = <RunningOrderEvent>[];
    for (final event in sorted) {
      var lane = laneEnds.indexWhere((end) => end <= event.startMinute);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(event.endMinute);
      } else {
        laneEnds[lane] = event.endMinute;
      }
      withLanes.add(event.copyWith(laneIndex: lane, laneCount: 1));
    }

    final n = withLanes.length;
    final laneCounts = List<int>.filled(n, 1);
    for (var i = 0; i < n; i++) {
      final seen = <int>{i};
      final stack = <int>[i];
      var maxLane = withLanes[i].laneIndex;
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        maxLane = math.max(maxLane, withLanes[cur].laneIndex);
        for (var j = 0; j < n; j++) {
          if (seen.contains(j)) continue;
          if (_overlaps(withLanes[cur], withLanes[j])) {
            seen.add(j);
            stack.add(j);
          }
        }
      }
      final count = maxLane + 1;
      for (final idx in seen) {
        laneCounts[idx] = math.max(laneCounts[idx], count);
      }
    }
    return [
      for (var i = 0; i < n; i++)
        withLanes[i].copyWith(laneCount: laneCounts[i]),
    ];
  }

  static bool _overlaps(RunningOrderEvent a, RunningOrderEvent b) =>
      a.startMinute < b.endMinute && b.startMinute < a.endMinute;

  static int _timelineMinutes(String raw, int rolloverMinutes) {
    final parts = raw.trim().split(':');
    final hour = parts.isEmpty ? 0 : int.tryParse(parts.first) ?? 0;
    final minute = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    final clock = hour * 60 + minute;
    return clock < rolloverMinutes ? clock + 24 * 60 : clock;
  }

  static String _dateForDay(
    String day,
    List<ScheduleEvent> events,
    FestivalWorkspace workspace,
  ) {
    final dayIndex = workspace.days.indexWhere((value) => value.trim() == day);
    if (dayIndex >= 0 && dayIndex < workspace.dates.length) {
      return workspace.dates[dayIndex].trim();
    }
    final orderedDates =
        events
            .map((event) => event.date.trim())
            .where((date) => date.isNotEmpty)
            .toList()
          ..sort((a, b) => _dateSortKey(a).compareTo(_dateSortKey(b)));
    return orderedDates.isEmpty ? '' : orderedDates.first;
  }

  static int _dateSortKey(String raw) {
    final parts = raw.split(RegExp(r'[/-]'));
    if (parts.length < 3) return 0;
    final first = int.tryParse(parts[0]) ?? 0;
    final second = int.tryParse(parts[1]) ?? 0;
    final third = int.tryParse(parts[2]) ?? 0;
    if (first >= 1000) return first * 10000 + second * 100 + third;
    return third * 10000 + first * 100 + second;
  }
}

class RunningOrderPage {
  const RunningOrderPage({
    required this.day,
    required this.date,
    required this.venues,
    required this.startMinute,
    required this.endMinute,
    required this.events,
  });

  final String day;
  final String date;
  final List<RunningOrderVenue> venues;
  final int startMinute;
  final int endMinute;
  final List<RunningOrderEvent> events;

  int get durationMinutes => endMinute - startMinute;

  String get displayDate {
    final parts = date.split(RegExp(r'[/-]'));
    if (parts.length < 3) return date.toUpperCase();
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) {
      return date.toUpperCase();
    }
    final year = first >= 1000 ? first : third;
    final month = first >= 1000 ? second : first;
    final dayOfMonth = first >= 1000 ? third : second;
    final value = DateTime(year, month, dayOfMonth);
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${weekdays[value.weekday - 1]}, '
        '${months[value.month - 1]} ${value.day}';
  }
}

class RunningOrderVenue {
  const RunningOrderVenue({required this.name, this.subtitle = ''});

  final String name;
  final String subtitle;

  static RunningOrderVenue parse(String raw) {
    final value = raw.trim().isEmpty ? 'Unspecified venue' : raw.trim();
    final match = RegExp(r'^(.*?)\s*(\([^)]*\))\s*$').firstMatch(value);
    if (match == null || (match.group(1) ?? '').trim().isEmpty) {
      return RunningOrderVenue(name: value);
    }
    return RunningOrderVenue(
      name: match.group(1)!.trim(),
      subtitle: match.group(2)!.trim(),
    );
  }
}

class RunningOrderEvent {
  const RunningOrderEvent({
    required this.sources,
    required this.venueIndex,
    required this.startMinute,
    required this.endMinute,
    this.laneIndex = 0,
    this.laneCount = 1,
  });

  /// One or more schedule rows sharing this block (multi-band slots).
  final List<ScheduleEvent> sources;
  final int venueIndex;
  final int startMinute;
  final int endMinute;

  /// Side-by-side subdivision when times overlap but are not identical.
  final int laneIndex;
  final int laneCount;

  int get durationMinutes => endMinute - startMinute;

  ScheduleEvent get source => sources.first;

  List<String> get bandNames => [
    for (final item in sources)
      if (item.band.trim().isNotEmpty) item.band.trim(),
  ];

  List<String> get noteLines => [
    for (final item in sources)
      if (item.notes.trim().isNotEmpty) item.notes.trim(),
  ];

  /// Titles that must appear in an event box. Falls back to notes when Band
  /// is empty so Special Events / clinics never render as time-only blanks.
  List<String> get displayTitles {
    final titles = bandNames;
    if (titles.isNotEmpty) return titles;
    final fromNotes = noteLines;
    if (fromNotes.isNotEmpty) return fromNotes;
    return const ['(Untitled)'];
  }
  /// Prefer a shared clock range; otherwise list each row's times.
  String timeLine({required String Function(String) formatClock}) {
    final starts = sources.map((item) => item.startTime.trim()).toSet();
    final ends = sources.map((item) => item.endTime.trim()).toSet();
    if (starts.length == 1 && ends.length == 1) {
      return '${formatClock(starts.single)} - ${formatClock(ends.single)}';
    }
    return sources
        .map(
          (item) =>
              '${formatClock(item.startTime)} - ${formatClock(item.endTime)}',
        )
        .join('\n');
  }

  RunningOrderEvent copyWith({
    List<ScheduleEvent>? sources,
    int? venueIndex,
    int? startMinute,
    int? endMinute,
    int? laneIndex,
    int? laneCount,
  }) {
    return RunningOrderEvent(
      sources: sources ?? this.sources,
      venueIndex: venueIndex ?? this.venueIndex,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      laneIndex: laneIndex ?? this.laneIndex,
      laneCount: laneCount ?? this.laneCount,
    );
  }
}
