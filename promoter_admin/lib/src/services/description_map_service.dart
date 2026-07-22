import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/user_description_folder_store.dart';

class DescriptionMapEntry {
  DescriptionMapEntry({
    required this.band,
    required this.url,
    required this.date,
  });

  final String band;
  final String url;
  final String date;

  Map<String, String> asRow() => {
        'Band': band,
        'URL': url,
        'Date': date,
      };

  static DescriptionMapEntry fromRow(Map<String, String> row) {
    return DescriptionMapEntry(
      band: (row['Band'] ?? '').trim(),
      url: (row['URL'] ?? '').trim(),
      date: (row['Date'] ?? '').trim(),
    );
  }
}

class DescriptionMapService {
  DescriptionMapService({
    required this.pointerService,
    required this.dropboxApi,
    UserDescriptionFolderStore? userFolderStore,
  }) : userFolderStore = userFolderStore ?? UserDescriptionFolderStore();

  final PointerService pointerService;
  final DropboxApi dropboxApi;
  final UserDescriptionFolderStore userFolderStore;

  static const columns = ['Band', 'URL', 'Date'];

  Future<List<DescriptionMapEntry>> load(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final url = await _mapUrl(workspace, forceRefresh: forceRefresh);
    final text = await fetchUrlText(url, forceRefresh: forceRefresh);
    return parseEntries(text);
  }

  Future<void> save(
    FestivalWorkspace workspace,
    List<DescriptionMapEntry> entries,
  ) async {
    final url = await _mapUrl(workspace);
    await dropboxApi.uploadTextInPlace(url, toCsv(entries));
  }

  /// Writes a description .txt beside the map file and returns a share URL.
  Future<String> writeDescriptionFile({
    required FestivalWorkspace workspace,
    required String labelName,
    required String text,
  }) async {
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
    final url = normalizeDropboxUrl(shareUrl.trim());
    if (label.isEmpty || url.isEmpty) {
      throw StateError('Band name and description URL are required.');
    }
    final previousText = await loadDescriptionText(url, forceRefresh: true);
    if (previousText == text) {
      return;
    }
    await dropboxApi.uploadTextInPlace(url, text);
    await upsertMapEntry(
      workspace: workspace,
      labelName: label,
      url: url,
      bumpDate: true,
      forceRefreshMap: true,
    );
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
    final normalizedUrl = normalizeDropboxUrl(url.trim());
    if (label.isEmpty || normalizedUrl.isEmpty) {
      throw StateError('Band / event name and Dropbox URL are required.');
    }
    final entries = await load(
      workspace,
      forceRefresh: bumpDate && forceRefreshMap,
    );
    final updated = List<DescriptionMapEntry>.from(entries);
    final idx = updated.indexWhere(
      (e) => e.band.toLowerCase() == label.toLowerCase(),
    );
    final previousDate = idx >= 0 ? updated[idx].date : '';
    final date = explicitDate?.trim().isNotEmpty == true
        ? explicitDate!.trim()
        : (bumpDate
            ? nextCacheDate(previousDate)
            : (previousDate.isEmpty ? cacheDateToday() : previousDate));
    final entry = DescriptionMapEntry(
      band: label,
      url: normalizedUrl,
      date: date,
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

  Future<String> loadDescriptionText(
    String shareUrl, {
    bool forceRefresh = false,
  }) async {
    final url = normalizeDropboxUrl(shareUrl.trim());
    if (url.isEmpty) {
      throw StateError('Description URL is required.');
    }
    return fetchUrlText(url, forceRefresh: forceRefresh);
  }

  static List<DescriptionMapEntry> parseEntries(String text) {
    final rows = parseCsvMaps(text);
    final entries = <DescriptionMapEntry>[];
    for (final row in rows) {
      final band = (row['Band'] ?? '').trim();
      if (band.isEmpty || band.toLowerCase() == 'band') continue;
      entries.add(DescriptionMapEntry.fromRow(row));
    }
    entries.sort((a, b) => a.band.toLowerCase().compareTo(b.band.toLowerCase()));
    return entries;
  }

  static String toCsv(List<DescriptionMapEntry> entries) {
    return mapsToCsv(columns, entries.map((e) => e.asRow()).toList());
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

  Future<String> _mapUrl(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
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
