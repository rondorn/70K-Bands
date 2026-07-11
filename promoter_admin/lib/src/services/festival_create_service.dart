import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';

/// Bootstrap a new festival folder on Dropbox (layout + pointers).
///
/// Creates header-only placeholders for artists / schedule / description map
/// in both testing (`*_test.csv`) and production variants, matching MDF-style
/// naming (`{prefix}_artistLineup_{year}.csv`, etc.).
class FestivalCreateService {
  FestivalCreateService(this.dropboxApi);

  final DropboxApi dropboxApi;

  static const descriptionsDir = 'descriptions';

  static const mapHeader = 'Band,URL,Date\n';

  static String lineupHeader({bool useCityState = false}) =>
      '${LineupService.fieldsFor(useCityState: useCityState).join(',')}\n';

  static String scheduleHeader() => '${ScheduleService.columns.join(',')}\n';

  /// Default Dropbox API folder for [festivalName]: `/{Name}_Public`.
  static String defaultFolderForName(String festivalName) {
    final base = sanitizeFolderSegment(festivalName);
    return '/${base}_Public';
  }

  /// Short file prefix (e.g. `mdf`, `rmf`) used in Dropbox filenames.
  static String defaultFilePrefix(String festivalName) {
    final words = festivalName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .toList();
    if (words.length >= 2) {
      final initials = words
          .map((w) => w.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
          .where((w) => w.isNotEmpty)
          .map((w) => w[0])
          .join()
          .toLowerCase();
      if (initials.length >= 2) return initials;
    }
    final slug = festivalName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return slug.isEmpty ? 'fest' : slug;
  }

  static String sanitizeFolderSegment(String raw) {
    var name = raw.trim().replaceAll(RegExp(r'[\\/]+'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    name = name.replaceAll(RegExp(r'[<>:"|?*]'), '');
    if (name.isEmpty) return 'Festival';
    return name;
  }

  static String sanitizeFilePrefix(String raw) {
    final slug = raw.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return slug.isEmpty ? 'fest' : slug;
  }

  static String normalizeFolder(String apiPath) {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path.isEmpty) {
      throw ArgumentError('Dropbox festival folder path is required.');
    }
    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '');
    return path.isEmpty ? '/' : path;
  }

  static String artistLineupName(String prefix, String year, {required bool testing}) {
    final p = sanitizeFilePrefix(prefix);
    final y = year.trim();
    return testing
        ? '${p}_artistLineup_${y}_test.csv'
        : '${p}_artistLineup_$y.csv';
  }

  static String scheduleName(String prefix, String year, {required bool testing}) {
    final p = sanitizeFilePrefix(prefix);
    final y = year.trim();
    return testing
        ? '${p}_artistsSchedule${y}_test.csv'
        : '${p}_artistsSchedule$y.csv';
  }

  static String descriptionMapName(
    String prefix,
    String year, {
    required bool testing,
  }) {
    final p = sanitizeFilePrefix(prefix);
    final y = year.trim();
    return testing
        ? '${p}_descriptionMap${y}_test.csv'
        : '${p}_descriptionMap$y.csv';
  }

  static String pointerName(String prefix, {required bool testing}) {
    final p = sanitizeFilePrefix(prefix);
    return testing
        ? '${p}_productionPointer_test.txt'
        : '${p}_productionPointer.txt';
  }

  static String buildPointerText({
    required String eventYear,
    required String bandListUrl,
    required String scheduleUrl,
    required String descriptionMapUrl,
  }) {
    final year = eventYear.trim().isEmpty ? '2027' : eventYear.trim();
    return [
      'Current::artistUrl::$bandListUrl',
      'Current::scheduleUrl::$scheduleUrl',
      'Current::eventYear::$year',
      'Current::descriptionMap::$descriptionMapUrl',
      '$year::scheduleUrl::$scheduleUrl',
      '',
    ].join('\n');
  }

  /// Create folders/files (only if missing) and return a filled workspace draft
  /// (without id — caller assigns when adding to the registry).
  Future<FestivalWorkspace> createFestival({
    required String festivalName,
    required String eventYear,
    required String dropboxFolder,
    String filePrefix = '',
  }) async {
    final name = festivalName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Festival name is required.');
    }
    final year = eventYear.trim().isEmpty ? '2027' : eventYear.trim();
    final prefix = filePrefix.trim().isEmpty
        ? defaultFilePrefix(name)
        : sanitizeFilePrefix(filePrefix);
    final root = normalizeFolder(dropboxFolder);

    await dropboxApi.ensureFolder(root);
    await dropboxApi.ensureFolder('$root/$descriptionsDir');

    // Production placeholders
    final prodArtists = '$root/${artistLineupName(prefix, year, testing: false)}';
    final prodSchedule = '$root/${scheduleName(prefix, year, testing: false)}';
    final prodMap = '$root/${descriptionMapName(prefix, year, testing: false)}';

    // Testing placeholders (what the admin edits)
    final testArtists = '$root/${artistLineupName(prefix, year, testing: true)}';
    final testSchedule = '$root/${scheduleName(prefix, year, testing: true)}';
    final testMap = '$root/${descriptionMapName(prefix, year, testing: true)}';

    final lineupCsv = lineupHeader();
    final scheduleCsv = scheduleHeader();
    final mapCsv = mapHeader;

    await dropboxApi.ensureTextFile(prodArtists, lineupCsv);
    await dropboxApi.ensureTextFile(testArtists, lineupCsv);
    await dropboxApi.ensureTextFile(prodSchedule, scheduleCsv);
    await dropboxApi.ensureTextFile(testSchedule, scheduleCsv);
    await dropboxApi.ensureTextFile(prodMap, mapCsv);
    await dropboxApi.ensureTextFile(testMap, mapCsv);

    final testBandUrl = await dropboxApi.shareUrlForPath(testArtists);
    final testScheduleUrl = await dropboxApi.shareUrlForPath(testSchedule);
    final testMapUrl = await dropboxApi.shareUrlForPath(testMap);

    final prodBandUrl = await dropboxApi.shareUrlForPath(prodArtists);
    final prodScheduleUrl = await dropboxApi.shareUrlForPath(prodSchedule);
    final prodMapUrl = await dropboxApi.shareUrlForPath(prodMap);

    final testingPointerBody = buildPointerText(
      eventYear: year,
      bandListUrl: testBandUrl,
      scheduleUrl: testScheduleUrl,
      descriptionMapUrl: testMapUrl,
    );
    final productionPointerBody = buildPointerText(
      eventYear: year,
      bandListUrl: prodBandUrl,
      scheduleUrl: prodScheduleUrl,
      descriptionMapUrl: prodMapUrl,
    );

    final testingPointerPath = '$root/${pointerName(prefix, testing: true)}';
    final productionPointerPath = '$root/${pointerName(prefix, testing: false)}';

    await dropboxApi.ensureTextFile(testingPointerPath, testingPointerBody);
    await dropboxApi.ensureTextFile(
      productionPointerPath,
      productionPointerBody,
    );

    final testingPointerUrl =
        await dropboxApi.shareUrlForPath(testingPointerPath);
    final productionPointerUrl =
        await dropboxApi.shareUrlForPath(productionPointerPath);

    return FestivalWorkspace(
      festivalName: name,
      eventYear: year,
      testingPointerUrl: testingPointerUrl,
      productionPointerUrl: productionPointerUrl,
      bandListUrl: testBandUrl,
      scheduleUrl: testScheduleUrl,
      descriptionMapUrl: testMapUrl,
      eventTypes: const ['Show', 'Special Event', 'Unofficial Event'],
      canEditBands: true,
      canEditSchedule: true,
      canEditDescriptions: true,
      canEditPointers: true,
    );
  }
}
