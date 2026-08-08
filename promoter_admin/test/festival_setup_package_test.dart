import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_setup_package.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';

void main() {
  test('export round-trip preserves vocabulary and omits reports/alerts by default', () {
    const workspace = FestivalWorkspace(
      festivalName: 'Maryland Deathfest',
      testingPointerUrl: 'https://www.dropbox.com/s/test/pointer_test.txt?raw=1',
      productionPointerUrl: 'https://www.dropbox.com/s/prod/pointer.txt?raw=1',
      festivalLogoUrl: 'https://www.dropbox.com/s/logo.png?raw=1',
      eventYear: '2026',
      venues: ['Main Stage', 'Tent'],
      days: ['Day 1', 'Day 2'],
      dates: ['2026-05-21', '2026-05-22', '2026-05-23'],
      dateRolloverTime: '8:00',
      eventTypes: ['Show', 'Clinic'],
      useCityStateField: true,
      reportsFolderUrl: 'https://www.dropbox.com/scl/fo/reports?dl=0',
      alertFolderUrl: 'https://www.dropbox.com/scl/fo/alerts?dl=0',
    );

    final package = FestivalSetupPackage.fromWorkspace(
      workspace,
      includeReports: false,
      includeAlerts: false,
    );
    expect(package.includesReports, isFalse);
    expect(package.includesAlerts, isFalse);
    expect(package.reportsFolderUrl, isEmpty);
    expect(package.alertFolderUrl, isEmpty);

    final parsed = FestivalSetupPackage.parse(package.toPrettyJson());
    expect(parsed.festivalName, 'Maryland Deathfest');
    expect(parsed.testingPointerUrl, workspace.testingPointerUrl);
    expect(parsed.productionPointerUrl, workspace.productionPointerUrl);
    expect(parsed.venues, ['Main Stage', 'Tent']);
    expect(parsed.days, ['Day 1', 'Day 2']);
    expect(parsed.dates, ['2026-05-21', '2026-05-22', '2026-05-23']);
    expect(parsed.eventTypes, ['Show', 'Clinic']);
    expect(parsed.useCityStateField, isTrue);
    expect(parsed.includesReports, isFalse);
    expect(parsed.includesAlerts, isFalse);

    final restored = parsed.toWorkspace();
    expect(restored.reportsFolderUrl, isEmpty);
    expect(restored.alertFolderUrl, isEmpty);
    expect(restored.venues, workspace.venues);
  });

  test('export can include reports only, alerts only, or both', () {
    const workspace = FestivalWorkspace(
      festivalName: 'MDF',
      testingPointerUrl: 'https://example.com/t.txt',
      reportsFolderUrl: 'https://example.com/reports',
      alertFolderUrl: 'https://example.com/alerts',
    );

    final reportsOnly = FestivalSetupPackage.parse(
      FestivalSetupPackage.fromWorkspace(
        workspace,
        includeReports: true,
        includeAlerts: false,
      ).toPrettyJson(),
    );
    expect(reportsOnly.includesReports, isTrue);
    expect(reportsOnly.includesAlerts, isFalse);
    expect(reportsOnly.reportsFolderUrl, 'https://example.com/reports');
    expect(reportsOnly.alertFolderUrl, isEmpty);
    expect(reportsOnly.toWorkspace().reportsFolderUrl, 'https://example.com/reports');
    expect(reportsOnly.toWorkspace().alertFolderUrl, isEmpty);

    final alertsOnly = FestivalSetupPackage.parse(
      FestivalSetupPackage.fromWorkspace(
        workspace,
        includeReports: false,
        includeAlerts: true,
      ).toPrettyJson(),
    );
    expect(alertsOnly.includesReports, isFalse);
    expect(alertsOnly.includesAlerts, isTrue);
    expect(alertsOnly.reportsFolderUrl, isEmpty);
    expect(alertsOnly.alertFolderUrl, 'https://example.com/alerts');

    final both = FestivalSetupPackage.parse(
      FestivalSetupPackage.fromWorkspace(
        workspace,
        includeReports: true,
        includeAlerts: true,
      ).toPrettyJson(),
    );
    expect(both.includesReports, isTrue);
    expect(both.includesAlerts, isTrue);
    expect(both.reportsFolderUrl, 'https://example.com/reports');
    expect(both.alertFolderUrl, 'https://example.com/alerts');
  });

  test('parse rejects empty or wrong format', () {
    expect(() => FestivalSetupPackage.parse(''), throwsFormatException);
    expect(() => FestivalSetupPackage.parse('not json'), throwsFormatException);
    expect(
      () => FestivalSetupPackage.parse('{"format":"other","festivalName":"X"}'),
      throwsFormatException,
    );
  });

  test('suggestedFileName slugs the festival name', () {
    expect(
      FestivalSetupPackage.suggestedFileName('Maryland Deathfest'),
      'maryland-deathfest-admin-setup.json',
    );
    expect(
      FestivalSetupPackage.suggestedFileName('  '),
      'festival-admin-setup.json',
    );
  });
}
