import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/csv_staging.dart';
import 'package:promoter_admin/src/services/schedule_staging.dart';

void main() {
  const key = 'Band';

  String merge({
    required String published,
    required String local,
    String? snapshot,
  }) {
    return CsvStagingCoordinator.mergeRemoteWithLocalEdits(
      publishedCsv: published,
      localCsv: local,
      lastSyncedCsv: snapshot,
      keyColumn: key,
      skipKeyLower: 'band',
    );
  }

  test('keeps a remote-only band when local staging is stale', () {
    const snapshot = '''
Band,URL,Date
Existing,https://example.com/old.txt,01-01-2026
''';
    const local = '''
Band,URL,Date
Existing,https://example.com/old.txt,01-01-2026
Edited,https://example.com/edited.txt,09-11-2026
''';
    const published = '''
Band,URL,Date
Existing,https://example.com/old.txt,01-01-2026
NewBand,https://example.com/new.txt,09-11-2026
''';

    final merged = merge(
      published: published,
      local: local,
      snapshot: snapshot,
    );
    expect(merged, contains('NewBand'));
    expect(merged, contains('Edited'));
    expect(merged, contains('Existing'));
  });

  test('applies a local row edit over the published copy of that band', () {
    const snapshot = '''
Band,URL,Date
Existing,https://example.com/old.txt,01-01-2026
''';
    const local = '''
Band,URL,Date
Existing,https://example.com/updated.txt,09-11-2026
''';
    const published = '''
Band,URL,Date
Existing,https://example.com/old.txt,01-01-2026
NewBand,https://example.com/new.txt,09-11-2026
''';

    final merged = merge(
      published: published,
      local: local,
      snapshot: snapshot,
    );
    expect(merged, contains('https://example.com/updated.txt'));
    expect(merged, contains('NewBand'));
    expect(merged, isNot(contains('https://example.com/old.txt')));
  });

  test('keeps published version of a band the admin did not change', () {
    const snapshot = '''
Band,URL,Date
Existing,https://example.com/old.txt,01-01-2026
''';
    const local = snapshot;
    const published = '''
Band,URL,Date
Existing,https://example.com/remote.txt,09-11-2026
NewBand,https://example.com/new.txt,09-11-2026
''';

    final merged = merge(
      published: published,
      local: local,
      snapshot: snapshot,
    );
    expect(merged, contains('https://example.com/remote.txt'));
    expect(merged, contains('NewBand'));
  });

  test('honors an explicit local delete when the band was in the snapshot', () {
    const snapshot = '''
Band,URL,Date
Keep,https://example.com/keep.txt,01-01-2026
Drop,https://example.com/drop.txt,01-01-2026
''';
    const local = '''
Band,URL,Date
Keep,https://example.com/keep.txt,01-01-2026
''';
    const published = '''
Band,URL,Date
Keep,https://example.com/keep.txt,01-01-2026
Drop,https://example.com/drop.txt,01-01-2026
NewBand,https://example.com/new.txt,09-11-2026
''';

    final merged = merge(
      published: published,
      local: local,
      snapshot: snapshot,
    );
    expect(merged, contains('Keep'));
    expect(merged, contains('NewBand'));
    expect(merged, isNot(contains('Drop')));
  });

  test('does not treat remote-only bands as deletes without a snapshot', () {
    const local = '''
Band,URL,Date
Existing,https://example.com/old.txt,01-01-2026
''';
    const published = '''
Band,URL,Date
Existing,https://example.com/old.txt,01-01-2026
NewBand,https://example.com/new.txt,09-11-2026
''';

    final merged = merge(published: published, local: local);
    expect(merged, contains('NewBand'));
    expect(merged, contains('Existing'));
  });

  test('preserves published row order and appends local-only rows', () {
    const snapshot = '''
Band,URL,Date
Zed,https://example.com/zed.txt,01-01-2026
''';
    const local = '''
Band,URL,Date
Zed,https://example.com/zed.txt,01-01-2026
NewLocal,https://example.com/new.txt,09-11-2026
''';
    const published = '''
Band,URL,Date
Zed,https://example.com/zed.txt,01-01-2026
Auto,https://example.com/auto.txt,09-11-2026
''';

    final merged = merge(
      published: published,
      local: local,
      snapshot: snapshot,
    );
    final zed = merged.indexOf('Zed,');
    final auto = merged.indexOf('Auto,');
    final localNew = merged.indexOf('NewLocal,');
    expect(zed, greaterThanOrEqualTo(0));
    expect(auto, greaterThan(zed));
    expect(localNew, greaterThan(auto));
  });

  test('artists: keeps automation band and applies a local rename', () {
    const snapshot = '''
bandName,officalSite,imageUrl,youtube,metalArchives,wikipedia,country,genre,noteworthy,priorYears
TypoBand,https://a.example, , , , ,US,metal, , 
Keep,https://k.example, , , , ,US,metal, , 
''';
    const local = '''
bandName,officalSite,imageUrl,youtube,metalArchives,wikipedia,country,genre,noteworthy,priorYears
FixedBand,https://a.example, , , , ,US,metal, , 
Keep,https://k.example, , , , ,US,metal, , 
''';
    const published = '''
bandName,officalSite,imageUrl,youtube,metalArchives,wikipedia,country,genre,noteworthy,priorYears
TypoBand,https://a.example, , , , ,US,metal, , 
Keep,https://k.example, , , , ,US,metal, , 
Automation,https://auto.example, , , , ,US,metal, , 
''';

    final merged = CsvStagingCoordinator.mergeRemoteWithLocalEdits(
      publishedCsv: published,
      localCsv: local,
      lastSyncedCsv: snapshot,
      keyColumn: 'bandName',
      skipKeyLower: 'bandname',
    );
    expect(merged, contains('FixedBand'));
    expect(merged, contains('Automation'));
    expect(merged, contains('Keep'));
    expect(merged, isNot(contains('TypoBand')));
    expect(merged.split('\n').first.trim(), startsWith('bandName,officalSite'));
  });

  test('schedule: Day 1 local add keeps a remote Day 2 row', () {
    const header =
        'Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL';
    const snapshot = '''
$header
''';
    const local = '''
$header
Local Band,Pool Deck,1/15/2026,Day 1,14:00,14:30,Show, , , 
''';
    const published = '''
$header
Remote Band,Pool Deck,1/16/2026,Day 2,14:00,14:30,Show, , , 
''';

    final merged = CsvStagingCoordinator.mergeRemoteWithLocalEdits(
      publishedCsv: published,
      localCsv: local,
      lastSyncedCsv: snapshot,
      rowKey: ScheduleStagingCoordinator.mergeEventKeyFromRow,
      skipKeyLower: 'band',
    );
    expect(merged, contains('Local Band'));
    expect(merged, contains('Remote Band'));
    expect(merged, contains('Day 1'));
    expect(merged, contains('Day 2'));
  });

  test('schedule: start-time edit removes the original slot key', () {
    const header =
        'Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL';
    const snapshot = '''
$header
Metallica,Pool Deck,1/15/2026,Day 1,14:00,14:30,Show, , , 
''';
    const local = '''
$header
Metallica,Pool Deck,1/15/2026,Day 1,15:00,15:30,Show, , , 
''';
    const published = '''
$header
Metallica,Pool Deck,1/15/2026,Day 1,14:00,14:30,Show, , , 
Slayer,Pool Deck,1/16/2026,Day 2,14:00,14:30,Show, , , 
''';

    final merged = CsvStagingCoordinator.mergeRemoteWithLocalEdits(
      publishedCsv: published,
      localCsv: local,
      lastSyncedCsv: snapshot,
      rowKey: ScheduleStagingCoordinator.mergeEventKeyFromRow,
      skipKeyLower: 'band',
    );
    expect(merged, contains('Metallica,Pool Deck,1/15/2026,Day 1,15:00'));
    expect(
      merged,
      isNot(contains('Metallica,Pool Deck,1/15/2026,Day 1,14:00')),
    );
    expect(merged, contains('Slayer'));
    expect(merged.split('\n').first.trim(), header);
  });
}
