import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/promote_service.dart';

void main() {
  test('countCsvRows ignores header', () {
    expect(PromoteService.countCsvRows(''), 0);
    expect(PromoteService.countCsvRows('Band,URL,Date\n'), 0);
    expect(
      PromoteService.countCsvRows('Band,URL,Date\nFoo,http://x,2026-01-01\n'),
      1,
    );
  });

  test('productionPathFromTestingPath strips _test before .csv', () {
    expect(
      PromoteService.productionPathFromTestingPath(
        '/Fest/mmf-artistFile-2027_test.csv',
      ),
      '/Fest/mmf-artistFile-2027.csv',
    );
    expect(
      PromoteService.productionPathFromTestingPath(
        'Fest/mdf_artistLineup_2027_test.csv',
      ),
      '/Fest/mdf_artistLineup_2027.csv',
    );
  });

  test('productionPathFromTestingPath never equals a prior-year production path', () {
    const testing2027 = '/Fest/mmf-artistFile-2027_test.csv';
    const archived2026 = '/Fest/mmf-artistFile-2026.csv';
    final dest2027 = PromoteService.productionPathFromTestingPath(testing2027);
    expect(dest2027, '/Fest/mmf-artistFile-2027.csv');
    expect(dest2027, isNot(archived2026));
  });

  test('PromoteDiff year-roll summary mentions leaving prior year files alone', () {
    final roll = PromoteDiff(
      testingYear: '2027',
      productionYear: '2026',
      messages: [
        'Data is written only to 2027 production files; '
            '2026 production files are left unchanged.',
      ],
    );
    expect(
      roll.summaryLines.any((l) => l.contains('2026 production files are left unchanged')),
      isTrue,
    );
  });
}
