import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/app_data_paths.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';

/// Sync lifecycle for a local Testing CSV staging file.
enum CsvSyncState {
  idle,
  pending,
  syncing,
  synced,
  error,
}

class CsvSyncStatus {
  const CsvSyncStatus({
    this.state = CsvSyncState.idle,
    this.lastError = '',
    this.lastSavedAt,
    this.lastSyncedAt,
    this.rowCount = 0,
    this.pendingCount = 0,
    this.displayName = 'Data',
  });

  final CsvSyncState state;
  final String lastError;
  final DateTime? lastSavedAt;
  final DateTime? lastSyncedAt;
  final int rowCount;
  final int pendingCount;
  final String displayName;

  bool get hasUnsynced =>
      state == CsvSyncState.pending ||
      state == CsvSyncState.syncing ||
      state == CsvSyncState.error ||
      pendingCount > 0;

  bool get shouldShowBanner {
    if (state == CsvSyncState.idle) return false;
    if (state == CsvSyncState.synced && pendingCount == 0) return false;
    return true;
  }

  String get label {
    final name = displayName;
    final lower = name.toLowerCase();
    switch (state) {
      case CsvSyncState.idle:
        return pendingCount > 0
            ? '$pendingCount unsynced change${pendingCount == 1 ? '' : 's'}'
            : '$name ready';
      case CsvSyncState.pending:
        if (pendingCount > 0) {
          return '$pendingCount unsynced change${pendingCount == 1 ? '' : 's'} — '
              'Dropbox sync pending…';
        }
        return 'Saved locally — $lower sync pending…';
      case CsvSyncState.syncing:
        return pendingCount > 0
            ? 'Syncing $pendingCount change${pendingCount == 1 ? '' : 's'} to Dropbox…'
            : 'Syncing $lower to Dropbox…';
      case CsvSyncState.synced:
        return pendingCount > 0
            ? '$pendingCount local change${pendingCount == 1 ? '' : 's'} still unsynced'
            : 'All $lower changes synced to Dropbox';
      case CsvSyncState.error:
        final friendly = friendlySyncError(lastError);
        if (pendingCount > 0) {
          return '$pendingCount unsynced change${pendingCount == 1 ? '' : 's'} — $friendly';
        }
        return friendly;
    }
  }

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
      return 'Couldn’t reach Dropbox (network). Local copy is saved — tap Retry sync when online.';
    }
    if (lower.contains('oauth2/token') ||
        lower.contains('invalid_access_token') ||
        lower.contains('expired_access_token') ||
        lower.contains('401')) {
      return 'Dropbox sign-in needs refresh. Reconnect Dropbox in Settings, then Retry sync.';
    }
    final oneLine = text.replaceAll(RegExp(r'\s+'), ' ');
    if (oneLine.length <= 160) return 'Dropbox sync failed: $oneLine';
    return 'Dropbox sync failed: ${oneLine.substring(0, 157)}…';
  }

  CsvSyncStatus copyWith({
    CsvSyncState? state,
    String? lastError,
    DateTime? lastSavedAt,
    DateTime? lastSyncedAt,
    int? rowCount,
    int? pendingCount,
    String? displayName,
  }) {
    return CsvSyncStatus(
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowCount: rowCount ?? this.rowCount,
      pendingCount: pendingCount ?? this.pendingCount,
      displayName: displayName ?? this.displayName,
    );
  }
}

typedef ResolveTestingCsvUrl = Future<String> Function(
  FestivalWorkspace workspace,
);

typedef PendingChangeCounter = Future<int> Function(
  String stagingCsv,
  String? syncedCsv,
);

/// Local Testing CSV + debounced Dropbox upload (one serialized queue per instance).
class CsvStagingCoordinator extends ChangeNotifier {
  CsvStagingCoordinator({
    required this.dropboxApi,
    required this.channelSuffix,
    required this.displayName,
    required this.resolveUrl,
    this.pendingChangeCounter,
    this.debounce = const Duration(seconds: 2),
    Directory? stagingRoot,
    Future<void> Function(String url, String text)? uploadOverride,
  })  : _stagingRootOverride = stagingRoot,
        _uploadOverride = uploadOverride;

  final DropboxApi dropboxApi;
  final String channelSuffix;
  final String displayName;
  final ResolveTestingCsvUrl resolveUrl;
  final PendingChangeCounter? pendingChangeCounter;
  final Duration debounce;
  final Directory? _stagingRootOverride;
  final Future<void> Function(String url, String text)? _uploadOverride;

  CsvSyncStatus _status = const CsvSyncStatus();
  CsvSyncStatus get status => _status;

  Timer? _debounceTimer;
  Future<void>? _syncInFlight;
  FestivalWorkspace? _queuedWorkspace;
  Directory? _resolvedRoot;

  Future<Directory> _root() async {
    final override = _stagingRootOverride;
    if (override != null) return override;
    if (_resolvedRoot != null) return _resolvedRoot!;
    _resolvedRoot = await AppDataPaths.testingCsvStagingDir();
    return _resolvedRoot!;
  }

  String _festivalKey(FestivalWorkspace workspace) {
    final id = workspace.id.trim();
    return id.isEmpty ? 'default' : id;
  }

  Future<File> _csvFile(FestivalWorkspace workspace) async {
    final root = await _root();
    return File('${root.path}/${_festivalKey(workspace)}_$channelSuffix.csv');
  }

  Future<File> _syncedSnapshotFile(FestivalWorkspace workspace) async {
    final root = await _root();
    return File(
      '${root.path}/${_festivalKey(workspace)}_$channelSuffix.synced.csv',
    );
  }

  Future<File> _metaFile(FestivalWorkspace workspace) async {
    final root = await _root();
    return File(
      '${root.path}/${_festivalKey(workspace)}_$channelSuffix.meta.json',
    );
  }

  static int countDataRows(String csvText) {
    final lines = csvText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trimRight())
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return 0;
    return lines.length - 1;
  }

  static bool csvTextsEqual(String a, String b) {
    String norm(String raw) =>
        raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trimRight();
    return norm(a) == norm(b);
  }

  /// Row-level pending count for simple CSV files keyed by [keyColumn].
  static int pendingRowKeyCount({
    required String stagingCsv,
    required String? syncedCsv,
    required String keyColumn,
    String? skipKeyLower,
  }) {
    final stagingRows = parseCsvMaps(stagingCsv);
    final syncedRows = syncedCsv == null || syncedCsv.trim().isEmpty
        ? <Map<String, String>>[]
        : parseCsvMaps(syncedCsv);

    String keyOf(Map<String, String> row) =>
        (row[keyColumn] ?? '').trim().toLowerCase();

    String fingerprint(Map<String, String> row) {
      final keys = row.keys.toList()..sort();
      return keys.map((k) => '$k=${(row[k] ?? '').trim()}').join('\u001f');
    }

    bool skip(Map<String, String> row) {
      final key = keyOf(row);
      if (key.isEmpty) return true;
      if (skipKeyLower != null && key == skipKeyLower) return true;
      return false;
    }

    final syncedByKey = <String, String>{};
    for (final row in syncedRows) {
      if (skip(row)) continue;
      syncedByKey[keyOf(row)] = fingerprint(row);
    }

    final stagingKeys = <String>{};
    final pending = <String>{};
    for (final row in stagingRows) {
      if (skip(row)) continue;
      final key = keyOf(row);
      stagingKeys.add(key);
      if (syncedByKey[key] != fingerprint(row)) {
        pending.add(key);
      }
    }
    pending.addAll(syncedByKey.keys.where((k) => !stagingKeys.contains(k)));
    return pending.length;
  }

  Future<int> _pendingCount(
    String stagingCsv,
    String? syncedCsv,
  ) async {
    final counter = pendingChangeCounter;
    if (counter != null) {
      return counter(stagingCsv, syncedCsv);
    }
    return csvTextsEqual(stagingCsv, syncedCsv ?? '') ? 0 : 1;
  }

  Future<int> _pendingCountForWorkspace(FestivalWorkspace workspace) async {
    final csv = await _csvFile(workspace);
    if (!await csv.exists()) return 0;
    final snapshot = await _syncedSnapshotFile(workspace);
    final syncedText =
        await snapshot.exists() ? await snapshot.readAsString() : null;
    return _pendingCount(await csv.readAsString(), syncedText);
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
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    );
  }

  void _applyStatus(CsvSyncStatus next) {
    final normalized = next.copyWith(displayName: displayName);
    if (_status.state == normalized.state &&
        _status.lastError == normalized.lastError &&
        _status.rowCount == normalized.rowCount &&
        _status.pendingCount == normalized.pendingCount &&
        _status.lastSavedAt == normalized.lastSavedAt &&
        _status.lastSyncedAt == normalized.lastSyncedAt) {
      return;
    }
    _status = normalized;
    notifyListeners();
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

  Future<void> _writeSyncedSnapshot(
    FestivalWorkspace workspace,
    String csvText,
  ) async {
    final snapshot = await _syncedSnapshotFile(workspace);
    await snapshot.parent.create(recursive: true);
    await snapshot.writeAsString(csvText);
  }

  Future<String> _seedFromDropbox(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final url = normalizeDropboxUrl(await resolveUrl(workspace));
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
    return text;
  }

  /// Ensure local CSV exists. Seeds from Dropbox only when missing — never
  /// overwrites an existing local working copy automatically.
  Future<File> ensureStaging(FestivalWorkspace workspace) async {
    final csv = await _csvFile(workspace);
    if (!await csv.exists()) {
      await _seedFromDropbox(workspace);
    }
    await _refreshStatusFromDisk(workspace, softenStaleErrors: true);
    return csv;
  }

  Future<String> loadWorkingCsv(FestivalWorkspace workspace) async {
    final csv = await ensureStaging(workspace);
    return csv.readAsString();
  }

  /// Read the on-disk staging CSV without refreshing sync status (for compare-only).
  Future<String?> readLocalCsvIfPresent(FestivalWorkspace workspace) async {
    final csv = await _csvFile(workspace);
    if (!await csv.exists()) return null;
    return csv.readAsString();
  }

  Future<void> _refreshStatusFromDisk(
    FestivalWorkspace workspace, {
    bool softenStaleErrors = false,
  }) async {
    final csv = await _csvFile(workspace);
    final meta = await _readMeta(workspace);
    final rowCount =
        await csv.exists() ? countDataRows(await csv.readAsString()) : 0;
    final snapshot = await _syncedSnapshotFile(workspace);
    final syncedText =
        await snapshot.exists() ? await snapshot.readAsString() : null;
    final stagingText = await csv.exists() ? await csv.readAsString() : '';
    final pendingCount = await _pendingCount(stagingText, syncedText);
    var stateRaw = (meta['state'] as String?) ?? 'idle';

    if (softenStaleErrors && stateRaw == 'error') {
      stateRaw = pendingCount > 0 ? 'pending' : 'synced';
      await _writeMeta(workspace, {
        'state': stateRaw,
        'lastError': '',
      });
    }

    if (pendingCount > 0 &&
        stateRaw != 'pending' &&
        stateRaw != 'syncing' &&
        stateRaw != 'error') {
      stateRaw = 'pending';
      await _writeMeta(workspace, {'state': 'pending'});
    }

    final state = switch (stateRaw) {
      'pending' => CsvSyncState.pending,
      'syncing' => CsvSyncState.syncing,
      'synced' => CsvSyncState.synced,
      'error' => CsvSyncState.error,
      _ => CsvSyncState.idle,
    };
    _applyStatus(
      CsvSyncStatus(
        state: state,
        lastError: state == CsvSyncState.error
            ? ((meta['lastError'] as String?) ?? '')
            : '',
        lastSavedAt: _parseTime(meta['lastSavedAt']),
        lastSyncedAt: _parseTime(meta['lastSyncedAt']),
        rowCount: rowCount,
        pendingCount: pendingCount,
        displayName: displayName,
      ),
    );
  }

  Future<void> saveLocalAndQueue(
    FestivalWorkspace workspace,
    String csvText,
  ) async {
    final csv = await _csvFile(workspace);
    await csv.parent.create(recursive: true);
    await csv.writeAsString(csvText);
    final url = normalizeDropboxUrl(await resolveUrl(workspace));
    final now = DateTime.now().toUtc().toIso8601String();
    await _writeMeta(workspace, {
      'state': 'pending',
      'publishedUrl': url,
      'lastSavedAt': now,
      'lastError': '',
    });
    final snapshot = await _syncedSnapshotFile(workspace);
    final syncedText =
        await snapshot.exists() ? await snapshot.readAsString() : null;
    final pendingCount = await _pendingCount(csvText, syncedText);
    _applyStatus(
      CsvSyncStatus(
        state: CsvSyncState.pending,
        lastSavedAt: DateTime.now().toUtc(),
        lastSyncedAt: _status.lastSyncedAt,
        rowCount: countDataRows(csvText),
        pendingCount: pendingCount,
        displayName: displayName,
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

  Future<void> flushSync(FestivalWorkspace workspace) async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _queuedWorkspace = workspace;
    await _runSync(workspace);
    if (_status.state == CsvSyncState.error) {
      throw StateError(CsvSyncStatus.friendlySyncError(_status.lastError));
    }
  }

  Future<void> _runSync(FestivalWorkspace workspace) async {
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
    }
  }

  Future<void> _syncOnce(FestivalWorkspace workspace) async {
    final csv = await _csvFile(workspace);
    if (!await csv.exists()) {
      await _seedFromDropbox(workspace);
    }
    final url = normalizeDropboxUrl(await resolveUrl(workspace));
    final text = await csv.readAsString();
    final rowCount = countDataRows(text);
    final snapshot = await _syncedSnapshotFile(workspace);
    final syncedText =
        await snapshot.exists() ? await snapshot.readAsString() : null;
    final pendingCount = await _pendingCount(text, syncedText);

    _applyStatus(
      _status.copyWith(
        state: CsvSyncState.syncing,
        lastError: '',
        rowCount: rowCount,
        pendingCount: pendingCount,
        displayName: displayName,
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
      await invalidateCachedUrlText(url);
      final now = DateTime.now().toUtc();
      await _writeSyncedSnapshot(workspace, text);

      final latestCsv = await csv.readAsString();
      final stillPending = await _pendingCount(latestCsv, text);
      if ((await _readMeta(workspace))['state'] == 'pending' ||
          stillPending > 0) {
        final meta = await _readMeta(workspace);
        if ((meta['state'] as String?) != 'pending') {
          await _writeMeta(workspace, {
            'state': 'pending',
            'lastSavedAt': meta['lastSavedAt'] ?? now.toIso8601String(),
          });
        }
        _applyStatus(
          CsvSyncStatus(
            state: CsvSyncState.pending,
            lastSavedAt: _parseTime(meta['lastSavedAt']) ?? now,
            lastSyncedAt: now,
            rowCount: countDataRows(latestCsv),
            pendingCount: stillPending,
            displayName: displayName,
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
        CsvSyncStatus(
          state: CsvSyncState.synced,
          lastSavedAt: _parseTime((await _readMeta(workspace))['lastSavedAt']) ??
              now,
          lastSyncedAt: now,
          rowCount: rowCount,
          pendingCount: 0,
          displayName: displayName,
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
          state: CsvSyncState.error,
          lastError: message,
          pendingCount: await _pendingCountForWorkspace(workspace),
          displayName: displayName,
        ),
      );
    }
  }

  /// Explicitly discard local edits and reload from Testing Dropbox.
  Future<String> reloadFromPublished(
    FestivalWorkspace workspace, {
    bool forceRefresh = true,
  }) async {
    _debounceTimer?.cancel();
    final url = normalizeDropboxUrl(await resolveUrl(workspace));
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

  Future<String?> readSyncedSnapshot(FestivalWorkspace workspace) async {
    final snapshot = await _syncedSnapshotFile(workspace);
    if (!await snapshot.exists()) return null;
    return snapshot.readAsString();
  }

  /// Explicitly discard local edits and reload from Testing Dropbox.
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
    _applyStatus(CsvSyncStatus(displayName: displayName));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
