import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/app_data_paths.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

/// Sync lifecycle for the local schedule staging file.
enum ScheduleSyncState {
  /// No staging activity yet for this festival.
  idle,

  /// Local CSV is ahead of Dropbox; upload queued or waiting for debounce.
  pending,

  /// Upload to Dropbox is in flight.
  syncing,

  /// Local staging matches last successful Dropbox upload.
  synced,

  /// Last upload failed; local file still has the latest edits.
  error,
}

class ScheduleSyncStatus {
  const ScheduleSyncStatus({
    this.state = ScheduleSyncState.idle,
    this.lastError = '',
    this.lastSavedAt,
    this.lastSyncedAt,
    this.eventCount = 0,
    this.pendingCount = 0,
  });

  final ScheduleSyncState state;
  final String lastError;
  final DateTime? lastSavedAt;
  final DateTime? lastSyncedAt;
  final int eventCount;

  /// Rows that differ from the last successful Dropbox snapshot (adds/edits/deletes).
  final int pendingCount;

  bool get hasUnsynced =>
      state == ScheduleSyncState.pending ||
      state == ScheduleSyncState.syncing ||
      state == ScheduleSyncState.error ||
      pendingCount > 0;

  /// Hide the schedule sync banner when there is nothing useful to show.
  bool get shouldShowBanner {
    if (state == ScheduleSyncState.idle) return false;
    if (state == ScheduleSyncState.synced && pendingCount == 0) return false;
    return true;
  }

  String get label {
    switch (state) {
      case ScheduleSyncState.idle:
        return pendingCount > 0
            ? '$pendingCount unsynced change${pendingCount == 1 ? '' : 's'}'
            : 'Schedule ready';
      case ScheduleSyncState.pending:
        if (pendingCount > 0) {
          return '$pendingCount unsynced change${pendingCount == 1 ? '' : 's'} — '
              'Dropbox sync pending…';
        }
        return 'Saved locally — Dropbox sync pending…';
      case ScheduleSyncState.syncing:
        return pendingCount > 0
            ? 'Syncing $pendingCount change${pendingCount == 1 ? '' : 's'} to Dropbox…'
            : 'Syncing schedule to Dropbox…';
      case ScheduleSyncState.synced:
        return pendingCount > 0
            ? '$pendingCount local change${pendingCount == 1 ? '' : 's'} still unsynced'
            : 'All schedule events synced to Dropbox';
      case ScheduleSyncState.error:
        final friendly = friendlySyncError(lastError);
        if (pendingCount > 0) {
          return '$pendingCount unsynced change${pendingCount == 1 ? '' : 's'} — $friendly';
        }
        return friendly;
    }
  }

  /// Short, user-facing sync failure text (avoids raw ClientException dumps).
  static String friendlySyncError(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return 'Dropbox sync failed — tap Retry sync.';
    final lower = text.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('nodename nor servname') ||
        lower.contains('network is unreachable') ||
        lower.contains('socketexception') ||
        lower.contains('connection failed') ||
        lower.contains('connection reset') ||
        lower.contains('timed out') ||
        lower.contains('timeout')) {
      return 'Couldn’t reach Dropbox (network). Local schedule is saved — tap Retry sync when online.';
    }
    if (lower.contains('oauth2/token') ||
        lower.contains('invalid_access_token') ||
        lower.contains('expired_access_token') ||
        lower.contains('401')) {
      return 'Dropbox sign-in needs refresh. Reconnect Dropbox in Settings, then Retry sync.';
    }
    // Keep message short for the banner.
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ');
    if (oneLine.length <= 160) return 'Dropbox sync failed: $oneLine';
    return 'Dropbox sync failed: ${oneLine.substring(0, 157)}…';
  }

  ScheduleSyncStatus copyWith({
    ScheduleSyncState? state,
    String? lastError,
    DateTime? lastSavedAt,
    DateTime? lastSyncedAt,
    int? eventCount,
    int? pendingCount,
  }) {
    return ScheduleSyncStatus(
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      eventCount: eventCount ?? this.eventCount,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

/// Local schedule CSV + debounced Dropbox upload for fast bulk entry.
///
/// Writes hit disk immediately so the UI can keep adding events; Dropbox
/// receives the latest CSV after [debounce] (coalescing rapid saves).
class ScheduleStagingCoordinator extends ChangeNotifier {
  ScheduleStagingCoordinator({
    required this.pointerService,
    required this.dropboxApi,
    this.debounce = const Duration(seconds: 2),
    Directory? stagingRoot,
    Future<void> Function(String url, String text)? uploadOverride,
  })  : _stagingRootOverride = stagingRoot,
        _uploadOverride = uploadOverride;

  final PointerService pointerService;
  final DropboxApi dropboxApi;
  final Duration debounce;
  final Directory? _stagingRootOverride;
  final Future<void> Function(String url, String text)? _uploadOverride;

  ScheduleSyncStatus _status = const ScheduleSyncStatus();
  ScheduleSyncStatus get status => _status;

  Timer? _debounceTimer;
  Future<void>? _syncInFlight;
  FestivalWorkspace? _queuedWorkspace;
  Directory? _resolvedRoot;

  Future<Directory> _root() async {
    final override = _stagingRootOverride;
    if (override != null) return override;
    if (_resolvedRoot != null) return _resolvedRoot!;
    final dir = await AppDataPaths.scheduleStagingDir();
    _resolvedRoot = dir;
    return dir;
  }

  String _festivalKey(FestivalWorkspace workspace) {
    final id = workspace.id.trim();
    return id.isEmpty ? 'default' : id;
  }

  Future<File> _csvFile(FestivalWorkspace workspace) async {
    final root = await _root();
    return File('${root.path}/${_festivalKey(workspace)}_schedule.csv');
  }

  Future<File> _syncedSnapshotFile(FestivalWorkspace workspace) async {
    final root = await _root();
    return File(
      '${root.path}/${_festivalKey(workspace)}_schedule.synced.csv',
    );
  }

  Future<File> _metaFile(FestivalWorkspace workspace) async {
    final root = await _root();
    return File('${root.path}/${_festivalKey(workspace)}_schedule.meta.json');
  }

  Future<void> _writeSyncedSnapshot(
    FestivalWorkspace workspace,
    String csvText,
  ) async {
    final snapshot = await _syncedSnapshotFile(workspace);
    await snapshot.parent.create(recursive: true);
    await snapshot.writeAsString(csvText);
  }

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
      date.trim(),
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
    return cols.map((c) => (row[c] ?? '').trim()).join('\u001f');
  }

  /// Keys for events that differ from the last successful Dropbox snapshot.
  static Set<String> pendingKeysFromCsv({
    required String stagingCsv,
    required String? syncedCsv,
  }) {
    final stagingRows = parseCsvMaps(stagingCsv);
    final syncedRows =
        syncedCsv == null || syncedCsv.trim().isEmpty
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
    // Deletions: present in last sync, removed from working copy.
    pending.addAll(syncedByKey.keys.where((k) => !stagingKeys.contains(k)));
    return pending;
  }

  Future<Set<String>> outstandingEventKeys(FestivalWorkspace workspace) async {
    final csv = await _csvFile(workspace);
    if (!await csv.exists()) return {};
    final snapshot = await _syncedSnapshotFile(workspace);
    final syncedText =
        await snapshot.exists() ? await snapshot.readAsString() : null;
    return pendingKeysFromCsv(
      stagingCsv: await csv.readAsString(),
      syncedCsv: syncedText,
    );
  }

  Future<int> _pendingCount(FestivalWorkspace workspace) async {
    return (await outstandingEventKeys(workspace)).length;
  }

  Future<Map<String, dynamic>> _readMeta(FestivalWorkspace workspace) async {
    final file = await _metaFile(workspace);
    if (!await file.exists()) return {};
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic>
          ? data
          : Map<String, dynamic>.from(data as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMeta(
    FestivalWorkspace workspace,
    Map<String, dynamic> updates,
  ) async {
    final file = await _metaFile(workspace);
    final data = await _readMeta(workspace)..addAll(updates);
    await file.parent.create(recursive: true);
    await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(data)}\n');
  }

  void _applyStatus(ScheduleSyncStatus next) {
    _status = next;
    notifyListeners();
  }

  static int _countDataRows(String csvText) {
    final lines = csvText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trimRight())
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return 0;
    return lines.length - 1;
  }

  Future<void> _refreshStatusFromDisk(
    FestivalWorkspace workspace, {
    bool softenStaleErrors = false,
  }) async {
    final csv = await _csvFile(workspace);
    final meta = await _readMeta(workspace);
    final eventCount =
        await csv.exists() ? _countDataRows(await csv.readAsString()) : 0;
    final pendingCount = await _pendingCount(workspace);
    var stateRaw = (meta['state'] as String?) ?? 'idle';

    // Stale errors from a previous session shouldn't greet the user with a red
    // banner on Entry. Demote to pending so local work stays available.
    if (softenStaleErrors && stateRaw == 'error') {
      await _writeMeta(workspace, {
        'state': pendingCount > 0 ? 'pending' : 'synced',
        'lastError': '',
      });
      stateRaw = pendingCount > 0 ? 'pending' : 'synced';
    }

    final state = switch (stateRaw) {
      'pending' => ScheduleSyncState.pending,
      'syncing' => ScheduleSyncState.syncing,
      'synced' => ScheduleSyncState.synced,
      'error' => ScheduleSyncState.error,
      _ => ScheduleSyncState.idle,
    };
    _applyStatus(
      ScheduleSyncStatus(
        state: state,
        lastError: state == ScheduleSyncState.error
            ? ((meta['lastError'] as String?) ?? '')
            : '',
        lastSavedAt: _parseTime(meta['lastSavedAt']),
        lastSyncedAt: _parseTime(meta['lastSyncedAt']),
        eventCount: eventCount,
        pendingCount: pendingCount,
      ),
    );
  }

  static DateTime? _parseTime(Object? raw) {
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch((raw * 1000).round());
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  Future<String> resolveScheduleUrl(FestivalWorkspace workspace) async {
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

  /// Ensure staging CSV exists (seed from Dropbox when missing).
  Future<File> ensureStaging(FestivalWorkspace workspace) async {
    final csv = await _csvFile(workspace);
    final url = await resolveScheduleUrl(workspace);
    final meta = await _readMeta(workspace);
    final metaUrl = (meta['publishedUrl'] as String?)?.trim() ?? '';

    if (await csv.exists()) {
      // Published URL changed and nothing pending — reseed from Dropbox.
      final pending = (meta['state'] as String?) == 'pending' ||
          (meta['state'] as String?) == 'error' ||
          (meta['state'] as String?) == 'syncing';
      if (metaUrl.isNotEmpty && metaUrl != url && !pending) {
        final text = await fetchUrlText(url);
        await csv.writeAsString(text);
        await _writeSyncedSnapshot(workspace, text);
        await _writeMeta(workspace, {
          'state': 'synced',
          'publishedUrl': url,
          'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
          'lastSavedAt': DateTime.now().toUtc().toIso8601String(),
          'lastError': '',
        });
      }
      await _refreshStatusFromDisk(workspace, softenStaleErrors: true);
      return csv;
    }

    await csv.parent.create(recursive: true);
    final text = await fetchUrlText(url);
    await csv.writeAsString(text);
    await _writeSyncedSnapshot(workspace, text);
    final now = DateTime.now().toUtc().toIso8601String();
    await _writeMeta(workspace, {
      'state': 'synced',
      'publishedUrl': url,
      'lastSyncedAt': now,
      'lastSavedAt': now,
      'lastError': '',
    });
    await _refreshStatusFromDisk(workspace, softenStaleErrors: true);
    return csv;
  }

  Future<String> loadWorkingCsv(FestivalWorkspace workspace) async {
    final csv = await ensureStaging(workspace);
    return csv.readAsString();
  }

  /// Persist CSV locally and queue a debounced Dropbox upload.
  ///
  /// Returns as soon as the local write completes — does not wait for Dropbox.
  Future<void> saveLocalAndQueue(
    FestivalWorkspace workspace,
    String csvText,
  ) async {
    final csv = await _csvFile(workspace);
    await csv.parent.create(recursive: true);
    await csv.writeAsString(csvText);
    final url = await resolveScheduleUrl(workspace);
    final now = DateTime.now().toUtc().toIso8601String();
    await _writeMeta(workspace, {
      'state': 'pending',
      'publishedUrl': url,
      'lastSavedAt': now,
      'lastError': '',
    });
    final pendingCount = await _pendingCount(workspace);
    _applyStatus(
      ScheduleSyncStatus(
        state: ScheduleSyncState.pending,
        lastSavedAt: DateTime.now().toUtc(),
        lastSyncedAt: _status.lastSyncedAt,
        eventCount: _countDataRows(csvText),
        pendingCount: pendingCount,
      ),
    );
    _queueSync(workspace);
  }

  void _queueSync(FestivalWorkspace workspace) {
    _queuedWorkspace = workspace;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      final ws = _queuedWorkspace;
      if (ws == null) return;
      unawaited(_runSync(ws));
    });
  }

  /// Cancel debounce and upload now (Promote, festival switch, Retry).
  Future<void> flushSync(FestivalWorkspace workspace) async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _queuedWorkspace = workspace;
    await _runSync(workspace);
    if (_status.state == ScheduleSyncState.error) {
      throw StateError(ScheduleSyncStatus.friendlySyncError(_status.lastError));
    }
  }

  Future<void> _runSync(FestivalWorkspace workspace) async {
    // Serialize uploads; if another finishes and we're still pending, loop.
    while (true) {
      if (_syncInFlight != null) {
        await _syncInFlight;
      }
      final meta = await _readMeta(workspace);
      final state = (meta['state'] as String?) ?? '';
      if (state != 'pending' && state != 'error') {
        await _refreshStatusFromDisk(workspace);
        return;
      }
      final future = _syncOnce(workspace);
      _syncInFlight = future;
      try {
        await future;
      } catch (_) {
        // Status already marked error; background debounce must not crash.
        return;
      } finally {
        if (identical(_syncInFlight, future)) {
          _syncInFlight = null;
        }
      }
      final after = await _readMeta(workspace);
      if ((after['state'] as String?) != 'pending') {
        return;
      }
      // New edits landed during upload — sync again immediately.
    }
  }

  Future<void> _syncOnce(FestivalWorkspace workspace) async {
    final csv = await ensureStaging(workspace);
    final url = await resolveScheduleUrl(workspace);
    final text = await csv.readAsString();
    final eventCount = _countDataRows(text);

    _applyStatus(
      _status.copyWith(
        state: ScheduleSyncState.syncing,
        lastError: '',
        eventCount: eventCount,
        pendingCount: await _pendingCount(workspace),
      ),
    );
    await _writeMeta(workspace, {
      'state': 'syncing',
      'publishedUrl': url,
      'lastError': '',
    });

    try {
      final upload = _uploadOverride;
      if (upload != null) {
        await upload(url, text);
      } else {
        await dropboxApi.uploadTextInPlace(url, text);
      }
      final now = DateTime.now().toUtc();
      // Snapshot what Dropbox now has (even if newer local edits arrived).
      await _writeSyncedSnapshot(workspace, text);

      final meta = await _readMeta(workspace);
      final pendingCount = await _pendingCount(workspace);
      if ((meta['state'] as String?) == 'pending' || pendingCount > 0) {
        if ((meta['state'] as String?) != 'pending') {
          await _writeMeta(workspace, {
            'state': 'pending',
            'lastSavedAt': meta['lastSavedAt'] ?? now.toIso8601String(),
          });
        }
        _applyStatus(
          ScheduleSyncStatus(
            state: ScheduleSyncState.pending,
            lastSavedAt: _parseTime(meta['lastSavedAt']) ?? now,
            lastSyncedAt: now,
            eventCount: _countDataRows(await csv.readAsString()),
            pendingCount: pendingCount,
          ),
        );
        return;
      }

      await _writeMeta(workspace, {
        'state': 'synced',
        'publishedUrl': url,
        'lastSyncedAt': now.toIso8601String(),
        'lastError': '',
      });
      _applyStatus(
        ScheduleSyncStatus(
          state: ScheduleSyncState.synced,
          lastSavedAt: _parseTime(meta['lastSavedAt']) ?? now,
          lastSyncedAt: now,
          eventCount: eventCount,
          pendingCount: 0,
        ),
      );
    } catch (e) {
      final message = e.toString();
      await _writeMeta(workspace, {
        'state': 'error',
        'lastError': message,
      });
      _applyStatus(
        _status.copyWith(
          state: ScheduleSyncState.error,
          lastError: message,
          pendingCount: await _pendingCount(workspace),
        ),
      );
    }
  }

  /// Discard local staging and reload from the published Dropbox URL.
  Future<String> reloadFromPublished(
    FestivalWorkspace workspace, {
    bool forceRefresh = true,
  }) async {
    _debounceTimer?.cancel();
    final url = await resolveScheduleUrl(workspace);
    final text = await fetchUrlText(url, forceRefresh: forceRefresh);
    final csv = await _csvFile(workspace);
    await csv.parent.create(recursive: true);
    await csv.writeAsString(text);
    await _writeSyncedSnapshot(workspace, text);
    final now = DateTime.now().toUtc().toIso8601String();
    await _writeMeta(workspace, {
      'state': 'synced',
      'publishedUrl': url,
      'lastSyncedAt': now,
      'lastSavedAt': now,
      'lastError': '',
    });
    await _refreshStatusFromDisk(workspace);
    return text;
  }

  /// Delete local staging CSV / snapshot / meta for [workspace] (e.g. after year roll).
  Future<void> clearForFestival(FestivalWorkspace workspace) async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (_queuedWorkspace != null &&
        _festivalKey(_queuedWorkspace!) == _festivalKey(workspace)) {
      _queuedWorkspace = null;
    }
    for (final file in [
      await _csvFile(workspace),
      await _syncedSnapshotFile(workspace),
      await _metaFile(workspace),
    ]) {
      if (await file.exists()) {
        await file.delete();
      }
    }
    _applyStatus(const ScheduleSyncStatus());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
