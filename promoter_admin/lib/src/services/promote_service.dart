import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_year_service.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

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
    List<String>? messages,
  }) : messages = messages ?? <String>[];

  int bandsTesting;
  int bandsProduction;
  int eventsTesting;
  int eventsProduction;
  int mapRowsTesting;
  int mapRowsProduction;
  String testingYear;
  String productionYear;
  final List<String> messages;

  bool get isYearRoll {
    final t = testingYear.trim();
    final p = productionYear.trim();
    return t.isNotEmpty && p.isNotEmpty && t != p;
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

  Future<Map<String, String>> _currentUrls(String pointerUrl) async {
    final pointer = await pointerService.fetchPointer(pointerUrl);
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
      return _productionShareUrlForTestingUrl(src);
    }

    final dest = {
      'band_list_url': await resolve('band_list_url'),
      'schedule_url': await resolve('schedule_url'),
      'description_map_url': await resolve('description_map_url'),
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

  Future<PromoteDiff> preview(FestivalWorkspace workspace) async {
    final testingUrl = workspace.testingPointerUrl.trim();
    final productionUrl = workspace.productionPointerUrl.trim();
    if (testingUrl.isEmpty) {
      throw StateError('Testing pointer URL is not configured.');
    }
    if (productionUrl.isEmpty) {
      throw StateError('Production pointer URL is not configured.');
    }

    final testUrls = await _currentUrls(testingUrl);
    final prodUrls = await _currentUrls(productionUrl);
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

    Future<void> count(
      String key,
      void Function(int t, int p) assign,
    ) async {
      final tUrl = testUrls[key] ?? '';
      final pUrl = destUrls[key] ?? '';
      if (tUrl.isEmpty || pUrl.isEmpty) {
        diff.messages.add('Missing URL for $key on testing or production target.');
        return;
      }
      try {
        final tText = await fetchUrlText(tUrl);
        final pText = await fetchUrlText(pUrl);
        assign(countCsvRows(tText), countCsvRows(pText));
      } catch (e) {
        diff.messages.add('Could not fetch $key: $e');
      }
    }

    await count('band_list_url', (t, p) {
      diff.bandsTesting = t;
      diff.bandsProduction = p;
    });
    await count('schedule_url', (t, p) {
      diff.eventsTesting = t;
      diff.eventsProduction = p;
    });
    await count('description_map_url', (t, p) {
      diff.mapRowsTesting = t;
      diff.mapRowsProduction = p;
    });

    return diff;
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

    final testUrls = await _currentUrls(testingUrl);
    final prodUrls = await _currentUrls(productionUrl);
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
      if (src == dest) {
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
        await dropboxApi.uploadTextInPlace(dest, text);
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

  /// Resolve Current URLs from a pointer (exposed for tests / diagnostics).
  Future<PointerFile> fetchPointer(String url) => pointerService.fetchPointer(url);
}
