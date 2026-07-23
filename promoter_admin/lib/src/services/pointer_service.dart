import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/day_date_alignment.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_validation.dart';

class PointerService {
  Future<PointerFile> fetchPointer(
    String url, {
    bool forceRefresh = false,
  }) async {
    final text = await fetchUrlText(url, forceRefresh: forceRefresh);
    return PointerFile.parse(text);
  }

  /// Refresh testing data-file URLs only (lineup / schedule / map).
  /// Does not change venues, dates, days, or event types.
  ///
  /// When [FestivalWorkspace.dataSourceYearOverride] is set, Current year is
  /// still refreshed on [eventYear], then archived-year URLs are re-applied.
  Future<FestivalWorkspace> applyTestingPointer(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final url = workspace.testingPointerUrl.trim();
    if (url.isEmpty) {
      throw StateError('Testing pointer URL is required.');
    }
    final pointer = await fetchPointer(url, forceRefresh: forceRefresh);
    var updated = workspace.copyWith(
      eventYear:
          pointer.eventYear.isNotEmpty ? pointer.eventYear : workspace.eventYear,
      bandListUrl: pointer.artistUrl,
      scheduleUrl: pointer.scheduleUrl,
      descriptionMapUrl: pointer.descriptionMapUrl,
      allowCustomAlerts: pointer.allowCustomAlerts,
    );
    final override = updated.dataSourceYearOverride.trim();
    if (override.isNotEmpty) {
      try {
        updated = await applyDataSourceYear(
          updated,
          override,
          forceRefresh: forceRefresh,
        );
      } catch (_) {
        // Archived year disappeared — fall back to Current quietly.
        updated = updated.copyWith(clearDataSourceYearOverride: true);
      }
    }
    return updated;
  }

  /// List archived years on the Testing pointer available as temporary data
  /// sources (does not consult Production — Current there may still be last year).
  Future<List<String>> listDataSourceYears(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final testingUrl = workspace.testingPointerUrl.trim();
    if (testingUrl.isEmpty) return const [];
    final testing =
        await fetchPointer(testingUrl, forceRefresh: forceRefresh);
    return testing.dataSourceYears;
  }

  /// Point Artists / Schedule / Descriptions at an archived year section from
  /// the Testing pointer only. Local override — does not rewrite Dropbox files.
  Future<FestivalWorkspace> applyDataSourceYear(
    FestivalWorkspace workspace,
    String year, {
    bool forceRefresh = false,
  }) async {
    final target = year.trim();
    if (target.isEmpty) {
      return clearDataSourceYearOverride(workspace, forceRefresh: forceRefresh);
    }

    final testingUrl = workspace.testingPointerUrl.trim();
    if (testingUrl.isEmpty) {
      throw StateError(
        'Testing link is required to look up archived year $target.',
      );
    }
    final testing =
        await fetchPointer(testingUrl, forceRefresh: forceRefresh);
    final urls = testing.urlsForYear(target);
    if (urls == null) {
      throw StateError(
        'Year $target was not found as an archived section on the '
        'Testing pointer.',
      );
    }

    return workspace.copyWith(
      dataSourceYearOverride: target,
      bandListUrl: urls.artistUrl,
      scheduleUrl: urls.scheduleUrl.isNotEmpty
          ? urls.scheduleUrl
          : workspace.scheduleUrl,
      descriptionMapUrl: urls.descriptionMapUrl.isNotEmpty
          ? urls.descriptionMapUrl
          : workspace.descriptionMapUrl,
    );
  }

  /// Restore Artists / Schedule / Descriptions to Testing Current.
  Future<FestivalWorkspace> clearDataSourceYearOverride(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final cleared =
        workspace.copyWith(clearDataSourceYearOverride: true);
    return applyTestingPointer(cleared, forceRefresh: forceRefresh);
  }

  /// Load from both pointers:
  /// - Testing → band / schedule / description-map URLs (+ event year)
  /// - Production → venues, dates, days, event types from production schedule
  ///   **only when the corresponding local list is empty** (never overwrite)
  /// - Custom-alerts UI flag prefers Production Current, else Testing
  ///
  /// Clears any demo year override so Load always returns to Current.
  Future<FestivalWorkspace> applyPointers(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    var updated = await applyTestingPointer(
      workspace.copyWith(clearDataSourceYearOverride: true),
      forceRefresh: forceRefresh,
    );

    final productionUrl = updated.productionPointerUrl.trim();
    if (productionUrl.isEmpty) {
      return updated;
    }

    final production =
        await fetchPointer(productionUrl, forceRefresh: forceRefresh);
    updated = updated.copyWith(
      allowCustomAlerts: production.allowCustomAlerts,
    );

    final vocabScheduleUrl = production.scheduleUrlForVocabulary;
    if (vocabScheduleUrl.isEmpty) {
      throw StateError(
        'Production pointer has no scheduleUrl to load vocabulary from.',
      );
    }

    try {
      final csv = await fetchUrlText(
        vocabScheduleUrl,
        forceRefresh: forceRefresh,
      );
      final events = ScheduleService.parseEvents(csv);
      final hints = ScheduleService.hintsFromEvents(events);
      final pointerTypes = production.eventTypesFromPointer;
      final mergedTypes = <String>[];
      final seen = <String>{};
      for (final t in [
        ...ScheduleValidation.defaultEventTypes,
        ...pointerTypes,
        ...hints.eventTypes,
      ]) {
        final v = t.trim();
        if (v.isEmpty || v == ' ') continue;
        if (seen.add(v)) mergedTypes.add(v);
      }
      updated = mergeScheduleVocabulary(
        workspace: updated,
        venues: hints.venues,
        dates: hints.dates,
        days: hints.days,
        eventTypes: mergedTypes,
      );
    } catch (e) {
      throw StateError(
        'Could not load vocabulary from production schedule: $e',
      );
    }
    return updated;
  }

  /// Fill venues / days / dates / event types only when the local list is empty.
  /// Existing preference values are never overwritten.
  static FestivalWorkspace mergeScheduleVocabulary({
    required FestivalWorkspace workspace,
    required List<String> venues,
    required List<String> dates,
    required List<String> days,
    required List<String> eventTypes,
  }) {
    final cleanVenues = DayDateAlignment.meaningful(venues);
    final cleanDates = DayDateAlignment.normalizeDates(dates);
    final cleanDays = DayDateAlignment.normalizeDays(days);
    final cleanTypes = ScheduleValidation.withDefaultEventTypes(eventTypes);

    return workspace.copyWith(
      venues: DayDateAlignment.meaningful(workspace.venues).isEmpty
          ? cleanVenues
          : workspace.venues,
      dates: DayDateAlignment.meaningful(workspace.dates).isEmpty
          ? cleanDates
          : workspace.dates,
      days: DayDateAlignment.meaningful(workspace.days).isEmpty
          ? cleanDays
          : workspace.days,
      eventTypes: DayDateAlignment.meaningful(workspace.eventTypes).isEmpty
          ? cleanTypes
          : ScheduleValidation.withDefaultEventTypes(workspace.eventTypes),
    );
  }

  Future<List<BandRow>> fetchLineup(
    String bandListUrl, {
    bool forceRefresh = false,
  }) async {
    final text = await fetchUrlText(bandListUrl, forceRefresh: forceRefresh);
    return parseLineupCsv(text);
  }

  static List<BandRow> parseLineupCsv(String text) {
    final bands = parseLineupCsvPreservingOrder(text);
    bands.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return bands;
  }

  /// Artist CSV row order — required for schedule QR band codes (do not sort).
  static List<BandRow> parseLineupCsvPreservingOrder(String text) {
    final rows = parseCsvMaps(text);
    final bands = <BandRow>[];
    for (final map in rows) {
      final name = (map['bandName'] ?? '').trim();
      if (name.isEmpty || name.toLowerCase() == 'bandname') continue;
      bands.add(BandRow(map));
    }
    return bands;
  }

  /// Canonical band names for QR encode/decode (file order, trimmed).
  Future<List<String>> fetchLineupNamesForQr(
    String bandListUrl, {
    bool forceRefresh = false,
  }) async {
    final text = await fetchUrlText(bandListUrl, forceRefresh: forceRefresh);
    return parseLineupCsvPreservingOrder(text)
        .map((row) => row.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }
}
