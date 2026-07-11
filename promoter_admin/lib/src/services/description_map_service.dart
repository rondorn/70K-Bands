import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

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
  });

  final PointerService pointerService;
  final DropboxApi dropboxApi;

  static const columns = ['Band', 'URL', 'Date'];

  Future<List<DescriptionMapEntry>> load(FestivalWorkspace workspace) async {
    final url = await _mapUrl(workspace);
    final text = await fetchUrlText(url);
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
    final safe = labelName
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-.]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (safe.isEmpty) {
      throw StateError('Band / event name is required.');
    }
    final path = '$parent/descriptions/$safe.txt';
    await dropboxApi.ensureFolder('$parent/descriptions');
    return dropboxApi.uploadNewTextFileAndShare(path, text);
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
    final entries = await load(workspace);
    final updated = List<DescriptionMapEntry>.from(entries);
    final idx = updated.indexWhere(
      (e) => e.band.toLowerCase() == label.toLowerCase(),
    );
    final entry = DescriptionMapEntry(
      band: label,
      url: shareUrl,
      date: cacheDateToday(),
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
    return shareUrl;
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

  Future<String> _mapUrl(FestivalWorkspace workspace) async {
    var url = workspace.descriptionMapUrl.trim();
    if (url.isEmpty) {
      final refreshed = await pointerService.applyTestingPointer(workspace);
      url = refreshed.descriptionMapUrl.trim();
    }
    if (url.isEmpty) {
      throw StateError('Testing pointer has no Current::descriptionMap.');
    }
    return url;
  }
}
