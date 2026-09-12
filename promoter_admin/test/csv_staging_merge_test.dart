import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/csv_staging.dart';

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
}
