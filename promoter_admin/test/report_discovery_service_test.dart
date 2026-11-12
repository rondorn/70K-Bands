import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';
import 'package:promoter_admin/src/services/report_discovery_service.dart';
import 'package:promoter_admin/src/services/report_urls.dart';

void main() {
  group('pickMainDashboardName', () {
    test('prefers English dashboard with event year', () {
      const names = [
        'report_dashboard_2027.html',
        'report_dashboard-en_2027.html',
        'report_dashboard_full_2027.html',
      ];
      expect(
        ReportDiscoveryService.pickMainDashboardName(names, '2027'),
        'report_dashboard-en_2027.html',
      );
    });

    test('falls back to generic dashboard when English missing', () {
      const names = ['report_dashboard_2027.html'];
      expect(
        ReportDiscoveryService.pickMainDashboardName(names, '2027'),
        'report_dashboard_2027.html',
      );
    });

    test('uses English without year when year-specific file missing', () {
      const names = ['report_dashboard-en.html', 'report_dashboard.html'];
      expect(
        ReportDiscoveryService.pickMainDashboardName(names, '2027'),
        'report_dashboard-en.html',
      );
    });
  });

  group('pickFullDashboardName', () {
    test('finds full dashboard with event year', () {
      const names = [
        'report_dashboard-en_2027.html',
        'report_dashboard_full_2027.html',
      ];
      expect(
        ReportDiscoveryService.pickFullDashboardName(names, '2027'),
        'report_dashboard_full_2027.html',
      );
    });
  });

  group('PointerFile endUserReportUrl', () {
    test('prefers reportUrl-en over reportUrl', () {
      final pointer = PointerFile.parse('''
Current::artistUrl::https://example.com/a.csv
Current::scheduleUrl::https://example.com/s.csv
Current::descriptionMap::https://example.com/d.csv
Current::reportUrl::https://example.com/generic.html
Current::reportUrl-en::https://example.com/en.html
''');
      expect(pointer.endUserReportUrl, 'https://example.com/en.html');
    });
  });

  test('preservingSessionReportFields keeps cached discovery metadata', () {
    const before = FestivalWorkspace(
      reportUrlFull: 'https://example.com/full.html',
      reportDiscoveryEventYear: '2027',
      reportDiscoveryFolderUrl: 'https://dropbox.com/folder',
    );
    const refreshed = FestivalWorkspace(
      reportUrl: 'https://example.com/end-user.html',
    );
    final merged = before.preservingSessionReportFields(refreshed);
    expect(merged.reportUrlFull, 'https://example.com/full.html');
    expect(merged.reportDiscoveryEventYear, '2027');
    expect(merged.reportDiscoveryFolderUrl, 'https://dropbox.com/folder');
  });

  test('preservingSessionReportFields drops last year when Current moves on', () {
    const before = FestivalWorkspace(
      eventYear: '2026',
      reportUrl:
          'https://www.dropbox.com/scl/fi/old/report_dashboard-en_2026.html?raw=1',
      reportUrlFull:
          'https://www.dropbox.com/scl/fi/old/report_dashboard_full_2026.html?raw=1',
      reportDiscoveryEventYear: '2026',
      reportDiscoveryFolderUrl: 'https://www.dropbox.com/scl/fo/folder?raw=1',
    );
    const refreshed = FestivalWorkspace(
      eventYear: '2027',
      reportUrl:
          'https://www.dropbox.com/scl/fi/new/report_dashboard-en_2027.html?raw=1',
      reportUrlFull:
          'https://www.dropbox.com/scl/fi/old/report_dashboard_full_2026.html?raw=1',
      reportDiscoveryEventYear: '2026',
      reportDiscoveryFolderUrl: 'https://www.dropbox.com/scl/fo/folder?raw=1',
    );
    final merged = before.preservingSessionReportFields(refreshed);
    expect(merged.eventYear, '2027');
    expect(
      merged.reportUrl,
      'https://www.dropbox.com/scl/fi/new/report_dashboard-en_2027.html?raw=1',
    );
    expect(merged.reportUrlFull, isEmpty);
    expect(merged.reportDiscoveryEventYear, isEmpty);
    expect(merged.reportDiscoveryFolderUrl, isEmpty);
  });

  test('preservingSessionReportFields keeps same-year discovery over a stale refresh', () {
    const before = FestivalWorkspace(
      eventYear: '2027',
      reportUrlFull:
          'https://www.dropbox.com/scl/fi/new/report_dashboard_full_2027.html?raw=1',
      reportDiscoveryEventYear: '2027',
      reportDiscoveryFolderUrl: 'https://www.dropbox.com/scl/fo/folder?raw=1',
    );
    const refreshed = FestivalWorkspace(
      eventYear: '2027',
      reportUrlFull:
          'https://www.dropbox.com/scl/fi/old/report_dashboard_full_2026.html?raw=1',
      reportDiscoveryEventYear: '2026',
      reportDiscoveryFolderUrl: 'https://www.dropbox.com/scl/fo/folder?raw=1',
    );
    final merged = before.preservingSessionReportFields(refreshed);
    expect(
      merged.reportUrlFull,
      'https://www.dropbox.com/scl/fi/new/report_dashboard_full_2027.html?raw=1',
    );
    expect(merged.reportDiscoveryEventYear, '2027');
  });

  test('eventYearInReportUrl reads the year suffix from a Dropbox report link', () {
    expect(
      ReportUrls.eventYearInReportUrl(
        'https://www.dropbox.com/scl/fi/abc/report_dashboard_full_2027.html?raw=1',
      ),
      '2027',
    );
    expect(
      ReportUrls.eventYearInReportUrl(
        'https://www.dropbox.com/scl/fi/abc/report_dashboard-en_2026.html?raw=1',
      ),
      '2026',
    );
    expect(
      ReportUrls.eventYearInReportUrl(
        'https://www.dropbox.com/scl/fi/abc/stats_unavailable.html?raw=1',
      ),
      isEmpty,
    );
  });

  group('isCacheValid', () {
    test('true when folder and event year match discovery metadata', () {
      const workspace = FestivalWorkspace(
        reportsFolderUrl: 'https://www.dropbox.com/scl/fo/abc?dl=0',
        eventYear: '2027',
        reportDiscoveryEventYear: '2027',
        reportDiscoveryFolderUrl:
            'https://www.dropbox.com/scl/fo/abc?raw=1',
      );
      expect(ReportDiscoveryService.isCacheValid(workspace), isTrue);
    });

    test('false when event year changes', () {
      const workspace = FestivalWorkspace(
        reportsFolderUrl: 'https://www.dropbox.com/scl/fo/abc?raw=1',
        eventYear: '2028',
        reportDiscoveryEventYear: '2027',
        reportDiscoveryFolderUrl:
            'https://www.dropbox.com/scl/fo/abc?raw=1',
      );
      expect(ReportDiscoveryService.isCacheValid(workspace), isFalse);
    });
  });
}
