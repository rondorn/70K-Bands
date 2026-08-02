import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';

void main() {
  group('DescriptionMapService.nextCacheDate', () {
    final day = DateTime(2026, 7, 14);
    const today = '07-14-2026';

    test('empty becomes today', () {
      expect(
        DescriptionMapService.nextCacheDate('', now: day),
        today,
      );
      expect(
        DescriptionMapService.nextCacheDate(null, now: day),
        today,
      );
    });

    test('same day gets -1 then -2', () {
      expect(
        DescriptionMapService.nextCacheDate(today, now: day),
        '$today-1',
      );
      expect(
        DescriptionMapService.nextCacheDate('$today-1', now: day),
        '$today-2',
      );
      expect(
        DescriptionMapService.nextCacheDate('$today-2', now: day),
        '$today-3',
      );
    });

    test('different day resets to today', () {
      expect(
        DescriptionMapService.nextCacheDate('07-13-2026', now: day),
        today,
      );
      expect(
        DescriptionMapService.nextCacheDate('07-13-2026-4', now: day),
        today,
      );
    });

    test('same-day edits keep incrementing suffix', () {
      final today = DescriptionMapService.cacheDateToday();
      expect(
        DescriptionMapService.nextCacheDate(today),
        '$today-1',
      );
      expect(
        DescriptionMapService.nextCacheDate('$today-1'),
        '$today-2',
      );
    });
  });

  group('DescriptionMapService.parseEntries', () {
    test('reads UpdatedBy when present', () {
      const csv = '''
Band,URL,Date,UpdatedBy
Amorphis,https://example.com/a.txt,07-14-2025,bot@example.com
Dark Tranquillity,https://example.com/d.txt,07-16-2025,
''';
      final entries = DescriptionMapService.parseEntries(csv);
      expect(entries, hasLength(2));
      expect(entries[0].updatedBy, 'bot@example.com');
      expect(entries[1].updatedBy, isEmpty);
    });

    test('tolerates maps without UpdatedBy column', () {
      const csv = '''
Band,URL,Date
Amorphis,https://example.com/a.txt,07-14-2025
''';
      final entries = DescriptionMapService.parseEntries(csv);
      expect(entries.single.updatedBy, isEmpty);
    });
  });

  group('DescriptionMapService.normalizeUpdatedBy', () {
    test('treats null literal and null characters as empty', () {
      expect(DescriptionMapService.normalizeUpdatedBy(null), isEmpty);
      expect(DescriptionMapService.normalizeUpdatedBy(''), isEmpty);
      expect(DescriptionMapService.normalizeUpdatedBy('null'), isEmpty);
      expect(DescriptionMapService.normalizeUpdatedBy('NULL'), isEmpty);
      expect(DescriptionMapService.normalizeUpdatedBy('\x00'), isEmpty);
      expect(
        DescriptionMapService.normalizeUpdatedBy('bot@example.com'),
        'bot@example.com',
      );
    });
  });

  group('DescriptionMapService.toCsv', () {
    test('omits UpdatedBy header when no row has an editor', () {
      final csv = DescriptionMapService.toCsv([
        DescriptionMapEntry(
          band: 'Amorphis',
          url: 'https://example.com/a.txt',
          date: '07-14-2025',
        ),
      ]);
      expect(csv.split('\n').first.trim(), 'Band,URL,Date');
      expect(csv, isNot(contains('UpdatedBy')));
    });

    test('includes UpdatedBy header when any row has an editor', () {
      final csv = DescriptionMapService.toCsv([
        DescriptionMapEntry(
          band: 'Amorphis',
          url: 'https://example.com/a.txt',
          date: '07-14-2025',
          updatedBy: 'editor@example.com',
        ),
      ]);
      expect(csv.split('\n').first.trim(), 'Band,URL,Date,UpdatedBy');
      expect(csv, contains('editor@example.com'));
    });

    test('adds UpdatedBy header when upgrading a 3-column automated map', () {
      const original = '''
Band,URL,Date
Amorphis,https://example.com/a.txt,07-14-2025
Dark Tranquillity,https://example.com/d.txt,07-16-2025
''';
      final entries = DescriptionMapService.parseEntries(original);
      entries[0] = DescriptionMapEntry(
        band: entries[0].band,
        url: entries[0].url,
        date: entries[0].date,
        updatedBy: 'editor@example.com',
      );
      final csv = DescriptionMapService.toCsv(entries);
      expect(csv.split('\n').first.trim(), 'Band,URL,Date,UpdatedBy');
      final lines = csv
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      expect(lines[1], endsWith('editor@example.com'));
      expect(lines[2], endsWith(','));
    });
  });

  group('DescriptionMapService.parseEntries', () {
    test('treats null literal UpdatedBy as empty', () {
      const csv = '''
Band,URL,Date,UpdatedBy
Amorphis,https://example.com/a.txt,07-14-2025,null
''';
      expect(
        DescriptionMapService.parseEntries(csv).single.updatedBy,
        isEmpty,
      );
    });
  });

  group('DescriptionMapService.descriptionTextCacheKey', () {
    test('includes opaque map date string in cache key', () {
      const url = 'https://www.dropbox.com/s/abc/band.txt?raw=1';
      expect(
        DescriptionMapService.descriptionTextCacheKey(url, '08-11-2025'),
        '$url::desc::08-11-2025',
      );
      expect(
        DescriptionMapService.descriptionTextCacheKey(url, '08-11-2025-1'),
        isNot(
          DescriptionMapService.descriptionTextCacheKey(url, '08-11-2025'),
        ),
      );
    });

    test('empty map date falls back to url-only key', () {
      const url = 'https://example.com/band.txt';
      expect(
        DescriptionMapService.descriptionTextCacheKey(url, ''),
        url,
      );
    });
  });
}
