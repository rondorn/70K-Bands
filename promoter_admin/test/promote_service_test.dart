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

  test('addedBandsFromCsv returns names only in testing', () {
    const production = 'bandName,country\nAlpha,US\nBeta,DE\n';
    const testing =
        'bandName,country\nAlpha,US\nBeta,DE\nGamma,SE\ndelta,NO\n';
    expect(
      PromoteService.addedBandsFromCsv(
        testingCsv: testing,
        productionCsv: production,
      ),
      ['delta', 'Gamma'],
    );
  });

  test('bandAnnouncementText is plain text list', () {
    expect(
      PromoteService.bandAnnouncementText(
        festivalName: 'MDF',
        bands: ['Band A', 'Band B'],
      ),
      'The following bands have just been added to MDF!\n'
      'Band A\n'
      'Band B\n',
    );
  });

  test('bandAnnouncementPendingFileName uses datetime stamp', () {
    expect(
      PromoteService.bandAnnouncementPendingFileName(
        DateTime(2026, 7, 14, 8, 45, 3),
      ),
      'bandAnnouncements-2026-07-14-08-45-03.pending',
    );
  });

  test('customAlertPendingFileName uses datetime stamp', () {
    expect(
      PromoteService.customAlertPendingFileName(
        DateTime(2026, 7, 14, 9, 1, 2),
      ),
      'customAlert-2026-07-14-09-01-02.pending',
    );
  });
}
