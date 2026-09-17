import 'dart:convert';

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

  test('fetchUrlText can store under a custom cache key', () async {
    await putCachedUrlText(
      'https://example.com/band.txt::desc::07-22-2026-1',
      'fresh body',
    );
    expect(
      UrlTextCache.peek('https://example.com/band.txt::desc::07-22-2026-1'),
      'fresh body',
    );
    expect(
      UrlTextCache.peek('https://example.com/band.txt::desc::07-22-2026-2'),
      isNull,
    );
    expect(UrlTextCache.peek('https://example.com/band.txt'), isNull);
  });

  test('decodeUtf8Text keeps Æ instead of Latin-1 mojibake', () {
    const name = 'Æther Realm';
    final utf8Bytes = utf8.encode(name);
    expect(latin1.decode(utf8Bytes), 'Ã\u0086ther Realm');
    expect(decodeUtf8Text(utf8Bytes), name);
    expect(decodeUtf8Text([0xEF, 0xBB, 0xBF, ...utf8Bytes]), name);
  });

  test('cacheBustedUrl adds unique query param without dropping others', () {
    final busted = cacheBustedUrl(
      'https://www.dropbox.com/s/abc/file.txt?raw=1',
    );
    final uri = Uri.parse(busted);
    expect(uri.queryParameters['raw'], '1');
    expect(uri.queryParameters['_'], isNotNull);
    expect(uri.queryParameters['_']!.isNotEmpty, isTrue);
  });
}
