import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/schedule_staging.dart';

class ScheduleEvent {
  ScheduleEvent({
    required this.band,
    required this.location,
    required this.date,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.descriptionUrl = ' ',
    this.notes = ' ',
    this.imageUrl = ' ',
  });

  final String band;
  final String location;
  final String date;
  final String day;
  final String startTime;
  final String endTime;
  final String type;
  final String descriptionUrl;
  final String notes;
  final String imageUrl;

  Map<String, String> asRow() => {
        'Band': band,
        'Location': location,
        'Date': date,
        'Day': day,
        'Start Time': startTime,
        'End Time': endTime,
        'Type': type,
        'Description URL': descriptionUrl.trim().isEmpty ? ' ' : descriptionUrl,
        'Notes': notes.trim().isEmpty ? ' ' : notes,
        'ImageURL': imageUrl.trim().isEmpty ? ' ' : imageUrl,
      };

  static ScheduleEvent fromRow(Map<String, String> row) {
    return ScheduleEvent(
      band: (row['Band'] ?? '').trim(),
      location: (row['Location'] ?? '').trim(),
      date: (row['Date'] ?? '').trim(),
      day: (row['Day'] ?? '').trim(),
      startTime: (row['Start Time'] ?? '').trim(),
      endTime: (row['End Time'] ?? '').trim(),
      type: (row['Type'] ?? '').trim(),
      descriptionUrl: (row['Description URL'] ?? ' ').trim().isEmpty
          ? ' '
          : (row['Description URL'] ?? ' ').trim(),
      notes: (row['Notes'] ?? ' ').trim().isEmpty
          ? ' '
          : (row['Notes'] ?? ' ').trim(),
      imageUrl: (row['ImageURL'] ?? ' ').trim().isEmpty
          ? ' '
          : (row['ImageURL'] ?? ' ').trim(),
    );
  }
}

class ScheduleHints {
  const ScheduleHints({
    this.venues = const [],
    this.dates = const [],
    this.days = const [],
    this.eventTypes = const [],
  });

  final List<String> venues;
  final List<String> dates;
  final List<String> days;
  final List<String> eventTypes;
}

class ScheduleService {
  ScheduleService({
    required this.pointerService,
    required this.dropboxApi,
    ScheduleStagingCoordinator? staging,
  }) : staging = staging ??
            ScheduleStagingCoordinator(
              pointerService: pointerService,
              dropboxApi: dropboxApi,
            );

  final PointerService pointerService;
  final DropboxApi dropboxApi;
  final ScheduleStagingCoordinator staging;

  ScheduleSyncStatus get syncStatus => staging.status;

  void addSyncListener(VoidCallback listener) => staging.addListener(listener);

  void removeSyncListener(VoidCallback listener) =>
      staging.removeListener(listener);

  static const columns = [
    'Band',
    'Location',
    'Date',
    'Day',
    'Start Time',
    'End Time',
    'Type',
    'Description URL',
    'Notes',
    'ImageURL',
  ];

  static const hours = [
    '00', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11',
    '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23',
  ];

  static const mins = [
    '00', '05', '10', '15', '20', '25', '30', '35', '40', '45', '50', '55',
  ];

  static const lengths = ['45', '60', '90', ' '];

  /// Load the working schedule (local staging, seeded from Dropbox when needed).
  Future<List<ScheduleEvent>> load(FestivalWorkspace workspace) async {
    final text = await staging.loadWorkingCsv(workspace);
    return parseEvents(text);
  }

  /// Save locally immediately and queue a background Dropbox sync.
  ///
  /// Does **not** wait for Dropbox — safe for rapid bulk entry.
  Future<void> save(FestivalWorkspace workspace, List<ScheduleEvent> events) {
    return staging.saveLocalAndQueue(workspace, toCsv(events));
  }

  /// Upload any pending local schedule changes to Dropbox now.
  Future<void> flushSync(FestivalWorkspace workspace) {
    return staging.flushSync(workspace);
  }

  /// Event keys (band|location|date|start) that differ from last Dropbox snapshot.
  Future<Set<String>> outstandingEventKeys(FestivalWorkspace workspace) {
    return staging.outstandingEventKeys(workspace);
  }

  static String eventKey(ScheduleEvent event) =>
      ScheduleStagingCoordinator.eventKey(
        band: event.band,
        location: event.location,
        date: event.date,
        startTime: event.startTime,
      );

  /// Discard staging and reload from the published testing schedule URL.
  Future<List<ScheduleEvent>> reloadFromPublished(
    FestivalWorkspace workspace,
  ) async {
    final text = await staging.reloadFromPublished(workspace);
    return parseEvents(text);
  }

  static List<ScheduleEvent> parseEvents(String text) {
    final rows = parseCsvMaps(text);
    final events = <ScheduleEvent>[];
    for (final row in rows) {
      final band = (row['Band'] ?? '').trim();
      if (band.isEmpty || band.toLowerCase() == 'band') continue;
      events.add(ScheduleEvent.fromRow(row));
    }
    return events;
  }

  static String toCsv(List<ScheduleEvent> events) {
    return mapsToCsv(columns, events.map((e) => e.asRow()).toList());
  }

  static ScheduleHints hintsFromEvents(List<ScheduleEvent> events) {
    final venues = <String>{};
    final dates = <String>{};
    final days = <String>{};
    final types = <String>{};
    for (final e in events) {
      if (e.location.trim().isNotEmpty) venues.add(e.location.trim());
      if (e.date.trim().isNotEmpty) dates.add(e.date.trim());
      if (e.day.trim().isNotEmpty) days.add(e.day.trim());
      if (e.type.trim().isNotEmpty) types.add(e.type.trim());
    }
    final dayOrder = [
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
      'Monday',
      'Tuesday',
    ];
    final orderedDays = dayOrder.where(days.contains).toList()
      ..addAll(days.where((d) => !dayOrder.contains(d)));
    return ScheduleHints(
      venues: [' ', ...venues.toList()..sort()],
      dates: [' ', ...dates.toList()..sort()],
      days: orderedDays.isEmpty ? const [] : [' ', ...orderedDays],
      eventTypes: types.toList()..sort(),
    );
  }

  void dispose() => staging.dispose();
}
