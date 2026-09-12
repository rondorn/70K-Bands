import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/app_data_paths.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/local_content_store.dart';

/// Sync lifecycle for a local Testing CSV staging file.
enum CsvSyncState {
  idle,
  pending,
  syncing,
  synced,
  error,
}

/// Soft load of local staging: show immediately, optionally refresh in background.
class CsvStagingSoftLoad {
  const CsvStagingSoftLoad({
    required this.csvText,
    required this.shouldRefreshInBackground,
  });

  final String csvText;

  /// True when local data is missing/expired and safe to overwrite from Dropbox.
  final bool shouldRefreshInBackground;
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

/// Builds a stable row identity for live-CSV merge (artists, schedule, map).
typedef CsvRowKey = String Function(Map<String, String> row);

/// Local Testing CSV + debounced Dropbox upload (one serialized queue per instance).
class CsvStagingCoordinator extends ChangeNotifier {
  CsvStagingCoordinator({
    required this.dropboxApi,
    required this.channelSuffix,
    required this.displayName,
    required this.resolveUrl,
    this.pendingChangeCounter,
    this.mergeKeyColumn,
    this.mergeKeyColumns,
    this.mergeRowKey,
    this.mergeSkipKeyLower,
    this.debounce = const Duration(seconds: 2),
    Directory? stagingRoot,
    Future<void> Function(String url, String text)? uploadOverride,
    Future<String> Function(String locator)? fetchPublishedOverride,
  })  : _stagingRootOverride = stagingRoot,
        _uploadOverride = uploadOverride,
        _fetchPublishedOverride = fetchPublishedOverride;

  final DropboxApi dropboxApi;
  final String channelSuffix;
  final String displayName;
  final ResolveTestingCsvUrl resolveUrl;
  final PendingChangeCounter? pendingChangeCounter;
  /// When any merge identity is set, local saves overlay onto the live
  /// published CSV so remote-only rows (e.g. automation) are not overwritten.
  final String? mergeKeyColumn;
  final List<String>? mergeKeyColumns;
  final CsvRowKey? mergeRowKey;
  final String? mergeSkipKeyLower;

  bool get mergeEnabled {
    if (mergeRowKey != null) return true;
    final columns = mergeKeyColumns;
    if (columns != null && columns.isNotEmpty) return true;
    return (mergeKeyColumn?.trim() ?? '').isNotEmpty;
  }
  final Duration debounce;
  final Directory? _stagingRootOverride;
  final Future<void> Function(String url, String text)? _uploadOverride;
  final Future<String> Function(String locator)? _fetchPublishedOverride;

  /// How long a published fetch stays fresh before background revalidation.
  static const Duration publishedCacheTtl = Duration(minutes: 10);

  /// Overlapping Dropbox writers: re-download, merge, and retry this many times.
  static const int mergeUploadAttempts = 5;

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

  static CsvRowKey resolveMergeRowKey({
    String? keyColumn,
    List<String>? keyColumns,
    CsvRowKey? rowKey,
  }) {
    if (rowKey != null) return rowKey;
    final columns = [
      if (keyColumns != null) ...keyColumns,
      if ((keyColumn?.trim() ?? '').isNotEmpty) keyColumn!.trim(),
    ];
    if (columns.isEmpty) {
      throw ArgumentError('merge requires keyColumn, keyColumns, or rowKey');
    }
    return (row) => columns
        .map((c) => (row[c] ?? '').trim().toLowerCase())
        .join('|');
  }

  static bool _skipMergeRow(
    String key,
    String? skipKeyLower,
  ) {
    if (key.isEmpty) return true;
    if (skipKeyLower == null || skipKeyLower.isEmpty) return false;
    if (key == skipKeyLower) return true;
    return key.split('|').first == skipKeyLower;
  }

  /// Fingerprint ignores empty values so missing vs blank extra columns match.
  static String rowFingerprint(Map<String, String> row) {
    final keys = row.keys
        .where((k) => (row[k] ?? '').trim().isNotEmpty)
        .toList()
      ..sort();
    return keys.map((k) => '$k=${row[k]!.trim()}').join('\u001f');
  }

  static ({Map<String, Map<String, String>> byKey, List<String> order})
      _rowsByResolvedKey(
    String csv, {
    required CsvRowKey keyOf,
    String? skipKeyLower,
  }) {
    final byKey = <String, Map<String, String>>{};
    final order = <String>[];
    if (csv.trim().isEmpty) {
      return (byKey: byKey, order: order);
    }
    for (final row in parseCsvMaps(csv)) {
      final key = keyOf(row);
      if (_skipMergeRow(key, skipKeyLower)) continue;
      if (!byKey.containsKey(key)) {
        order.add(key);
      }
      byKey[key] = Map<String, String>.from(row);
    }
    return (byKey: byKey, order: order);
  }

  static List<String> csvHeaderFields(String csv) {
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trimRight())
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];
    return [
      for (final header in parseCsvLine(lines.first))
        if (header.trim().isNotEmpty) header.trim(),
    ];
  }

  static List<String> mergeOutputFields({
    required String publishedCsv,
    required String localCsv,
    required String? lastSyncedCsv,
  }) {
    final seen = <String>{};
    final out = <String>[];
    void add(List<String> fields) {
      for (final raw in fields) {
        final field = raw.trim();
        if (field.isEmpty || seen.contains(field)) continue;
        seen.add(field);
        out.add(field);
      }
    }

    add(csvHeaderFields(publishedCsv));
    add(csvHeaderFields(localCsv));
    add(csvHeaderFields(lastSyncedCsv ?? ''));
    if (out.isEmpty) {
      for (final row in [
        ...parseCsvMaps(publishedCsv),
        ...parseCsvMaps(localCsv),
        ...parseCsvMaps(lastSyncedCsv ?? ''),
      ]) {
        add(row.keys.toList());
      }
    }
    return out;
  }

  /// Rebuild [publishedCsv] with only the row changes in [localCsv] relative
  /// to [lastSyncedCsv]. Remote-only rows are kept. Deletes apply only for
  /// keys present in the last synced snapshot (keys the admin actually had).
  ///
  /// Published row order is kept; new local keys are appended. Identity
  /// changes (renamed band, moved set time) show up as a delete of the old
  /// key plus an add of the new one.
  static String mergeRemoteWithLocalEdits({
    required String publishedCsv,
    required String localCsv,
    required String? lastSyncedCsv,
    String? keyColumn,
    List<String>? keyColumns,
    CsvRowKey? rowKey,
    String? skipKeyLower,
  }) {
    final keyOf = resolveMergeRowKey(
      keyColumn: keyColumn,
      keyColumns: keyColumns,
      rowKey: rowKey,
    );
    final published = _rowsByResolvedKey(
      publishedCsv,
      keyOf: keyOf,
      skipKeyLower: skipKeyLower,
    );
    final local = _rowsByResolvedKey(
      localCsv,
      keyOf: keyOf,
      skipKeyLower: skipKeyLower,
    );
    final synced = _rowsByResolvedKey(
      lastSyncedCsv ?? '',
      keyOf: keyOf,
      skipKeyLower: skipKeyLower,
    );

    final result = <String, Map<String, String>>{
      for (final key in published.order)
        key: Map<String, String>.from(published.byKey[key]!),
    };
    final order = List<String>.from(published.order);

    for (final key in local.order) {
      final localRow = local.byKey[key]!;
      final syncedRow = synced.byKey[key];
      if (syncedRow == null) {
        final publishedRow = result[key];
        if (publishedRow == null) {
          result[key] = localRow;
          order.add(key);
        } else if (rowFingerprint(localRow) != rowFingerprint(publishedRow)) {
          result[key] = localRow;
        }
      } else if (rowFingerprint(localRow) != rowFingerprint(syncedRow)) {
        result[key] = localRow;
      }
    }

    for (final key in synced.byKey.keys) {
      if (!local.byKey.containsKey(key)) {
        result.remove(key);
        order.remove(key);
      }
    }

    final rows = [
      for (final key in order)
        if (result.containsKey(key)) result[key]!,
    ];
    final fields = mergeOutputFields(
      publishedCsv: publishedCsv,
      localCsv: localCsv,
      lastSyncedCsv: lastSyncedCsv,
    );
    if (fields.isEmpty) return '';
    return mapsToCsv(fields, rows);
  }

  String _mergeUsingConfig({
    required String publishedCsv,
    required String localCsv,
    required String? lastSyncedCsv,
  }) {
    return mergeRemoteWithLocalEdits(
      publishedCsv: publishedCsv,
      localCsv: localCsv,
      lastSyncedCsv: lastSyncedCsv,
      keyColumn: mergeKeyColumn,
      keyColumns: mergeKeyColumns,
      rowKey: mergeRowKey,
      skipKeyLower: mergeSkipKeyLower,
    );
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

  Future<DateTime?> lastFetchedAt(FestivalWorkspace workspace) async {
    final meta = await _readMeta(workspace);
    return _parseTime(meta['lastFetchedAt']);
  }

  /// True when there is no local CSV, no fetch timestamp, or age exceeds TTL.
  ///
  /// Expired caches are kept on disk; callers may still display them.
  Future<bool> isPublishedCacheExpired(FestivalWorkspace workspace) async {
    final csv = await _csvFile(workspace);
    if (!await csv.exists()) return true;
    final fetched = await lastFetchedAt(workspace);
    if (fetched == null) return true;
    final age = DateTime.now().toUtc().difference(fetched.toUtc());
    return age > publishedCacheTtl;
  }

  Future<String> _seedFromDropbox(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final url = await resolveUrl(workspace);
    final text = await _fetchPublishedContent(
      url,
      forceRefresh: forceRefresh,
    );
    final publishedLocator = LocalContentStore.isLocalLocator(url)
        ? LocalContentStore.expandPath(url)
        : normalizeDropboxUrl(url);
    final csv = await _csvFile(workspace);
    await csv.parent.create(recursive: true);
    await csv.writeAsString(text);
    await _writeSyncedSnapshot(workspace, text);
    final now = DateTime.now().toUtc().toIso8601String();
    await _writeMeta(workspace, {
      'state': 'synced',
      'publishedUrl': publishedLocator,
      'lastSyncedAt': now,
      'lastSavedAt': now,
      'lastFetchedAt': now,
      'lastError': '',
    });
    return text;
  }

  Future<({String text, String rev})> _downloadPublishedForMerge(
    String locator,
  ) async {
    final fetchOverride = _fetchPublishedOverride;
    if (fetchOverride != null) {
      return (text: await fetchOverride(locator), rev: '');
    }
    if (LocalContentStore.isLocalLocator(locator)) {
      return (
        text: await LocalContentStore.readText(locator),
        rev: '',
      );
    }
    final path = await dropboxApi.resolveApiPath(normalizeDropboxUrl(locator));
    return dropboxApi.downloadTextWithRevAtPath(path);
  }

  Future<String> _fetchPublishedContent(
    String locator, {
    bool forceRefresh = false,
  }) async {
    final fetchOverride = _fetchPublishedOverride;
    if (fetchOverride != null) {
      return fetchOverride(locator);
    }
    if (LocalContentStore.isLocalLocator(locator)) {
      return LocalContentStore.readText(locator);
    }
    return fetchUrlText(
      normalizeDropboxUrl(locator),
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _publishContent(
    String locator,
    String text, {
    String? ifRev,
  }) async {
    if (LocalContentStore.isLocalLocator(locator)) {
      await LocalContentStore.writeText(locator, text);
      return;
    }
    final upload = _uploadOverride;
    if (upload != null) {
      await upload(locator, text);
      return;
    }
    await dropboxApi.uploadTextInPlace(
      normalizeDropboxUrl(locator),
      text,
      ifRev: ifRev,
    );
  }

  String _normalizePublishedLocator(String locator) {
    if (LocalContentStore.isLocalLocator(locator)) {
      return LocalContentStore.expandPath(locator);
    }
    return normalizeDropboxUrl(locator);
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

  /// Read local staging without network seed. Flags background refresh when
  /// cache is missing/expired and there are no unsynced local edits.
  Future<CsvStagingSoftLoad> loadWorkingCsvSoft(
    FestivalWorkspace workspace,
  ) async {
    final csv = await _csvFile(workspace);
    var text = '';
    if (await csv.exists()) {
      text = await csv.readAsString();
      await _refreshStatusFromDisk(workspace, softenStaleErrors: true);
    } else {
      _applyStatus(CsvSyncStatus(displayName: displayName));
    }
    final expired = await isPublishedCacheExpired(workspace);
    final shouldRefresh = expired && !_status.hasUnsynced;
    return CsvStagingSoftLoad(
      csvText: text,
      shouldRefreshInBackground: shouldRefresh,
    );
  }

  /// Reload from Dropbox when safe (no unsynced local edits). Returns null if
  /// skipped to preserve pending changes.
  Future<String?> refreshPublishedInBackground(
    FestivalWorkspace workspace,
  ) async {
    await _refreshStatusFromDisk(workspace, softenStaleErrors: true);
    if (_status.hasUnsynced) return null;
    return reloadFromPublished(workspace, forceRefresh: true);
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
    final rawUrl = await resolveUrl(workspace);
    final url = _normalizePublishedLocator(rawUrl);
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
    final urlRaw = await resolveUrl(workspace);
    final url = _normalizePublishedLocator(urlRaw);
    try {
      var text = await csv.readAsString();
      var rowCount = countDataRows(text);
      final snapshot = await _syncedSnapshotFile(workspace);
      var syncedText =
          await snapshot.exists() ? await snapshot.readAsString() : null;
      var pendingCount = await _pendingCount(text, syncedText);

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

      for (var attempt = 0; attempt < mergeUploadAttempts; attempt++) {
        text = await csv.readAsString();
        syncedText =
            await snapshot.exists() ? await snapshot.readAsString() : null;
        String? ifRev;
        if (mergeEnabled) {
          try {
            final live = await _downloadPublishedForMerge(urlRaw);
            ifRev = live.rev.isEmpty ? null : live.rev;
            final merged = _mergeUsingConfig(
              publishedCsv: live.text,
              localCsv: text,
              lastSyncedCsv: syncedText,
            );
            if (!csvTextsEqual(merged, text)) {
              debugPrint('$displayName: merged live CSV before upload');
              await csv.writeAsString(merged);
              text = merged;
            }
          } catch (e) {
            if (e is DropboxRevisionConflict) rethrow;
            debugPrint('$displayName: live merge skipped before upload: $e');
            ifRev = null;
          }
        }
        pendingCount = await _pendingCount(text, syncedText);
        rowCount = countDataRows(text);

        try {
          await _publishContent(urlRaw, text, ifRev: ifRev);
          break;
        } on DropboxRevisionConflict {
          if (attempt >= mergeUploadAttempts - 1) rethrow;
          debugPrint(
            '$displayName: Dropbox revision conflict, retrying merge '
            '(${attempt + 1}/$mergeUploadAttempts)',
          );
          await Future<void>.delayed(
            Duration(milliseconds: 120 * (attempt + 1)),
          );
        }
      }
      if (!LocalContentStore.isLocalLocator(urlRaw)) {
        await invalidateCachedUrlText(normalizeDropboxUrl(urlRaw));
      }
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
        // Local upload matches published — treat as a fresh fetch clock too.
        'lastFetchedAt': now.toIso8601String(),
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
    final rawUrl = await resolveUrl(workspace);
    final url = _normalizePublishedLocator(rawUrl);
    final text = await _fetchPublishedContent(
      rawUrl,
      forceRefresh: forceRefresh,
    );
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
      'lastFetchedAt': now,
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

  /// Fetch the live published CSV and overlay only this device's row edits.
  ///
  /// Returns [localCsv] unchanged when merge is not configured or the fetch
  /// fails (caller should still save locally).
  Future<String> mergeLocalCsvWithPublished(
    FestivalWorkspace workspace,
    String localCsv,
  ) async {
    if (!mergeEnabled) return localCsv;
    final url = await resolveUrl(workspace);
    final live = await _downloadPublishedForMerge(url);
    final snapshot = await readSyncedSnapshot(workspace);
    return _mergeUsingConfig(
      publishedCsv: live.text,
      localCsv: localCsv,
      lastSyncedCsv: snapshot,
    );
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
