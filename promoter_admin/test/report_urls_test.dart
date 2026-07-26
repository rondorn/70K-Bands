import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/report_urls.dart';

void main() {
  test('deriveFullReportUrl inserts _full before year suffix', () {
    const url =
        'https://www.dropbox.com/scl/fi/abc/report_dashboard_2027.html?raw=1';
    expect(
      ReportUrls.deriveFullReportUrl(url),
      'https://www.dropbox.com/scl/fi/abc/report_dashboard_full_2027.html?raw=1',
    );
  });

  test('deriveFullReportUrl leaves existing full URLs unchanged', () {
    const url =
        'https://www.dropbox.com/scl/fi/abc/report_dashboard_full_2027.html?raw=1';
    expect(ReportUrls.deriveFullReportUrl(url), url);
  });
}
