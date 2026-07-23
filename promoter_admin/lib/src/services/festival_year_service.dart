import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';

/// Roll a festival to a new event year: archive Current on the **testing**
/// pointer, create empty new-year CSVs, rewrite testing Current in place.
///
/// Production pointer is never modified here — use Promote after verifying
/// testing.
class FestivalYearService {
  FestivalYearService(this.dropboxApi);

  final DropboxApi dropboxApi;

  /// New-year naming (distinct from create-festival `artistLineup` names).
  static String artistFileName(String prefix, String year, {required bool testing}) {
    final p = FestivalCreateService.sanitizeFilePrefix(prefix);
    final y = year.trim();
    return testing
        ? '$p-artistFile-${y}_test.csv'
        : '$p-artistFile-$y.csv';
  }

  static String scheduleFileName(
    String prefix,
    String year, {
    required bool testing,
  }) {
    final p = FestivalCreateService.sanitizeFilePrefix(prefix);
    final y = year.trim();
    return testing
        ? '$p-scheduleFile-${y}_test.csv'
        : '$p-scheduleFile-$y.csv';
  }

  static String descriptionMapFileName(
    String prefix,
    String year, {
    required bool testing,
  }) {
    final p = FestivalCreateService.sanitizeFilePrefix(prefix);
    final y = year.trim();
    return testing
        ? '$p-descriptionMap-${y}_test.csv'
        : '$p-descriptionMap-$y.csv';
  }

  static String parentFolderOfPath(String apiPath) {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '');
    final slash = path.lastIndexOf('/');
    if (slash <= 0) return '/';
    return path.substring(0, slash);
  }

  static String defaultNewYear(String currentYear) {
    final y = currentYear.trim();
    if (RegExp(r'^\d+$').hasMatch(y)) {
      return (int.parse(y) + 1).toString();
    }
    return (DateTime.now().year + 1).toString();
  }

  /// Archive Current into [oldYear] and point Current at the new-year URLs.
  ///
  /// Pointer layout is Current + past year sections only — never a
  /// `{newYear}::` section (that year exists only as Current until archived).
  static String rewritePointerText({
    required String pointerText,
    required String oldYear,
    required String newYear,
    required String artistUrl,
    required String scheduleUrl,
    required String descriptionMapUrl,
  }) {
    final oldY = oldYear.trim();
    final newY = newYear.trim();
    if (oldY.isEmpty || newY.isEmpty) {
      throw ArgumentError('oldYear and newYear are required.');
    }
    if (oldY == newY) {
      throw ArgumentError('New year must differ from the current year.');
    }

    final parsed = _parseSections(pointerText);
    final sections = parsed.sections;
    final current = Map<String, String>.from(sections['Current'] ?? const {});
    if (current.isEmpty) {
      throw FormatException('Pointer file has no Current section.');
    }

    final archived = Map<String, String>.from(sections[oldY] ?? const {});
    archived.addAll(current);
    archived['eventYear'] = oldY;
    sections[oldY] = archived;

    final nextCurrent = Map<String, String>.from(current);
    nextCurrent['artistUrl'] = artistUrl;
    nextCurrent['scheduleUrl'] = scheduleUrl;
    nextCurrent['descriptionMap'] = descriptionMapUrl;
    nextCurrent['eventYear'] = newY;
    sections['Current'] = nextCurrent;

    final order = List<String>.from(parsed.order);
    if (!order.contains(oldY)) {
      final idx = order.indexOf('Current');
      final at = idx >= 0 ? idx + 1 : order.length;
      order.insert(at, oldY);
    }

    return _serializeSections(sections, order, parsed.keyOrders);
  }

  /// Files that will be created for a year roll (for confirm dialog).
  static List<String> plannedFilenames({
    required String prefix,
    required String newYear,
    bool shareArtistsWithProduction = false,
    bool shareMapWithProduction = false,
  }) {
    return [
      artistFileName(prefix, newYear, testing: false),
      if (!shareArtistsWithProduction)
        artistFileName(prefix, newYear, testing: true),
      scheduleFileName(prefix, newYear, testing: false),
      scheduleFileName(prefix, newYear, testing: true),
      descriptionMapFileName(prefix, newYear, testing: false),
      if (!shareMapWithProduction)
        descriptionMapFileName(prefix, newYear, testing: true),
    ];
  }

  /// Replace selected Current keys on a pointer file text (preserves other keys).
  static String patchCurrentUrls({
    required String pointerText,
    String? artistUrl,
    String? scheduleUrl,
    String? descriptionMapUrl,
  }) {
    final parsed = _parseSections(pointerText);
    final sections = parsed.sections;
    final current = Map<String, String>.from(sections['Current'] ?? const {});
    if (current.isEmpty) {
      throw FormatException('Pointer file has no Current section.');
    }
    if (artistUrl != null) current['artistUrl'] = artistUrl.trim();
    if (scheduleUrl != null) current['scheduleUrl'] = scheduleUrl.trim();
    if (descriptionMapUrl != null) {
      current['descriptionMap'] = descriptionMapUrl.trim();
    }
    sections['Current'] = current;
    return _serializeSections(sections, parsed.order, parsed.keyOrders);
  }

  /// Create empty CSVs and rewrite the **testing** pointer in place only.
  ///
  /// When [shareArtistsWithProduction] / [shareMapWithProduction] is true,
  /// Testing Current points at the new-year Production file for that channel
  /// (no separate `*_test` file). Schedule always gets a separate Testing file.
  ///
  /// Artist / schedule / description files are created in each channel's folder
  /// when split paths are known; otherwise [dropboxFolder] is used for all.
  Future<FestivalWorkspace> rollNewYear({
    required FestivalWorkspace workspace,
    required String newYear,
    required String dropboxFolder,
    String filePrefix = '',
    bool shareArtistsWithProduction = false,
    bool shareMapWithProduction = false,
  }) async {
    final testingPointerUrl = workspace.testingPointerUrl.trim();
    if (testingPointerUrl.isEmpty) {
      throw StateError('Testing pointer URL is required to add a new year.');
    }

    final testingText = await fetchUrlText(testingPointerUrl);
    final testingPointer = PointerFile.parse(testingText);
    final oldYear = testingPointer.eventYear.trim().isNotEmpty
        ? testingPointer.eventYear.trim()
        : workspace.eventYear.trim();
    if (oldYear.isEmpty) {
      throw StateError('Current event year is unknown; set it on the pointer first.');
    }

    final year = newYear.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(year)) {
      throw ArgumentError('New year must be a 4-digit year.');
    }
    if (year == oldYear) {
      throw ArgumentError('New year must differ from the current year ($oldYear).');
    }

    final prefix = filePrefix.trim().isEmpty
        ? FestivalCreateService.defaultFilePrefix(workspace.festivalName)
        : FestivalCreateService.sanitizeFilePrefix(filePrefix);
    final legacyRoot = FestivalCreateService.normalizeFolder(dropboxFolder);

    final artistRoot = workspace.artistFilesFolderPath.trim().isNotEmpty
        ? FestivalCreateService.normalizeFolder(workspace.artistFilesFolderPath)
        : legacyRoot;
    final scheduleRoot = workspace.scheduleFilesFolderPath.trim().isNotEmpty
        ? FestivalCreateService.normalizeFolder(workspace.scheduleFilesFolderPath)
        : legacyRoot;
    final descriptionRoot =
        workspace.descriptionFilesFolderPath.trim().isNotEmpty
        ? FestivalCreateService.normalizeFolder(
            workspace.descriptionFilesFolderPath,
          )
        : legacyRoot;

    await dropboxApi.ensureFolder(artistRoot);
    await dropboxApi.ensureFolder(scheduleRoot);
    await dropboxApi.ensureFolder(descriptionRoot);
    await dropboxApi.ensureFolder(
      '$descriptionRoot/${FestivalCreateService.descriptionsDir}',
    );

    final useCityState = workspace.useCityStateField;
    final lineupCsv = FestivalCreateService.lineupHeader(useCityState: useCityState);
    final scheduleCsv = FestivalCreateService.scheduleHeader();
    final mapCsv = FestivalCreateService.mapHeader;

    final prodArtists = '$artistRoot/${artistFileName(prefix, year, testing: false)}';
    final prodSchedule =
        '$scheduleRoot/${scheduleFileName(prefix, year, testing: false)}';
    final prodMap =
        '$descriptionRoot/${descriptionMapFileName(prefix, year, testing: false)}';
    final testArtists = '$artistRoot/${artistFileName(prefix, year, testing: true)}';
    final testSchedule =
        '$scheduleRoot/${scheduleFileName(prefix, year, testing: true)}';
    final testMap =
        '$descriptionRoot/${descriptionMapFileName(prefix, year, testing: true)}';

    await dropboxApi.ensureTextFile(prodArtists, lineupCsv);
    if (!shareArtistsWithProduction) {
      await dropboxApi.ensureTextFile(testArtists, lineupCsv);
    }
    await dropboxApi.ensureTextFile(prodSchedule, scheduleCsv);
    await dropboxApi.ensureTextFile(testSchedule, scheduleCsv);
    await dropboxApi.ensureTextFile(prodMap, mapCsv);
    if (!shareMapWithProduction) {
      await dropboxApi.ensureTextFile(testMap, mapCsv);
    }

    final prodBandUrl = await dropboxApi.shareUrlForPath(prodArtists);
    final prodScheduleUrl = await dropboxApi.shareUrlForPath(prodSchedule);
    final prodMapUrl = await dropboxApi.shareUrlForPath(prodMap);
    final testBandUrl = shareArtistsWithProduction
        ? prodBandUrl
        : await dropboxApi.shareUrlForPath(testArtists);
    final testScheduleUrl = await dropboxApi.shareUrlForPath(testSchedule);
    final testMapUrl = shareMapWithProduction
        ? prodMapUrl
        : await dropboxApi.shareUrlForPath(testMap);

    // Production placeholder files are created for later Promote, but the
    // production pointer is intentionally left untouched.
    assert(prodScheduleUrl.isNotEmpty);

    final rewrittenTesting = rewritePointerText(
      pointerText: testingText,
      oldYear: oldYear,
      newYear: year,
      artistUrl: testBandUrl,
      scheduleUrl: testScheduleUrl,
      descriptionMapUrl: testMapUrl,
    );
    await dropboxApi.uploadTextInPlace(testingPointerUrl, rewrittenTesting);

    return workspace.copyWith(
      eventYear: year,
      bandListUrl: testBandUrl,
      scheduleUrl: testScheduleUrl,
      descriptionMapUrl: testMapUrl,
      artistFilesFolderPath: artistRoot,
      scheduleFilesFolderPath: scheduleRoot,
      descriptionFilesFolderPath: descriptionRoot,
      canEditBands: true,
      canEditSchedule: true,
      canEditDescriptions: true,
      canEditPointers: true,
    );
  }

  /// Production Dropbox path → sibling testing path (`….csv` → `…_test.csv`).
  static String testingPathFromProductionPath(String apiPath) {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    final lower = path.toLowerCase();
    if (lower.endsWith('_test.csv')) return path;
    if (!lower.endsWith('.csv')) {
      throw ArgumentError('Expected a .csv path, got: $apiPath');
    }
    return '${path.substring(0, path.length - '.csv'.length)}_test.csv';
  }

  /// Point Testing Current artists and/or description map at Production's
  /// Current URLs (intentional live sharing). Schedule is never changed here.
  Future<FestivalWorkspace> shareTestingChannelsWithProduction({
    required FestivalWorkspace workspace,
    bool shareArtists = false,
    bool shareMap = false,
  }) async {
    if (!shareArtists && !shareMap) return workspace;
    final testingPointerUrl = workspace.testingPointerUrl.trim();
    final productionPointerUrl = workspace.productionPointerUrl.trim();
    if (testingPointerUrl.isEmpty || productionPointerUrl.isEmpty) {
      throw StateError('Testing and Production links are required.');
    }
    final productionText = await fetchUrlText(productionPointerUrl);
    final production = PointerFile.parse(productionText);
    if (shareArtists && production.artistUrl.isEmpty) {
      throw StateError('Production pointer has no Current::artistUrl.');
    }
    if (shareMap && production.descriptionMapUrl.isEmpty) {
      throw StateError('Production pointer has no Current::descriptionMap.');
    }

    final testingText = await fetchUrlText(testingPointerUrl);
    final rewritten = patchCurrentUrls(
      pointerText: testingText,
      artistUrl: shareArtists ? production.artistUrl : null,
      descriptionMapUrl: shareMap ? production.descriptionMapUrl : null,
    );
    await dropboxApi.uploadTextInPlace(testingPointerUrl, rewritten);

    return workspace.copyWith(
      bandListUrl: shareArtists ? production.artistUrl : workspace.bandListUrl,
      descriptionMapUrl:
          shareMap ? production.descriptionMapUrl : workspace.descriptionMapUrl,
    );
  }

  /// Point Testing Current artists and/or description map at a dedicated
  /// `*_test.csv` sibling (creates the file from Production content if missing).
  Future<FestivalWorkspace> unshareTestingChannelsFromProduction({
    required FestivalWorkspace workspace,
    bool unshareArtists = false,
    bool unshareMap = false,
  }) async {
    if (!unshareArtists && !unshareMap) return workspace;
    final testingPointerUrl = workspace.testingPointerUrl.trim();
    final productionPointerUrl = workspace.productionPointerUrl.trim();
    if (testingPointerUrl.isEmpty || productionPointerUrl.isEmpty) {
      throw StateError('Testing and Production links are required.');
    }
    final productionText = await fetchUrlText(productionPointerUrl);
    final production = PointerFile.parse(productionText);

    String? newArtistUrl;
    String? newMapUrl;

    if (unshareArtists) {
      final prodUrl = production.artistUrl.trim();
      if (prodUrl.isEmpty) {
        throw StateError('Production pointer has no Current::artistUrl.');
      }
      final prodPath = await dropboxApi.resolveApiPath(prodUrl);
      final testPath = testingPathFromProductionPath(prodPath);
      final body = await fetchUrlText(prodUrl);
      await dropboxApi.ensureTextFile(testPath, body);
      newArtistUrl = await dropboxApi.shareUrlForPath(testPath);
    }
    if (unshareMap) {
      final prodUrl = production.descriptionMapUrl.trim();
      if (prodUrl.isEmpty) {
        throw StateError('Production pointer has no Current::descriptionMap.');
      }
      final prodPath = await dropboxApi.resolveApiPath(prodUrl);
      final testPath = testingPathFromProductionPath(prodPath);
      final body = await fetchUrlText(prodUrl);
      await dropboxApi.ensureTextFile(testPath, body);
      newMapUrl = await dropboxApi.shareUrlForPath(testPath);
    }

    final testingText = await fetchUrlText(testingPointerUrl);
    final rewritten = patchCurrentUrls(
      pointerText: testingText,
      artistUrl: newArtistUrl,
      descriptionMapUrl: newMapUrl,
    );
    await dropboxApi.uploadTextInPlace(testingPointerUrl, rewritten);

    return workspace.copyWith(
      bandListUrl: newArtistUrl ?? workspace.bandListUrl,
      descriptionMapUrl: newMapUrl ?? workspace.descriptionMapUrl,
    );
  }

  Future<String?> inferFolderFromWorkspace(FestivalWorkspace workspace) async {
    final candidates = [
      workspace.bandListUrl,
      workspace.scheduleUrl,
      workspace.descriptionMapUrl,
      workspace.testingPointerUrl,
    ];
    for (final url in candidates) {
      final trimmed = url.trim();
      if (trimmed.isEmpty) continue;
      try {
        final path = await dropboxApi.resolveApiPath(trimmed);
        return parentFolderOfPath(path);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static ({
    Map<String, Map<String, String>> sections,
    List<String> order,
    Map<String, List<String>> keyOrders,
  }) _parseSections(String text) {
    final sections = <String, Map<String, String>>{};
    final order = <String>[];
    final keyOrders = <String, List<String>>{};
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('::');
      if (parts.length < 3) continue;
      final section = parts[0].trim();
      final key = parts[1].trim();
      final value = parts.sublist(2).join('::').trim();
      if (!sections.containsKey(section)) {
        sections[section] = <String, String>{};
        order.add(section);
        keyOrders[section] = <String>[];
      }
      sections[section]![key] = value;
      final keys = keyOrders[section]!;
      if (!keys.contains(key)) keys.add(key);
    }
    return (sections: sections, order: order, keyOrders: keyOrders);
  }

  static String _serializeSections(
    Map<String, Map<String, String>> sections,
    List<String> order,
    Map<String, List<String>> keyOrders,
  ) {
    final lines = <String>[];
    for (final section in order) {
      final map = sections[section];
      if (map == null || map.isEmpty) continue;
      final keys = <String>[];
      for (final k in keyOrders[section] ?? const <String>[]) {
        if (map.containsKey(k) && !keys.contains(k)) keys.add(k);
      }
      for (final k in map.keys) {
        if (!keys.contains(k)) keys.add(k);
      }
      // Prefer a stable Current / year key order when inserting new keys.
      _preferKeyOrder(keys, const [
        'artistUrl',
        'scheduleUrl',
        'eventYear',
        'descriptionMap',
        'reportUrl',
      ]);
      for (final key in keys) {
        lines.add('$section::$key::${map[key]}');
      }
      lines.add('');
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return '${lines.join('\n')}\n';
  }

  static void _preferKeyOrder(List<String> keys, List<String> preferred) {
    final preferredPresent =
        preferred.where(keys.contains).toList(growable: false);
    if (preferredPresent.isEmpty) return;
    keys.removeWhere(preferred.contains);
    keys.insertAll(0, preferredPresent);
  }
}
