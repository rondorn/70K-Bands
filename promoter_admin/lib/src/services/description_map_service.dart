import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_staging.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/dropbox_auth.dart';
import 'package:promoter_admin/src/services/emergency_local_mode_support.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/local_content_store.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/user_description_folder_store.dart';

class DescriptionMapEntry {
  DescriptionMapEntry({
    required this.band,
    required this.url,
    required this.date,
    this.updatedBy = '',
  });

  final String band;
  final String url;
  final String date;
  final String updatedBy;

  Map<String, String> asRow() => {
        'Band': band,
        'URL': url,
        'Date': date,
        'UpdatedBy': updatedBy,
      };

  static DescriptionMapEntry fromRow(Map<String, String> row) {
    return DescriptionMapEntry(
      band: (row['Band'] ?? '').trim(),
      url: (row['URL'] ?? '').trim(),
      date: (row['Date'] ?? '').trim(),
      updatedBy: DescriptionMapService.normalizeUpdatedBy(row['UpdatedBy']),
    );
  }
}

class DescriptionMapService {
  DescriptionMapService({
    required this.pointerService,
    required this.dropboxApi,
    this.dropboxAuth,
    UserDescriptionFolderStore? userFolderStore,
    CsvStagingCoordinator? staging,
  })  : userFolderStore = userFolderStore ?? UserDescriptionFolderStore(),
        staging = staging ??
            CsvStagingCoordinator(
              dropboxApi: dropboxApi,
              channelSuffix: 'description_map',
              displayName: 'Description map',
              resolveUrl: (workspace) async {
                if (workspace.usesEmergencyLocalMode) {
                  final path =
                      workspace.emergencyLocalPaths.descriptionMapCsv.trim();
                  if (path.isEmpty) {
                    throw StateError(
                      'Description map CSV path is not configured.',
                    );
                  }
                  return path;
                }
                var url = workspace.descriptionMapUrl.trim();
                if (url.isEmpty) {
                  final refreshed = await pointerService.applyTestingPointer(
                    workspace,
                  );
                  url = refreshed.descriptionMapUrl.trim();
                }
                if (url.isEmpty) {
                  throw StateError(
                    'Testing pointer has no Current::descriptionMap.',
                  );
                }
                return url;
              },
              pendingChangeCounter: (stagingCsv, syncedCsv) async {
                return CsvStagingCoordinator.pendingRowKeyCount(
                  stagingCsv: stagingCsv,
                  syncedCsv: syncedCsv,
                  keyColumn: 'Band',
                  skipKeyLower: 'band',
                );
              },
            );

  final PointerService pointerService;
  final DropboxApi dropboxApi;
  final DropboxAuth? dropboxAuth;
  final UserDescriptionFolderStore userFolderStore;
  final CsvStagingCoordinator staging;

  CsvSyncStatus get syncStatus => staging.status;

  void addSyncListener(VoidCallback listener) => staging.addListener(listener);

  void removeSyncListener(VoidCallback listener) =>
      staging.removeListener(listener);

  static const baseColumns = ['Band', 'URL', 'Date'];
  static const updatedByColumn = 'UpdatedBy';

  /// CSV columns for [entries]. [UpdatedBy] is omitted unless at least one row
  /// has an editor (automated maps are typically Band/URL/Date only).
  static List<String> columnsFor(List<DescriptionMapEntry> entries) {
    final hasUpdatedBy = entries.any(
      (e) => normalizeUpdatedBy(e.updatedBy).isNotEmpty,
    );
    if (hasUpdatedBy) return [...baseColumns, updatedByColumn];
    return baseColumns;
  }

  /// Treats missing, blank, literal "null", and null-character values as empty.
  static String normalizeUpdatedBy(String? value) {
    if (value == null) return '';
    final stripped = value.replaceAll('\x00', '').trim();
    if (stripped.isEmpty) return '';
    if (stripped.toLowerCase() == 'null') return '';
    return stripped;
  }

  Future<List<DescriptionMapEntry>> load(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final text = forceRefresh
        ? await staging.reloadFromPublished(
            workspace,
            forceRefresh: true,
          )
        : await staging.loadWorkingCsv(workspace);
    return parseEntries(text);
  }

  /// Save map CSV locally and queue background Dropbox sync.
  ///
  /// Individual description `.txt` files still upload immediately via
  /// [writeDescriptionFile] and related helpers.
  Future<void> save(
    FestivalWorkspace workspace,
    List<DescriptionMapEntry> entries,
  ) async {
    await staging.saveLocalAndQueue(workspace, toCsv(entries));
  }

  Future<void> flushSync(FestivalWorkspace workspace) =>
      staging.flushSync(workspace);

  void dispose() => staging.dispose();

  /// Writes a description .txt beside the map file and returns a share URL.
  Future<String> writeDescriptionFile({
    required FestivalWorkspace workspace,
    required String labelName,
    required String text,
  }) async {
    if (workspace.usesEmergencyLocalMode) {
      final path = LocalContentStore.descriptionFilePath(
        paths: workspace.emergencyLocalPaths,
        labelName: labelName,
      );
      await LocalContentStore.writeText(path, text);
      return path;
    }
    final mapUrl = await _mapUrl(workspace);
    final mapPath = await dropboxApi.resolveApiPath(mapUrl);
    final parent = mapPath.contains('/')
        ? mapPath.substring(0, mapPath.lastIndexOf('/'))
        : '';
    return writeDescriptionFileToFolder(
      folderApiPath: '$parent/descriptions',
      labelName: labelName,
      text: text,
    );
  }

  /// Writes a description .txt under a Dropbox folder (creates folder if needed).
  Future<String> writeDescriptionFileToFolder({
    required String folderApiPath,
    required String labelName,
    required String text,
  }) async {
    final safe = safeFileStem(labelName);
    if (safe.isEmpty) {
      throw StateError('Band / event name is required.');
    }
    var folder = folderApiPath.trim().replaceAll('\\', '/');
    if (folder.isEmpty) {
      throw StateError('A Dropbox folder is required to save the description.');
    }
    if (!folder.startsWith('/')) folder = '/$folder';
    folder = folder.replaceAll(RegExp(r'/+$'), '');
    if (folder.isEmpty) folder = '';
    if (folder.isNotEmpty) {
      await dropboxApi.ensureFolder(folder);
    }
    final path = folder.isEmpty ? '/$safe.txt' : '$folder/$safe.txt';
    return dropboxApi.uploadNewTextFileAndShare(path, text);
  }

  /// Saves under the user's remembered folder (prompts caller if missing).
  Future<String> writeDescriptionFileForUser({
    required String labelName,
    required String text,
    required Future<String?> Function() promptForFolder,
  }) async {
    var folder = await userFolderStore.load();
    if (folder == null || folder.trim().isEmpty) {
      folder = await promptForFolder();
      if (folder == null || folder.trim().isEmpty) {
        throw StateError('Choose a Dropbox folder to save descriptions.');
      }
      await userFolderStore.save(folder);
    }
    return writeDescriptionFileToFolder(
      folderApiPath: folder,
      labelName: labelName,
      text: text,
    );
  }

  /// Save description text and upsert the map row for [labelName].
  /// Returns the share URL stored on the map.
  Future<String> writeDescriptionAndUpsertMap({
    required FestivalWorkspace workspace,
    required String labelName,
    required String text,
  }) async {
    final label = labelName.trim();
    if (label.isEmpty) {
      throw StateError('Band / event name is required.');
    }
    final shareUrl = await writeDescriptionFile(
      workspace: workspace,
      labelName: label,
      text: text,
    );
    await upsertMapEntry(
      workspace: workspace,
      labelName: label,
      url: shareUrl,
      bumpDate: true,
    );
    return shareUrl;
  }

  /// Update text at an existing share URL.
  ///
  /// When [text] differs from the file on Dropbox, overwrites the description
  /// file and bumps that band's cache [Date] in the description map only
  /// (pointer files are untouched) via [nextCacheDate].
  Future<void> updateDescriptionTextInPlace({
    required FestivalWorkspace workspace,
    required String labelName,
    required String shareUrl,
    required String text,
  }) async {
    final label = labelName.trim();
    final rawUrl = shareUrl.trim();
    if (label.isEmpty || rawUrl.isEmpty) {
      throw StateError('Band name and description URL are required.');
    }
    final url = LocalContentStore.isLocalLocator(rawUrl)
        ? LocalContentStore.expandPath(rawUrl)
        : normalizeDropboxUrl(rawUrl);
    final entries = await load(workspace);
    final idx = entries.indexWhere(
      (e) => e.band.toLowerCase() == label.toLowerCase(),
    );
    final previousDate = idx >= 0 ? entries[idx].date : '';
    final previousText = await loadDescriptionText(
      url,
      mapDate: previousDate,
    );
    if (previousText == text) {
      return;
    }
    if (LocalContentStore.isLocalLocator(url)) {
      await LocalContentStore.writeText(url, text);
    } else {
      await dropboxApi.uploadTextInPlace(url, text);
    }
    final newDate = nextCacheDate(previousDate);
    await upsertMapEntry(
      workspace: workspace,
      labelName: label,
      url: url,
      bumpDate: true,
      explicitDate: newDate,
    );
    await putCachedUrlText(descriptionTextCacheKey(url, newDate), text);
    await invalidateCachedUrlText(url);
  }

  /// Insert or replace a map row (URL link). Bumps Date when [bumpDate] is true.
  Future<void> upsertMapEntry({
    required FestivalWorkspace workspace,
    required String labelName,
    required String url,
    bool bumpDate = true,
    String? explicitDate,
    bool forceRefreshMap = false,
  }) async {
    final label = labelName.trim();
    final normalizedUrl = url.trim();
    if (label.isEmpty || normalizedUrl.isEmpty) {
      throw StateError('Band / event name and description location are required.');
    }
    final storedUrl = LocalContentStore.isLocalLocator(normalizedUrl)
        ? LocalContentStore.expandPath(normalizedUrl)
        : normalizeDropboxUrl(normalizedUrl);
    final entries = await load(
      workspace,
      forceRefresh: forceRefreshMap,
    );
    final updated = List<DescriptionMapEntry>.from(entries);
    final idx = updated.indexWhere(
      (e) => e.band.toLowerCase() == label.toLowerCase(),
    );
    final previousDate = idx >= 0 ? updated[idx].date : '';
    final previousUpdatedBy = idx >= 0 ? updated[idx].updatedBy : '';
    final date = explicitDate?.trim().isNotEmpty == true
        ? explicitDate!.trim()
        : (bumpDate
            ? nextCacheDate(previousDate)
            : (previousDate.isEmpty ? cacheDateToday() : previousDate));
    final shouldStampEditor = bumpDate || idx < 0;
    final updatedBy = normalizeUpdatedBy(
      shouldStampEditor ? await _currentEditorLabel() : previousUpdatedBy,
    );
    final entry = DescriptionMapEntry(
      band: label,
      url: storedUrl,
      date: date,
      updatedBy: updatedBy,
    );
    if (idx >= 0) {
      updated[idx] = entry;
    } else {
      updated.add(entry);
    }
    updated.sort(
      (a, b) => a.band.toLowerCase().compareTo(b.band.toLowerCase()),
    );
    await save(workspace, updated);
  }

  Future<void> removeMapEntry({
    required FestivalWorkspace workspace,
    required String labelName,
  }) async {
    final label = labelName.trim().toLowerCase();
    final entries = await load(workspace);
    final updated = entries
        .where((e) => e.band.toLowerCase() != label)
        .toList();
    await save(workspace, updated);
  }

  /// Cache key for description .txt bodies — mirrors fan apps' BandName.note-DATE.
  ///
  /// [mapDate] is an opaque string from descriptionMap CSV (not parsed as a date).
  /// When the string changes, cached text is missed and re-fetched.
  static String descriptionTextCacheKey(String shareUrl, String mapDate) {
    final url = normalizeDropboxUrl(shareUrl.trim());
    final date = mapDate.trim();
    if (url.isEmpty) return '';
    if (date.isEmpty) return url;
    return '$url::desc::$date';
  }

  /// Loads description text for [shareUrl], cached under [mapDate].
  ///
  /// Re-fetches from the network when [mapDate] differs from the last cached
  /// lookup for this URL, or when [forceRefresh] is true.
  Future<String> loadDescriptionText(
    String shareUrl, {
    required String mapDate,
    bool forceRefresh = false,
  }) async {
    final url = shareUrl.trim();
    if (url.isEmpty) {
      throw StateError('Description URL is required.');
    }
    if (LocalContentStore.isLocalLocator(url)) {
      return LocalContentStore.readText(url);
    }
    final normalized = normalizeDropboxUrl(url);
    return fetchUrlText(
      normalized,
      cacheKey: descriptionTextCacheKey(normalized, mapDate),
      forceRefresh: forceRefresh,
    );
  }

  static List<DescriptionMapEntry> parseEntries(String text) {
    final rows = parseCsvMaps(text);
    final entries = <DescriptionMapEntry>[];
    for (final row in rows) {
      final band = (row['Band'] ?? '').trim();
      if (band.isEmpty || band.toLowerCase() == 'band') continue;
      final parsed = DescriptionMapEntry.fromRow(row);
      entries.add(
        DescriptionMapEntry(
          band: parsed.band,
          url: LocalContentStore.isLocalLocator(parsed.url)
              ? LocalContentStore.expandPath(parsed.url)
              : normalizeDropboxUrl(parsed.url),
          date: parsed.date,
          updatedBy: parsed.updatedBy,
        ),
      );
    }
    entries.sort((a, b) => a.band.toLowerCase().compareTo(b.band.toLowerCase()));
    return entries;
  }

  static String toCsv(List<DescriptionMapEntry> entries) {
    final fields = columnsFor(entries);
    return mapsToCsv(fields, entries.map((e) => e.asRow()).toList());
  }

  static String cacheDateToday() {
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '$mm-$dd-${now.year}';
  }

  /// Bumps cache date so fan apps refresh. Same calendar day → `-1`, `-2`, …
  static String nextCacheDate(String? existing, {DateTime? now}) {
    final today = () {
      final n = now ?? DateTime.now();
      final mm = n.month.toString().padLeft(2, '0');
      final dd = n.day.toString().padLeft(2, '0');
      return '$mm-$dd-${n.year}';
    }();
    final e = (existing ?? '').trim();
    if (e.isEmpty || e == today) {
      return e == today ? '$today-1' : today;
    }
    final prefix = '$today-';
    if (e.startsWith(prefix)) {
      final n = int.tryParse(e.substring(prefix.length));
      if (n != null && n >= 1) return '$today-${n + 1}';
    }
    return today;
  }

  static String safeFileStem(String labelName) {
    return labelName
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-.]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  Future<String> _currentEditorLabel() async {
    final auth = dropboxAuth;
    if (auth == null) return '';
    return (await auth.accountLabel()).trim();
  }

  Future<String> _mapUrl(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    if (workspace.usesEmergencyLocalMode) {
      final path = workspace.emergencyLocalPaths.descriptionMapCsv.trim();
      if (path.isEmpty) {
        throw StateError('Description map CSV path is not configured.');
      }
      return path;
    }
    var url = workspace.descriptionMapUrl.trim();
    if (url.isEmpty) {
      final refreshed = await pointerService.applyTestingPointer(
        workspace,
        forceRefresh: forceRefresh,
      );
      url = refreshed.descriptionMapUrl.trim();
    }
    if (url.isEmpty) {
      throw StateError('Testing pointer has no Current::descriptionMap.');
    }
    return url;
  }
}
