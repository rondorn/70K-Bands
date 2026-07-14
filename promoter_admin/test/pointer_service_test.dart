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
}
