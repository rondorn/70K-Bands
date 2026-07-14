import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
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
  Future<FestivalWorkspace> applyTestingPointer(
    FestivalWorkspace workspace,
  ) async {
    final url = workspace.testingPointerUrl.trim();
    if (url.isEmpty) {
      throw StateError('Testing pointer URL is required.');
    }
    final pointer = await fetchPointer(url);
    return workspace.copyWith(
      eventYear:
          pointer.eventYear.isNotEmpty ? pointer.eventYear : workspace.eventYear,
      bandListUrl: pointer.artistUrl,
      scheduleUrl: pointer.scheduleUrl,
      descriptionMapUrl: pointer.descriptionMapUrl,
      allowCustomAlerts: pointer.allowCustomAlerts,
    );
  }

  /// Load from both pointers:
  /// - Testing → band / schedule / description-map URLs (+ event year)
  /// - Production → venues, dates, days, event types from production schedule
  /// - Custom-alerts UI flag prefers Production Current, else Testing
  Future<FestivalWorkspace> applyPointers(FestivalWorkspace workspace) async {
    var updated = await applyTestingPointer(workspace);

    final productionUrl = updated.productionPointerUrl.trim();
    if (productionUrl.isEmpty) {
      throw StateError(
        'Production pointer URL is required to load venues and event types.',
      );
    }

    final production = await fetchPointer(productionUrl);
    // Developer gate lives on the Production pointer Current section.
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
      final csv = await fetchUrlText(vocabScheduleUrl);
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
      updated = updated.copyWith(
        venues: hints.venues,
        dates: hints.dates,
        days: hints.days,
        eventTypes: ScheduleValidation.withDefaultEventTypes(mergedTypes),
      );
    } catch (e) {
      throw StateError(
        'Could not load vocabulary from production schedule: $e',
      );
    }
    return updated;
  }

  Future<List<BandRow>> fetchLineup(String bandListUrl) async {
    final text = await fetchUrlText(bandListUrl);
    return parseLineupCsv(text);
  }

  static List<BandRow> parseLineupCsv(String text) {
    final rows = parseCsvMaps(text);
    final bands = <BandRow>[];
    for (final map in rows) {
      final name = (map['bandName'] ?? '').trim();
      if (name.isEmpty || name.toLowerCase() == 'bandname') continue;
      bands.add(BandRow(map));
    }
    bands.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return bands;
  }
}
