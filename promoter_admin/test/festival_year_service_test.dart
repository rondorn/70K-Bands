import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/festival_year_service.dart';

void main() {
  test('new-year filenames use artistFile / scheduleFile / descriptionMap', () {
    expect(
      FestivalYearService.artistFileName('mdf', '2027', testing: false),
      'mdf-artistFile-2027.csv',
    );
    expect(
      FestivalYearService.artistFileName('mdf', '2027', testing: true),
      'mdf-artistFile-2027_test.csv',
    );
    expect(
      FestivalYearService.scheduleFileName('rmf', '2028', testing: false),
      'rmf-scheduleFile-2028.csv',
    );
    expect(
      FestivalYearService.scheduleFileName('rmf', '2028', testing: true),
      'rmf-scheduleFile-2028_test.csv',
    );
    expect(
      FestivalYearService.descriptionMapFileName('x', '2027', testing: false),
      'x-descriptionMap-2027.csv',
    );
    expect(
      FestivalYearService.descriptionMapFileName('x', '2027', testing: true),
      'x-descriptionMap-2027_test.csv',
    );
  });

  test('parentFolderOfPath strips filename', () {
    expect(
      FestivalYearService.parentFolderOfPath('/Fest_Public/mdf-artistFile-2026.csv'),
      '/Fest_Public',
    );
    expect(FestivalYearService.parentFolderOfPath('/file.csv'), '/');
  });

  test('defaultNewYear increments numeric year', () {
    expect(FestivalYearService.defaultNewYear('2026'), '2027');
  });

  test('rewritePointerText archives Current and sets new Current', () {
    const input = '''
Current::artistUrl::https://example.com/old-artists?raw=1
Current::scheduleUrl::https://example.com/old-schedule?raw=1
Current::eventYear::2026
Current::descriptionMap::https://example.com/old-map?raw=1
Current::reportUrl::https://example.com/report.html
2025::scheduleUrl::https://example.com/2025-schedule?raw=1
''';

    final out = FestivalYearService.rewritePointerText(
      pointerText: input,
      oldYear: '2026',
      newYear: '2027',
      artistUrl: 'https://example.com/new-artists?raw=1',
      scheduleUrl: 'https://example.com/new-schedule?raw=1',
      descriptionMapUrl: 'https://example.com/new-map?raw=1',
    );

    final parsed = PointerFile.parse(out);
    expect(parsed.eventYear, '2027');
    expect(parsed.artistUrl, 'https://example.com/new-artists?raw=1');
    expect(parsed.scheduleUrl, 'https://example.com/new-schedule?raw=1');
    expect(parsed.descriptionMapUrl, 'https://example.com/new-map?raw=1');

    final archived = parsed.sections['2026']!;
    expect(archived['artistUrl'], 'https://example.com/old-artists?raw=1');
    expect(archived['scheduleUrl'], 'https://example.com/old-schedule?raw=1');
    expect(archived['eventYear'], '2026');
    expect(archived['descriptionMap'], 'https://example.com/old-map?raw=1');
    expect(archived['reportUrl'], 'https://example.com/report.html');

    // New year exists only as Current — no `2027::` section is created.
    expect(parsed.sections.containsKey('2027'), isFalse);
    expect(out.contains('2027::'), isFalse);

    // Prior year section preserved.
    expect(
      parsed.sections['2025']!['scheduleUrl'],
      'https://example.com/2025-schedule?raw=1',
    );

    // reportUrl kept on Current.
    expect(parsed.current['reportUrl'], 'https://example.com/report.html');
  });

  test('rewritePointerText rejects same old and new year', () {
    expect(
      () => FestivalYearService.rewritePointerText(
        pointerText: 'Current::eventYear::2026\nCurrent::scheduleUrl::x\n',
        oldYear: '2026',
        newYear: '2026',
        artistUrl: 'a',
        scheduleUrl: 'b',
        descriptionMapUrl: 'c',
      ),
      throwsArgumentError,
    );
  });

  test('plannedFilenames lists six test and production files', () {
    final names = FestivalYearService.plannedFilenames(
      prefix: 'mdf',
      newYear: '2027',
    );
    expect(names, hasLength(6));
    expect(names, contains('mdf-artistFile-2027.csv'));
    expect(names, contains('mdf-artistFile-2027_test.csv'));
  });
}
