import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';

void main() {
  setUp(UrlTextCache.clearMemory);

  test('UrlTextCache keys normalize Dropbox dl=0 to raw=1', () async {
    await UrlTextCache.put(
      'https://www.dropbox.com/s/abc/file.csv?dl=0',
      'body-a',
    );
    expect(
      UrlTextCache.peek('https://www.dropbox.com/s/abc/file.csv?raw=1'),
      'body-a',
    );
  });

  test('invalidate clears memory entry', () async {
    await UrlTextCache.put('https://example.com/x.csv', 'v1');
    await invalidateCachedUrlText('https://example.com/x.csv');
    expect(UrlTextCache.peek('https://example.com/x.csv'), isNull);
  });

  test('putCachedUrlText seeds memory for later peek', () async {
    await putCachedUrlText('https://example.com/lineup.csv', 'csv-data');
    expect(UrlTextCache.peek('https://example.com/lineup.csv'), 'csv-data');
  });
}
