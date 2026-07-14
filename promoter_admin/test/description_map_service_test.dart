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
  });
}
