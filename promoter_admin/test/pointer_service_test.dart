import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

void main() {
  test('PointerFile.parse reads Current section', () {
    const text = '''
Current::artistUrl::https://example.com/lineup.csv
Current::scheduleUrl::https://example.com/schedule.csv
Current::eventYear::2027
Current::descriptionMap::https://example.com/map.csv
''';
    final pointer = PointerFile.parse(text);
    expect(pointer.artistUrl, 'https://example.com/lineup.csv');
    expect(pointer.eventYear, '2027');
  });

  test('schedule vocabulary prefers prior year section', () {
    const text = '''
Current::artistUrl::https://example.com/lineup.csv
Current::scheduleUrl::https://example.com/schedule-2027.csv
Current::eventYear::2027
2026::scheduleUrl::https://example.com/schedule-2026.csv
''';
    final pointer = PointerFile.parse(text);
    expect(pointer.scheduleSourceSection, '2026');
    expect(
      pointer.scheduleUrlForVocabulary,
      'https://example.com/schedule-2026.csv',
    );
  });

  test('parseLineupCsv skips header and empty names', () {
    const csv = '''
bandName,genre,country
Iron Test,Death Metal,Sweden
,ignored,
Another Band,Thrash,USA
''';
    final rows = PointerService.parseLineupCsv(csv);
    expect(rows.length, 2);
    expect(rows.first.name, 'Another Band');
    expect(rows.last.name, 'Iron Test');
  });

  test('PointerFile.allowCustomAlerts reads Current flag', () {
    const on = '''
Current::artistUrl::https://example.com/lineup.csv
Current::scheduleUrl::https://example.com/schedule.csv
Current::eventYear::2027
Current::descriptionMap::https://example.com/map.csv
Current::allowCustomAlerts::1
''';
    const off = '''
Current::artistUrl::https://example.com/lineup.csv
Current::scheduleUrl::https://example.com/schedule.csv
Current::eventYear::2027
Current::descriptionMap::https://example.com/map.csv
''';
    expect(PointerFile.parse(on).allowCustomAlerts, isTrue);
    expect(PointerFile.parse(off).allowCustomAlerts, isFalse);
  });

  test('customAlertsUiEnabled needs alert folder plus flag or pointer write', () {
    expect(
      const FestivalWorkspace(
        alertFolderUrl: 'https://dropbox.example/alerts',
        allowCustomAlerts: true,
      ).customAlertsUiEnabled,
      isTrue,
    );
    expect(
      const FestivalWorkspace(
        alertFolderUrl: 'https://dropbox.example/alerts',
        canEditPointers: true,
      ).customAlertsUiEnabled,
      isTrue,
    );
    expect(
      const FestivalWorkspace(
        canEditPointers: true,
        allowCustomAlerts: true,
      ).customAlertsUiEnabled,
      isFalse,
    );
    expect(
      const FestivalWorkspace(
        alertFolderUrl: 'https://dropbox.example/alerts',
      ).customAlertsUiEnabled,
      isFalse,
    );
  });

  test('mergeScheduleVocabulary fills only empty lists', () {
    const existing = FestivalWorkspace(
      venues: ['Pool Deck'],
      days: ['Day 1'],
      dates: ['1/13/2027', '1/14/2027'],
      eventTypes: ['Show', 'Clinic'],
    );
    final merged = PointerService.mergeScheduleVocabulary(
      workspace: existing,
      venues: ['Theater', 'Pool Deck'],
      dates: ['2/1/2027', '2/2/2027', '2/3/2027'],
      days: ['Friday', 'Saturday'],
      eventTypes: ['Show', 'Special Event'],
    );
    expect(merged.venues, ['Pool Deck']);
    expect(merged.days, ['Day 1']);
    expect(merged.dates, ['1/13/2027', '1/14/2027']);
    expect(merged.eventTypes, contains('Clinic'));
  });

  test('PointerFile.dataSourceYears lists archived years with artistUrl', () {
    const text = '''
Current::artistUrl::https://example.com/lineup-2027.csv
Current::scheduleUrl::https://example.com/schedule-2027.csv
Current::eventYear::2027
Current::descriptionMap::https://example.com/map-2027.csv
2026::artistUrl::https://example.com/lineup-2026.csv
2026::scheduleUrl::https://example.com/schedule-2026.csv
2026::eventYear::2026
2026::descriptionMap::https://example.com/map-2026.csv
2025::artistUrl::https://example.com/lineup-2025.csv
2025::eventYear::2025
2024::scheduleUrl::https://example.com/schedule-2024.csv
''';
    final pointer = PointerFile.parse(text);
    expect(pointer.dataSourceYears, ['2026', '2025']);
    final urls = pointer.urlsForYear('2026');
    expect(urls, isNotNull);
    expect(urls!.artistUrl, 'https://example.com/lineup-2026.csv');
    expect(urls.scheduleUrl, 'https://example.com/schedule-2026.csv');
    expect(urls.descriptionMapUrl, 'https://example.com/map-2026.csv');
    expect(pointer.urlsForYear('2024'), isNull);
    expect(pointer.urlsForYear('1999'), isNull);
  });

  test('dataSourceYearOverride round-trips through prefs', () {
    const ws = FestivalWorkspace(
      eventYear: '2027',
      dataSourceYearOverride: '2025',
      bandListUrl: 'https://example.com/old.csv',
    );
    expect(ws.hasDataSourceYearOverride, isTrue);
    final restored = FestivalWorkspace.fromPrefs(ws.toPrefs());
    expect(restored.dataSourceYearOverride, '2025');
    expect(
      ws.copyWith(clearDataSourceYearOverride: true).dataSourceYearOverride,
      '',
    );
  });
}
