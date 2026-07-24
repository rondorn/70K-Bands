import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';

void main() {
  test('normalizeDropboxUrl replaces dl=0 with raw=1 on Dropbox hosts', () {
    expect(
      normalizeDropboxUrl(
        'https://www.dropbox.com/s/abc/file.csv?dl=0',
      ),
      'https://www.dropbox.com/s/abc/file.csv?raw=1',
    );
    expect(
      normalizeDropboxUrl(
        'https://www.dropbox.com/scl/fi/abc/file.csv?rlkey=xyz&dl=0',
      ),
      'https://www.dropbox.com/scl/fi/abc/file.csv?rlkey=xyz&raw=1',
    );
  });

  test('normalizeDropboxUrl leaves non-Dropbox URLs unchanged', () {
    const url = 'https://example.com/page?dl=0';
    expect(normalizeDropboxUrl(url), url);
  });

  test('displayShareUrl matches normalizeDropboxUrl', () {
    const input =
        'https://www.dropbox.com/s/abc/logo.png?rlkey=abc&dl=0';
    expect(displayShareUrl(input), normalizeDropboxUrl(input));
  });
}
