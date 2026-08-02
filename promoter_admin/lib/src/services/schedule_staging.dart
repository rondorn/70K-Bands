import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_staging.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/day_date_alignment.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/emergency_local_mode_support.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

export 'package:promoter_admin/src/services/csv_staging.dart'
    show CsvSyncState, CsvSyncStatus;

typedef ScheduleSyncState = CsvSyncState;
typedef ScheduleSyncStatus = CsvSyncStatus;

extension ScheduleSyncStatusCompat on CsvSyncStatus {
  int get eventCount => rowCount;
}

/// Local schedule CSV + debounced Dropbox upload for fast bulk entry.
class ScheduleStagingCoordinator extends ChangeNotifier {
  ScheduleStagingCoordinator({
    required this.pointerService,
    required this.dropboxApi,
    Duration debounce = const Duration(seconds: 2),
    Directory? stagingRoot,
    Future<void> Function(String url, String text)? uploadOverride,
  }) : _inner = CsvStagingCoordinator(
          dropboxApi: dropboxApi,
          channelSuffix: 'schedule',
          displayName: 'Schedule',
          debounce: debounce,
          stagingRoot: stagingRoot,
          uploadOverride: uploadOverride,
          resolveUrl: (workspace) async {
            if (workspace.usesEmergencyLocalMode) {
              final path = workspace.emergencyLocalPaths.scheduleCsv.trim();
              if (path.isEmpty) {
                throw StateError('Schedule CSV path is not configured.');
              }
              return path;
            }
            var url = workspace.scheduleUrl.trim();
            if (url.isEmpty) {
              final refreshed = await pointerService.applyTestingPointer(
                workspace,
              );
              url = refreshed.scheduleUrl.trim();
            }
            if (url.isEmpty) {
              throw StateError('Testing pointer has no Current::scheduleUrl.');
            }
            return url;
          },
          pendingChangeCounter: (stagingCsv, syncedCsv) async {
            return pendingKeysFromCsv(
              stagingCsv: stagingCsv,
              syncedCsv: syncedCsv,
            ).length;
          },
        ) {
    _inner.addListener(notifyListeners);
  }

  final PointerService pointerService;
  final DropboxApi dropboxApi;
  final CsvStagingCoordinator _inner;

  CsvSyncStatus get status => _inner.status;

  /// Event identity key (band|location|date|start) matching the web portal.
  static String eventKey({
    required String band,
    required String location,
    required String date,
    required String startTime,
  }) {
    return [
      band.trim(),
      location.trim(),
      DayDateAlignment.normalizeDate(date),
      startTime.trim(),
    ].join('|');
  }

  static String eventFingerprintFromCsvRow(Map<String, String> row) {
    const cols = [
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
    return cols.map((c) {
      final raw = (row[c] ?? '').trim();
      if (c == 'Date') return DayDateAlignment.normalizeDate(raw);
      return raw;
    }).join('\u001f');
  }

  static Set<String> pendingKeysFromCsv({
    required String stagingCsv,
    required String? syncedCsv,
  }) {
    final stagingRows = parseCsvMaps(stagingCsv);
    final syncedRows = syncedCsv == null || syncedCsv.trim().isEmpty
        ? <Map<String, String>>[]
        : parseCsvMaps(syncedCsv);

    String keyOf(Map<String, String> row) => eventKey(
          band: row['Band'] ?? '',
          location: row['Location'] ?? '',
          date: row['Date'] ?? '',
          startTime: row['Start Time'] ?? '',
        );

    final syncedByKey = <String, String>{};
    for (final row in syncedRows) {
      final band = (row['Band'] ?? '').trim();
      if (band.isEmpty || band.toLowerCase() == 'band') continue;
      syncedByKey[keyOf(row)] = eventFingerprintFromCsvRow(row);
    }

    final stagingKeys = <String>{};
    final pending = <String>{};
    for (final row in stagingRows) {
      final band = (row['Band'] ?? '').trim();
      if (band.isEmpty || band.toLowerCase() == 'band') continue;
      final key = keyOf(row);
      stagingKeys.add(key);
      if (syncedByKey[key] != eventFingerprintFromCsvRow(row)) {
        pending.add(key);
      }
    }
    pending.addAll(syncedByKey.keys.where((k) => !stagingKeys.contains(k)));
    return pending;
  }

  Future<Set<String>> outstandingEventKeys(FestivalWorkspace workspace) async {
    final stagingCsv = await _inner.loadWorkingCsv(workspace);
    final syncedFile = await _inner.readSyncedSnapshot(workspace);
    return pendingKeysFromCsv(
      stagingCsv: stagingCsv,
      syncedCsv: syncedFile,
    );
  }

  Future<String> resolveScheduleUrl(FestivalWorkspace workspace) async {
    if (workspace.usesEmergencyLocalMode) {
      final path = workspace.emergencyLocalPaths.scheduleCsv.trim();
      if (path.isEmpty) {
        throw StateError('Schedule CSV path is not configured.');
      }
      return path;
    }
    var url = workspace.scheduleUrl.trim();
    if (url.isEmpty) {
      final refreshed = await pointerService.applyTestingPointer(workspace);
      url = refreshed.scheduleUrl.trim();
    }
    if (url.isEmpty) {
      throw StateError('Testing pointer has no Current::scheduleUrl.');
    }
    return url;
  }

  Future<File> ensureStaging(FestivalWorkspace workspace) =>
      _inner.ensureStaging(workspace);

  Future<String> loadWorkingCsv(FestivalWorkspace workspace) =>
      _inner.loadWorkingCsv(workspace);

  Future<String?> readLocalCsvIfPresent(FestivalWorkspace workspace) =>
      _inner.readLocalCsvIfPresent(workspace);

  Future<void> saveLocalAndQueue(
    FestivalWorkspace workspace,
    String csvText,
  ) =>
      _inner.saveLocalAndQueue(workspace, csvText);

  Future<void> flushSync(FestivalWorkspace workspace) =>
      _inner.flushSync(workspace);

  Future<String> reloadFromPublished(
    FestivalWorkspace workspace, {
    bool forceRefresh = true,
  }) =>
      _inner.reloadFromPublished(
        workspace,
        forceRefresh: forceRefresh,
      );

  Future<void> clearForFestival(FestivalWorkspace workspace) =>
      _inner.clearForFestival(workspace);

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }
}
