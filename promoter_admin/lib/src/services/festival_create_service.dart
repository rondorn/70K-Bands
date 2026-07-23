import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_folder_path_cache.dart';
import 'package:promoter_admin/src/services/festival_year_service.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_validation.dart';

/// Bootstrap a new festival folder on Dropbox (layout + pointers).
///
/// Creates header-only placeholders for artists / schedule / description map
/// in both testing (`*_test.csv`) and production variants, matching MDF-style
/// naming (`{prefix}_artistLineup_{year}.csv`, etc.).
///
/// New festivals use five root-level Dropbox folders for access control:
/// `/{Name}_MasterFiles`, `/{Name}_Artist_Files`, `/{Name}_Schedule_Files`,
/// `/{Name}_Description_Files`, and `/{Name}_Alert_Files`.
class FestivalCreateService {
  FestivalCreateService(this.dropboxApi);

  final DropboxApi dropboxApi;

  static const descriptionsDir = 'descriptions';

  static const mapHeader = 'Band,URL,Date\n';

  static String lineupHeader({bool useCityState = false}) =>
      '${LineupService.fieldsFor(useCityState: useCityState).join(',')}\n';

  static String scheduleHeader() => '${ScheduleService.columns.join(',')}\n';

  /// Legacy single-folder default (existing festivals / year-roll fallback).
  static String defaultFolderForName(String festivalName) {
    final base = sanitizeFolderSegment(festivalName);
    return '/${base}_Public';
  }

  static String _eventSegment(String festivalName) =>
      sanitizeFolderSegment(festivalName);

  /// Root-level master access folder: `/{Name}_MasterFiles` (pointer files).
  static String masterFilesFolderForName(String festivalName) {
    return '/${_eventSegment(festivalName)}_MasterFiles';
  }

  /// Root-level artist access folder: `/{Name}_Artist_Files`.
  static String artistFilesFolderForName(String festivalName) {
    return '/${_eventSegment(festivalName)}_Artist_Files';
  }

  /// Root-level schedule access folder: `/{Name}_Schedule_Files`.
  static String scheduleFilesFolderForName(String festivalName) {
    return '/${_eventSegment(festivalName)}_Schedule_Files';
  }

  /// Root-level description access folder: `/{Name}_Description_Files`.
  static String descriptionFilesFolderForName(String festivalName) {
    return '/${_eventSegment(festivalName)}_Description_Files';
  }

  /// Root-level alert queue folder: `/{Name}_Alert_Files`.
  static String alertFilesFolderForName(String festivalName) {
    return '/${_eventSegment(festivalName)}_Alert_Files';
  }

  /// Local Dropbox sync path hint for [alertFilesFolderForName] (backend cron).
  static String localAlertSyncPathHint(String festivalName) {
    final folder = alertFilesFolderForName(festivalName);
    return '~/Library/CloudStorage/Dropbox$folder';
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

  /// Refresh cached folder paths from share URLs (background / launch validation).
  static Future<({FestivalWorkspace workspace, bool cacheChanged})>
      refreshFolderPathCache(
    FestivalWorkspace workspace,
    DropboxApi dropboxApi,
  ) {
    return FestivalFolderPathCache.refreshFromUrls(workspace, dropboxApi);
  }

  /// Infer split folder paths from share URLs (delegates to [FestivalFolderPathCache]).
  static Future<FestivalWorkspace> inferSplitFoldersFromUrls(
    FestivalWorkspace workspace,
    DropboxApi dropboxApi,
  ) async {
    final result = await FestivalFolderPathCache.refreshFromUrls(
      workspace,
      dropboxApi,
    );
    return result.workspace;
  }

  /// Infer folder paths, write-access flags, and folder ownership on startup /
  /// refresh (ownership is not persisted — must be re-probed each launch).
  static Future<FestivalWorkspace> probeFullWorkspaceAccess(
    FestivalWorkspace workspace,
    DropboxApi dropboxApi,
  ) async {
    final hasUrls =
        workspace.bandListUrl.trim().isNotEmpty ||
        workspace.scheduleUrl.trim().isNotEmpty ||
        workspace.descriptionMapUrl.trim().isNotEmpty ||
        workspace.testingPointerUrl.trim().isNotEmpty ||
        workspace.productionPointerUrl.trim().isNotEmpty ||
        workspace.alertFolderUrl.trim().isNotEmpty;
    if (!hasUrls) return workspace;

    var updated = await inferSplitFoldersFromUrls(workspace, dropboxApi);
    updated = await dropboxApi.probeWorkspaceWriteAccess(updated);
    updated = await dropboxApi.probeWorkspaceFolderOwnership(updated);
    return updated;
  }

  /// Create (if missing) `/{Name}_Alert_Files` and return its Dropbox path + share URL.
  Future<({String path, String shareUrl})> bootstrapAlertFolder(
    String festivalName,
  ) async {
    final name = festivalName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Festival name is required.');
    }
    final root = normalizeFolder(alertFilesFolderForName(name));
    await dropboxApi.ensureFolder(root);
    final shareUrl = await dropboxApi.shareUrlForPath(root);
    return (path: root, shareUrl: shareUrl);
  }

  /// Create folders/files (only if missing) and return a filled workspace draft
  /// (without id — caller assigns when adding to the registry).
  Future<FestivalWorkspace> createFestival({
    required String festivalName,
    required String eventYear,
    String filePrefix = '',
    String? artistFilesFolder,
    String? scheduleFilesFolder,
    String? descriptionFilesFolder,
  }) async {
    final name = festivalName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Festival name is required.');
    }
    final year = eventYear.trim().isEmpty ? '2027' : eventYear.trim();
    final prefix = filePrefix.trim().isEmpty
        ? defaultFilePrefix(name)
        : sanitizeFilePrefix(filePrefix);

    final artistRoot = normalizeFolder(
      artistFilesFolder ?? artistFilesFolderForName(name),
    );
    final scheduleRoot = normalizeFolder(
      scheduleFilesFolder ?? scheduleFilesFolderForName(name),
    );
    final descriptionRoot = normalizeFolder(
      descriptionFilesFolder ?? descriptionFilesFolderForName(name),
    );
    final masterRoot = normalizeFolder(masterFilesFolderForName(name));

    await dropboxApi.ensureFolder(artistRoot);
    await dropboxApi.ensureFolder(scheduleRoot);
    await dropboxApi.ensureFolder(descriptionRoot);
    await dropboxApi.ensureFolder(masterRoot);
    await dropboxApi.ensureFolder('$descriptionRoot/$descriptionsDir');

    // Production placeholders
    final prodArtists =
        '$artistRoot/${artistLineupName(prefix, year, testing: false)}';
    final prodSchedule =
        '$scheduleRoot/${scheduleName(prefix, year, testing: false)}';
    final prodMap =
        '$descriptionRoot/${descriptionMapName(prefix, year, testing: false)}';

    // Testing placeholders (what the admin edits)
    final testArtists =
        '$artistRoot/${artistLineupName(prefix, year, testing: true)}';
    final testSchedule =
        '$scheduleRoot/${scheduleName(prefix, year, testing: true)}';
    final testMap =
        '$descriptionRoot/${descriptionMapName(prefix, year, testing: true)}';

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

    final testingPointerPath = '$masterRoot/${pointerName(prefix, testing: true)}';
    final productionPointerPath =
        '$masterRoot/${pointerName(prefix, testing: false)}';

    await dropboxApi.ensureTextFile(testingPointerPath, testingPointerBody);
    await dropboxApi.ensureTextFile(
      productionPointerPath,
      productionPointerBody,
    );

    final testingPointerUrl =
        await dropboxApi.shareUrlForPath(testingPointerPath);
    final productionPointerUrl =
        await dropboxApi.shareUrlForPath(productionPointerPath);

    final alert = await bootstrapAlertFolder(name);

    return FestivalWorkspace(
      festivalName: name,
      eventYear: year,
      testingPointerUrl: testingPointerUrl,
      productionPointerUrl: productionPointerUrl,
      bandListUrl: testBandUrl,
      scheduleUrl: testScheduleUrl,
      descriptionMapUrl: testMapUrl,
      alertFolderUrl: alert.shareUrl,
      artistFilesFolderPath: artistRoot,
      scheduleFilesFolderPath: scheduleRoot,
      descriptionFilesFolderPath: descriptionRoot,
      alertFilesFolderPath: alert.path,
      masterFilesFolderPath: masterRoot,
      ownsArtistFilesFolder: true,
      ownsScheduleFilesFolder: true,
      ownsDescriptionFilesFolder: true,
      ownsAlertFilesFolder: true,
      ownsMasterFilesFolder: true,
      eventTypes: ScheduleValidation.defaultEventTypes,
      canEditBands: true,
      canEditSchedule: true,
      canEditDescriptions: true,
      canEditPointers: true,
      canEditAlerts: true,
    );
  }
}
