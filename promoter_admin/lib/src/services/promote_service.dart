import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_year_service.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_staging.dart';

/// Whether Testing and Production Current data files resolve to the same Dropbox file.
class DataFileShareStatus {
  const DataFileShareStatus({
    this.artistsShared = false,
    this.scheduleShared = false,
    this.mapShared = false,
  });

  final bool artistsShared;
  final bool scheduleShared;
  final bool mapShared;

  bool get anyShared => artistsShared || scheduleShared || mapShared;
}

class PromoteDiff {
  PromoteDiff({
    this.bandsTesting = 0,
    this.bandsProduction = 0,
    this.eventsTesting = 0,
    this.eventsProduction = 0,
    this.mapRowsTesting = 0,
    this.mapRowsProduction = 0,
    this.testingYear = '',
    this.productionYear = '',
    this.addedBandNames = const [],
    this.artistsShared = false,
    this.scheduleShared = false,
    this.mapShared = false,
    this.bandsContentDiffer = false,
    this.eventsContentDiffer = false,
    this.mapContentDiffer = false,
    List<String>? changeDetailLines,
    List<String>? messages,
  })  : changeDetailLines = changeDetailLines ?? <String>[],
        messages = messages ?? <String>[];

  int bandsTesting;
  int bandsProduction;
  int eventsTesting;
  int eventsProduction;
  int mapRowsTesting;
  int mapRowsProduction;
  String testingYear;
  String productionYear;
  List<String> addedBandNames;
  bool artistsShared;
  bool scheduleShared;
  bool mapShared;

  /// True when Testing artists CSV text differs from the Production target.
  bool bandsContentDiffer;

  /// True when Testing schedule CSV text differs from the Production target.
  bool eventsContentDiffer;

  /// True when Testing description map CSV text differs from the Production target.
  bool mapContentDiffer;

  /// Plain-language summary of adds/removes/edits (may be non-empty when row counts match).
  final List<String> changeDetailLines;

  final List<String> messages;

  bool get isYearRoll {
    final t = testingYear.trim();
    final p = productionYear.trim();
    return t.isNotEmpty && p.isNotEmpty && t != p;
  }

  /// True when Publish would change Production (year-roll or CSV content differs).
  bool get hasPublishableChanges {
    if (isYearRoll) return true;
    return bandsContentDiffer || eventsContentDiffer || mapContentDiffer;
  }

  List<String> get summaryLines {
    final lines = <String>[];
    if (isYearRoll) {
      lines.add(
        'Event year: testing $testingYear → production $productionYear '
        '(will archive production Current as $productionYear and point '
        'Current at $testingYear production files)',
      );
    } else if (testingYear.isNotEmpty || productionYear.isNotEmpty) {
      final y = testingYear.isNotEmpty ? testingYear : productionYear;
      lines.add('Event year: $y (same on testing and production)');
    }
    lines.addAll([
      'Bands: testing $bandsTesting → production $bandsProduction',
      'Schedule events: testing $eventsTesting → production $eventsProduction',
      'Description map rows: testing $mapRowsTesting → production $mapRowsProduction',
      ...messages,
    ]);
    return lines;
  }
}

class PromoteService {
  PromoteService({
    required this.pointerService,
    required this.dropboxApi,
  });

  final PointerService pointerService;
  final DropboxApi dropboxApi;

  /// Testing Dropbox path → sibling production path (`…_test.csv` → `….csv`).
  static String productionPathFromTestingPath(String apiPath) {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    if (!path.toLowerCase().endsWith('_test.csv')) {
      throw ArgumentError(
        'Expected a testing file path ending in _test.csv, got: $apiPath',
      );
    }
    return '${path.substring(0, path.length - '_test.csv'.length)}.csv';
  }

  /// True when [path] looks like a dedicated Testing CSV (`*_test.csv`).
  static bool isTestingCsvPath(String apiPath) {
    final path = apiPath.trim().replaceAll('\\', '/').toLowerCase();
    return path.endsWith('_test.csv');
  }

  /// Cheap URL equality (normalized). Prefer [sameDataFile] when Dropbox is available.
  static bool sameShareUrl(String a, String b) {
    final left = normalizeDropboxUrl(a).trim().toLowerCase();
    final right = normalizeDropboxUrl(b).trim().toLowerCase();
    if (left.isEmpty || right.isEmpty) return false;
    return left == right;
  }

  /// Compare Testing vs Production Current data-file URLs (path-aware when possible).
  Future<DataFileShareStatus> inspectDataFileSharing(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final testingUrl = workspace.testingPointerUrl.trim();
    final productionUrl = workspace.productionPointerUrl.trim();
    if (testingUrl.isEmpty || productionUrl.isEmpty) {
      return const DataFileShareStatus();
    }
    final pointerPair = await Future.wait([
      _currentUrls(testingUrl, forceRefresh: forceRefresh),
      _currentUrls(productionUrl, forceRefresh: forceRefresh),
    ]);
    final testUrls = pointerPair[0];
    final prodUrls = pointerPair[1];
    final artists = await sameDataFile(
      testUrls['band_list_url'] ?? '',
      prodUrls['band_list_url'] ?? '',
    );
    final schedule = await sameDataFile(
      testUrls['schedule_url'] ?? '',
      prodUrls['schedule_url'] ?? '',
    );
    final map = await sameDataFile(
      testUrls['description_map_url'] ?? '',
      prodUrls['description_map_url'] ?? '',
    );
    return DataFileShareStatus(
      artistsShared: artists,
      scheduleShared: schedule,
      mapShared: map,
    );
  }

  /// True when two share links resolve to the same Dropbox path (or equal URLs).
  Future<bool> sameDataFile(String urlA, String urlB) async {
    if (sameShareUrl(urlA, urlB)) return true;
    final a = normalizeDropboxUrl(urlA).trim();
    final b = normalizeDropboxUrl(urlB).trim();
    if (a.isEmpty || b.isEmpty) return false;
    try {
      final paths = await Future.wait([
        dropboxApi.resolveApiPath(a),
        dropboxApi.resolveApiPath(b),
      ]);
      return paths[0].toLowerCase() == paths[1].toLowerCase();
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _currentUrls(String pointerUrl, {bool forceRefresh = false}) async {
    final pointer = await pointerService.fetchPointer(pointerUrl, forceRefresh: forceRefresh);
    final current = pointer.current;
    if (current.isEmpty) {
      throw StateError('Pointer has no Current section: $pointerUrl');
    }
    return {
      'band_list_url': (current['artistUrl'] ?? '').trim(),
      'schedule_url': (current['scheduleUrl'] ?? '').trim(),
      'description_map_url': (current['descriptionMap'] ?? '').trim(),
      'event_year': (current['eventYear'] ?? '').trim(),
    };
  }

  Future<String> _productionShareUrlForTestingUrl(String testingShareUrl) async {
    final testPath = await dropboxApi.resolveApiPath(testingShareUrl);
    final prodPath = productionPathFromTestingPath(testPath);
    return dropboxApi.shareUrlForPath(prodPath);
  }

  /// Destination production URLs for each data file.
  ///
  /// Same-year promote uses Current on the production pointer.
  /// Year-roll promote uses the non-`_test` siblings of the testing Current files
  /// (never the production pointer's existing Current URLs — those stay archived).
  Future<Map<String, String>> _destinationUrls({
    required Map<String, String> testUrls,
    required Map<String, String> prodUrls,
    required bool yearRoll,
  }) async {
    if (!yearRoll) {
      return {
        'band_list_url': prodUrls['band_list_url'] ?? '',
        'schedule_url': prodUrls['schedule_url'] ?? '',
        'description_map_url': prodUrls['description_map_url'] ?? '',
      };
    }

    Future<String> resolve(String key) async {
      final src = (testUrls[key] ?? '').trim();
      if (src.isEmpty) return '';
      // Intentional shared artists/map: Testing already points at a production
      // (non-_test) file — that file is the year-roll destination.
      try {
        final path = await dropboxApi.resolveApiPath(src);
        if (!isTestingCsvPath(path)) {
          return src;
        }
      } catch (_) {
        if (!src.toLowerCase().contains('_test.csv')) {
          return src;
        }
      }
      return _productionShareUrlForTestingUrl(src);
    }

    final resolved = await Future.wait([
      resolve('band_list_url'),
      resolve('schedule_url'),
      resolve('description_map_url'),
    ]);
    final dest = {
      'band_list_url': resolved[0],
      'schedule_url': resolved[1],
      'description_map_url': resolved[2],
    };

    // Refuse to target the old Current production files.
    for (final key in dest.keys) {
      final newUrl = (dest[key] ?? '').trim();
      final oldUrl = (prodUrls[key] ?? '').trim();
      if (newUrl.isEmpty || oldUrl.isEmpty) continue;
      final newPath = await dropboxApi.resolveApiPath(newUrl);
      final oldPath = await dropboxApi.resolveApiPath(oldUrl);
      if (newPath.toLowerCase() == oldPath.toLowerCase()) {
        throw StateError(
          'Year-roll destination for $key resolved to the existing production '
          'Current file ($oldPath). New-year production files must be separate '
          'so $key for the prior year is left unchanged.',
        );
      }
    }

    return dest;
  }

  static int countCsvRows(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return 0;
    return lines.length - 1;
  }

  /// Band names present in [testingCsv] but not in [productionCsv] (case-insensitive).
  static List<String> addedBandsFromCsv({
    required String testingCsv,
    required String productionCsv,
  }) {
    final testing = PointerService.parseLineupCsv(testingCsv);
    final production = PointerService.parseLineupCsv(productionCsv);
    final prodKeys = {
      for (final b in production) b.name.toLowerCase(),
    };
    final added = <String>[];
    for (final b in testing) {
      if (!prodKeys.contains(b.name.toLowerCase())) {
        added.add(b.name);
      }
    }
    added.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return added;
  }

  static String _bandFingerprint(BandRow band) {
    final keys = band.fields.keys.toList()..sort();
    return keys.map((k) => '$k=${(band.fields[k] ?? '').trim()}').join('\u001f');
  }

  static List<String> bandChangeDetailLines({
    required String testingCsv,
    required String productionCsv,
    int maxNames = 8,
  }) {
    final testing = PointerService.parseLineupCsvPreservingOrder(testingCsv);
    final production = PointerService.parseLineupCsvPreservingOrder(productionCsv);
    final prodByName = {
      for (final b in production) b.name.toLowerCase(): b,
    };
    final testByName = {
      for (final b in testing) b.name.toLowerCase(): b,
    };

    final added = <String>[];
    final removed = <String>[];
    final updated = <String>[];
    for (final b in testing) {
      final key = b.name.toLowerCase();
      final prod = prodByName[key];
      if (prod == null) {
        added.add(b.name);
      } else if (_bandFingerprint(b) != _bandFingerprint(prod)) {
        updated.add(b.name);
      }
    }
    for (final b in production) {
      if (!testByName.containsKey(b.name.toLowerCase())) {
        removed.add(b.name);
      }
    }

    added.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    removed.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    updated.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return _formatChangeGroups(
      label: 'Artists',
      added: added,
      removed: removed,
      updated: updated,
      maxNames: maxNames,
    );
  }

  static String _scheduleEventLabel(ScheduleEvent event) {
    final parts = <String>[event.band.trim()];
    if (event.day.trim().isNotEmpty) {
      parts.add(event.day.trim());
    } else if (event.date.trim().isNotEmpty) {
      parts.add(event.date.trim());
    }
    if (event.startTime.trim().isNotEmpty) {
      parts.add(event.startTime.trim());
    }
    if (event.location.trim().isNotEmpty) {
      parts.add('@ ${event.location.trim()}');
    }
    return parts.join(' · ');
  }

  static List<String> scheduleChangeDetailLines({
    required String testingCsv,
    required String productionCsv,
    int maxNames = 10,
  }) {
    final testing = ScheduleService.parseEvents(testingCsv);
    final production = ScheduleService.parseEvents(productionCsv);

    String keyOf(ScheduleEvent e) => ScheduleStagingCoordinator.eventKey(
          band: e.band,
          location: e.location,
          date: e.date,
          startTime: e.startTime,
        );

    String fingerprint(ScheduleEvent e) =>
        ScheduleStagingCoordinator.eventFingerprintFromCsvRow(e.asRow());

    final prodByKey = {for (final e in production) keyOf(e): e};
    final testByKey = {for (final e in testing) keyOf(e): e};

    final added = <String>[];
    final removed = <String>[];
    final updated = <String>[];
    for (final e in testing) {
      final key = keyOf(e);
      final prod = prodByKey[key];
      if (prod == null) {
        added.add(_scheduleEventLabel(e));
      } else if (fingerprint(e) != fingerprint(prod)) {
        updated.add(_scheduleEventLabel(e));
      }
    }
    for (final e in production) {
      if (!testByKey.containsKey(keyOf(e))) {
        removed.add(_scheduleEventLabel(e));
      }
    }

    added.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    removed.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    updated.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return _formatChangeGroups(
      label: 'Schedule',
      added: added,
      removed: removed,
      updated: updated,
      maxNames: maxNames,
    );
  }

  static List<String> mapChangeDetailLines({
    required String testingCsv,
    required String productionCsv,
    int maxNames = 8,
  }) {
    final testingRows = parseCsvMaps(testingCsv);
    final productionRows = parseCsvMaps(productionCsv);

    String bandOf(Map<String, String> row) => (row['Band'] ?? '').trim();
    String fingerprint(Map<String, String> row) => [
          bandOf(row).toLowerCase(),
          (row['URL'] ?? '').trim(),
          (row['Date'] ?? '').trim(),
        ].join('\u001f');

    final prodByBand = <String, Map<String, String>>{};
    for (final row in productionRows) {
      final band = bandOf(row);
      if (band.isEmpty || band.toLowerCase() == 'band') continue;
      prodByBand[band.toLowerCase()] = row;
    }
    final testByBand = <String, Map<String, String>>{};
    for (final row in testingRows) {
      final band = bandOf(row);
      if (band.isEmpty || band.toLowerCase() == 'band') continue;
      testByBand[band.toLowerCase()] = row;
    }

    final added = <String>[];
    final removed = <String>[];
    final updated = <String>[];
    for (final entry in testByBand.entries) {
      final band = bandOf(entry.value);
      final prod = prodByBand[entry.key];
      if (prod == null) {
        added.add(band);
      } else if (fingerprint(entry.value) != fingerprint(prod)) {
        updated.add(band);
      }
    }
    for (final entry in prodByBand.entries) {
      if (!testByBand.containsKey(entry.key)) {
        removed.add(bandOf(entry.value));
      }
    }

    added.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    removed.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    updated.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return _formatChangeGroups(
      label: 'Descriptions',
      added: added,
      removed: removed,
      updated: updated,
      maxNames: maxNames,
    );
  }

  static List<String> _formatChangeGroups({
    required String label,
    required List<String> added,
    required List<String> removed,
    required List<String> updated,
    required int maxNames,
  }) {
    final lines = <String>[];
    void addGroup(String verb, List<String> names) {
      if (names.isEmpty) return;
      final shown = names.take(maxNames).toList();
      final tail = names.length - shown.length;
      final suffix = tail > 0 ? ' (and $tail more)' : '';
      lines.add(
        '$label — ${names.length} $verb: ${shown.join('; ')}$suffix',
      );
    }

    addGroup('added in Testing', added);
    addGroup('removed from Testing', removed);
    addGroup('edited in Testing', updated);
    return lines;
  }

  static String bandAnnouncementText({
    required String festivalName,
    required List<String> bands,
  }) {
    final label =
        festivalName.trim().isEmpty ? 'the festival' : festivalName.trim();
    final buffer = StringBuffer(
      'The following bands have just been added to $label!\n',
    );
    for (final name in bands) {
      buffer.writeln(name);
    }
    return buffer.toString();
  }

  /// `bandAnnouncements-YYYY-MM-DD-HH-MM-SS.pending`
  static String bandAnnouncementPendingFileName(DateTime when) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'bandAnnouncements-${when.year}-'
        '${two(when.month)}-${two(when.day)}-'
        '${two(when.hour)}-${two(when.minute)}-${two(when.second)}.pending';
  }

  /// `customAlert-YYYY-MM-DD-HH-MM-SS.pending`
  static String customAlertPendingFileName(DateTime when) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'customAlert-${when.year}-'
        '${two(when.month)}-${two(when.day)}-'
        '${two(when.hour)}-${two(when.minute)}-${two(when.second)}.pending';
  }

  Future<PromoteDiff> preview(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
    bool includeChangeDetails = true,
    String? scheduleTestingCsvOverride,
    String? artistsTestingCsvOverride,
    String? descriptionMapTestingCsvOverride,
  }) async {
    final testingUrl = workspace.testingPointerUrl.trim();
    final productionUrl = workspace.productionPointerUrl.trim();
    if (testingUrl.isEmpty) {
      throw StateError('Testing pointer URL is not configured.');
    }
    if (productionUrl.isEmpty) {
      throw StateError('Production pointer URL is not configured.');
    }

    final pointerPair = await Future.wait([
      _currentUrls(testingUrl, forceRefresh: forceRefresh),
      _currentUrls(productionUrl, forceRefresh: forceRefresh),
    ]);
    final testUrls = pointerPair[0];
    final prodUrls = pointerPair[1];
    final testingYear = testUrls['event_year'] ?? '';
    final productionYear = prodUrls['event_year'] ?? '';
    final yearRoll = testingYear.isNotEmpty &&
        productionYear.isNotEmpty &&
        testingYear != productionYear;

    final destUrls = await _destinationUrls(
      testUrls: testUrls,
      prodUrls: prodUrls,
      yearRoll: yearRoll,
    );

    final diff = PromoteDiff(
      testingYear: testingYear,
      productionYear: productionYear,
    );

    if (yearRoll) {
      diff.messages.add(
        'Production pointer will be rewritten: archive Current as '
        '$productionYear, set Current to $testingYear.',
      );
      diff.messages.add(
        'Data is written only to $testingYear production files; '
        '$productionYear production files are left unchanged.',
      );
    }

    Future<void> noteShare(String key, String label) async {
      final tUrl = (testUrls[key] ?? '').trim();
      final pUrl = (destUrls[key] ?? '').trim();
      if (tUrl.isEmpty || pUrl.isEmpty) return;
      if (!await sameDataFile(tUrl, pUrl)) return;
      if (key == 'schedule_url') {
        diff.scheduleShared = true;
        throw StateError(
          'Schedule Testing and Production resolve to the same file. '
          'Schedule must use a separate Testing file — fix the Testing pointer '
          'before publishing.',
        );
      }
      if (key == 'band_list_url') diff.artistsShared = true;
      if (key == 'description_map_url') diff.mapShared = true;
      diff.messages.add(
        '$label: Testing and Production share the same file '
        '(edits are live; Publish will skip copy).',
      );
    }

    await Future.wait([
      noteShare('band_list_url', 'Artists'),
      noteShare('schedule_url', 'Schedule'),
      noteShare('description_map_url', 'Description map'),
    ]);

    Future<({String? testing, String? production, String? error})> loadPair(
      String key,
      String label, {
      String? testingOverride,
    }) async {
      final tUrl = testUrls[key] ?? '';
      final pUrl = destUrls[key] ?? '';
      if (tUrl.isEmpty || pUrl.isEmpty) {
        return (
          testing: null,
          production: null,
          error: 'Missing URL for $label on testing or production target.',
        );
      }
      try {
        final texts = await Future.wait([
          testingOverride != null
              ? Future<String>.value(testingOverride)
              : fetchUrlText(tUrl, forceRefresh: forceRefresh),
          fetchUrlText(pUrl, forceRefresh: forceRefresh),
        ]);
        return (testing: texts[0], production: texts[1], error: null);
      } catch (e) {
        return (
          testing: null,
          production: null,
          error: 'Could not fetch $label: $e',
        );
      }
    }

    final loaded = await Future.wait([
      loadPair(
        'band_list_url',
        'artists',
        testingOverride: artistsTestingCsvOverride,
      ),
      loadPair(
        'schedule_url',
        'schedule',
        testingOverride: scheduleTestingCsvOverride,
      ),
      loadPair(
        'description_map_url',
        'description map',
        testingOverride: descriptionMapTestingCsvOverride,
      ),
    ]);

    final bands = loaded[0];
    if (bands.error != null) {
      diff.messages.add(bands.error!);
    } else {
      diff.bandsTesting = countCsvRows(bands.testing!);
      diff.bandsProduction = countCsvRows(bands.production!);
      diff.bandsContentDiffer = !diff.artistsShared &&
          !_sameCsvText(bands.testing!, bands.production!);
      if (includeChangeDetails) {
        diff.addedBandNames = addedBandsFromCsv(
          testingCsv: bands.testing!,
          productionCsv: bands.production!,
        );
        if (diff.bandsContentDiffer && !diff.artistsShared) {
          diff.changeDetailLines.addAll(
            bandChangeDetailLines(
              testingCsv: bands.testing!,
              productionCsv: bands.production!,
            ),
          );
        }
        if (diff.addedBandNames.isNotEmpty) {
          diff.messages.add(
            '${diff.addedBandNames.length} new band(s) vs production target '
            '(will be announced if alert folder is configured).',
          );
        }
      }
    }

    final schedule = loaded[1];
    if (schedule.error != null) {
      diff.messages.add(schedule.error!);
    } else {
      diff.eventsTesting = countCsvRows(schedule.testing!);
      diff.eventsProduction = countCsvRows(schedule.production!);
      diff.eventsContentDiffer = !diff.scheduleShared &&
          !_sameCsvText(schedule.testing!, schedule.production!);
      if (includeChangeDetails &&
          diff.eventsContentDiffer &&
          !diff.scheduleShared) {
        diff.changeDetailLines.addAll(
          scheduleChangeDetailLines(
            testingCsv: schedule.testing!,
            productionCsv: schedule.production!,
          ),
        );
      }
    }

    final map = loaded[2];
    if (map.error != null) {
      diff.messages.add(map.error!);
    } else {
      diff.mapRowsTesting = countCsvRows(map.testing!);
      diff.mapRowsProduction = countCsvRows(map.production!);
      diff.mapContentDiffer = !diff.mapShared &&
          !_sameCsvText(map.testing!, map.production!);
      if (includeChangeDetails && diff.mapContentDiffer && !diff.mapShared) {
        diff.changeDetailLines.addAll(
          mapChangeDetailLines(
            testingCsv: map.testing!,
            productionCsv: map.production!,
          ),
        );
      }
    }

    if (!diff.hasPublishableChanges && !diff.scheduleShared) {
      diff.messages.add(
        'Testing and Production data files match — nothing to publish.',
      );
    }

    return diff;
  }

  /// Header badge / background check: row counts and differ flags only.
  Future<PromoteDiff> previewQuick(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
    String? scheduleTestingCsvOverride,
    String? artistsTestingCsvOverride,
    String? descriptionMapTestingCsvOverride,
  }) {
    return preview(
      workspace,
      forceRefresh: forceRefresh,
      includeChangeDetails: false,
      scheduleTestingCsvOverride: scheduleTestingCsvOverride,
      artistsTestingCsvOverride: artistsTestingCsvOverride,
      descriptionMapTestingCsvOverride: descriptionMapTestingCsvOverride,
    );
  }

  /// Normalize line endings / trailing whitespace for CSV content equality.
  static bool _sameCsvText(String a, String b) {
    String norm(String raw) =>
        raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trimRight();
    return norm(a) == norm(b);
  }

  /// Copy testing CSV contents onto production files in place.
  ///
  /// When testing and production event years differ:
  /// - Writes only to new-year production siblings of the testing files
  /// - Leaves the prior-year production Current files unchanged
  /// - Rewrites the production pointer (archive Current → old year, point
  ///   Current at the new-year production files)
  ///
  /// Same-year promote leaves the pointer alone and writes to Current URLs.
  ///
  /// Only promotes files the workspace can edit (bands / schedule / map).
  Future<PromoteDiff> promote(FestivalWorkspace workspace) async {
    final testingUrl = workspace.testingPointerUrl.trim();
    final productionUrl = workspace.productionPointerUrl.trim();
    if (testingUrl.isEmpty) {
      throw StateError('Testing pointer URL is not configured.');
    }
    if (productionUrl.isEmpty) {
      throw StateError('Production pointer URL is not configured.');
    }
    if (testingUrl == productionUrl) {
      throw StateError(
        'Testing and production pointers must be different URLs.',
      );
    }

    final pointerPair = await Future.wait([
      _currentUrls(testingUrl),
      _currentUrls(productionUrl),
    ]);
    final testUrls = pointerPair[0];
    final prodUrls = pointerPair[1];
    final testingYear = (testUrls['event_year'] ?? '').trim();
    final productionYear = (prodUrls['event_year'] ?? '').trim();
    final yearRoll = testingYear.isNotEmpty &&
        productionYear.isNotEmpty &&
        testingYear != productionYear;

    // Resolve destinations before preview so year-roll path guards run first.
    final destUrls = await _destinationUrls(
      testUrls: testUrls,
      prodUrls: prodUrls,
      yearRoll: yearRoll,
    );

    // Reuses URL text cache filled by the Publish preview (reads stay local).
    final diff = await preview(workspace);

    final jobs = <({String key, String label, bool enabled})>[
      (
        key: 'band_list_url',
        label: 'lineup',
        enabled: workspace.canEditBands,
      ),
      (
        key: 'schedule_url',
        label: 'schedule',
        enabled: workspace.canEditSchedule,
      ),
      (
        key: 'description_map_url',
        label: 'description map',
        enabled: workspace.canEditDescriptions,
      ),
    ];

    var anyEnabled = false;
    var lineupPromoted = false;
    String? testingLineupText;
    String? productionLineupBeforeText;

    for (final job in jobs) {
      if (!job.enabled) {
        diff.messages.add('${job.label}: skipped (no write access).');
        continue;
      }
      anyEnabled = true;
      final src = testUrls[job.key] ?? '';
      final dest = destUrls[job.key] ?? '';
      final archivedProd = (prodUrls[job.key] ?? '').trim();
      if (src.isEmpty || dest.isEmpty) {
        throw StateError('Cannot promote ${job.label}: missing URL on pointer.');
      }
      if (await sameDataFile(src, dest)) {
        if (job.key == 'schedule_url') {
          throw StateError(
            'Schedule Testing and Production resolve to the same file. '
            'Schedule must use a separate Testing file — refusing to publish.',
          );
        }
        diff.messages.add(
          '${job.label}: testing and production share the same file — skipped copy.',
        );
        continue;
      }
      if (yearRoll && archivedProd.isNotEmpty) {
        final destPath = await dropboxApi.resolveApiPath(dest);
        final archivedPath = await dropboxApi.resolveApiPath(archivedProd);
        if (destPath.toLowerCase() == archivedPath.toLowerCase()) {
          throw StateError(
            'Refusing to overwrite $productionYear production ${job.label} '
            '($archivedPath). Year-roll data must go to a separate $testingYear file.',
          );
        }
      }
      try {
        final text = await fetchUrlText(src);
        String productionBefore = '';
        if (job.key == 'band_list_url') {
          try {
            productionBefore = await fetchUrlText(dest);
          } catch (_) {
            productionBefore = '';
          }
          testingLineupText = text;
          productionLineupBeforeText = productionBefore;
        }
        await dropboxApi.uploadTextInPlace(dest, text);
        if (job.key == 'band_list_url') {
          lineupPromoted = true;
        }
        diff.messages.add(
          yearRoll
              ? 'Wrote testing ${job.label} → $testingYear production file '
                  '(left $productionYear file unchanged).'
              : 'Updated production ${job.label} in place.',
        );
      } catch (e) {
        throw StateError('Failed promoting ${job.label}: $e');
      }
    }

    if (!anyEnabled) {
      throw StateError(
        'No writable data files to promote. Check File access in Settings.',
      );
    }

    if (lineupPromoted &&
        testingLineupText != null &&
        productionLineupBeforeText != null) {
      final added = addedBandsFromCsv(
        testingCsv: testingLineupText,
        productionCsv: productionLineupBeforeText,
      );
      diff.addedBandNames = added;
      if (added.isNotEmpty) {
        await _enqueueBandAnnouncement(workspace, diff, added);
      }
    }

    if (yearRoll) {
      final artistUrl = destUrls['band_list_url'] ?? '';
      final scheduleUrl = destUrls['schedule_url'] ?? '';
      final mapUrl = destUrls['description_map_url'] ?? '';
      if (artistUrl.isEmpty || scheduleUrl.isEmpty || mapUrl.isEmpty) {
        throw StateError(
          'Cannot rewrite production pointer: missing new-year production URLs.',
        );
      }
      final productionText = await fetchUrlText(productionUrl);
      final rewritten = FestivalYearService.rewritePointerText(
        pointerText: productionText,
        oldYear: productionYear,
        newYear: testingYear,
        artistUrl: artistUrl,
        scheduleUrl: scheduleUrl,
        descriptionMapUrl: mapUrl,
      );
      await dropboxApi.uploadTextInPlace(productionUrl, rewritten);
      diff.messages.add(
        'Updated production pointer: archived $productionYear (files unchanged), '
        'Current is now $testingYear.',
      );
    }

    return diff;
  }

  Future<void> _enqueueBandAnnouncement(
    FestivalWorkspace workspace,
    PromoteDiff diff,
    List<String> addedBands,
  ) async {
    final folderUrl = workspace.alertFolderUrl.trim();
    if (folderUrl.isEmpty) {
      diff.messages.add(
        'Band announcement skipped: no alert folder URL in Settings '
        '(${addedBands.length} new band(s)).',
      );
      return;
    }
    if (!workspace.canEditAlerts) {
      diff.messages.add(
        'Band announcement skipped: no write access to alert folder '
        '(${addedBands.length} new band(s)). Fix access in Settings.',
      );
      return;
    }

    final body = bandAnnouncementText(
      festivalName: workspace.festivalName,
      bands: addedBands,
    );
    final fileName = bandAnnouncementPendingFileName(DateTime.now());
    try {
      await dropboxApi.uploadTextInFolder(
        folderShareUrl: folderUrl,
        fileName: fileName,
        text: body,
      );
      diff.messages.add(
        'Queued band announcement ($fileName) for ${addedBands.length} new band(s).',
      );
    } catch (e) {
      diff.messages.add(
        'Failed to queue band announcement for ${addedBands.length} new band(s): $e',
      );
    }
  }

  /// Resolve Current URLs from a pointer (exposed for tests / diagnostics).
  Future<PointerFile> fetchPointer(String url) => pointerService.fetchPointer(url);
}
