import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/band_discover_service.dart';
import 'package:promoter_admin/src/services/ma_web_html_fetch.dart';

void main() {
  test('unwrapJsStringResult decodes WebView2 \\u003C HTML escapes', () {
    const escaped =
        r'"\u003Ch1 class=\"band_name\"\u003E\u003Ca href=\"https://www.metal-archives.com/bands/Absolute_Darkness/3540421383\"\u003EAbsolute Darkness\u003C/a\u003E\u003C/h1\u003E"';
    final html = MaWebHtmlFetch.unwrapJsStringResult(escaped);
    expect(html.contains('<h1 class="band_name">'), isTrue);
    expect(html.contains(r'\u003C'), isFalse);
    expect(html.contains('Absolute Darkness'), isTrue);
  });

  test('parseMaBandPage strips anchor tags from band name', () {
    const html = '''
<html><body>
<script>var bandName = "Absolute Darkness";</script>
<h1 class="band_name"><a href="https://www.metal-archives.com/bands/Absolute_Darkness/3540421383">Absolute Darkness</a></h1>
<dl>
<dt>Country of origin:</dt><dd>United States</dd>
<dt>Genre:</dt><dd>Black Metal</dd>
</dl>
<a id="logo" href="https://www.metal-archives.com/images/3/5/4/0/3540421383_logo.jpg?1"></a>
</body></html>
''';
    final service = BandDiscoverService();
    // ignore: invalid_use_of_visible_for_testing_member
    final page = service.debugParseMaBandPage(
      html,
      'https://www.metal-archives.com/bands/Absolute_Darkness/3540421383',
    );
    expect(page['bandName'], 'Absolute Darkness');
    expect(page['country'], 'United States');
    expect(page['genre'], 'Black Metal');
  });

  test('ajax-list sized bodies are acceptable for WebView2', () {
    const html = '''
<table>
<tr id="header_Official"><td>Official</td></tr>
<tr><td><a href="https://absolutedarkness1.bandcamp.com/">Bandcamp</a></td></tr>
</table>
''';
    expect(
      MaWebHtmlFetch.isAcceptableMaBody(html, expectJson: false),
      isTrue,
    );
  });

  test('expectJson accepts HTML band links from WebView-painted ajax', () {
    const html = '''
*<a href="https://www.metal-archives.com/bands/Absolute_Darkness/3540421383">Absolute Darkness</a>
''';
    expect(
      MaWebHtmlFetch.isAcceptableMaBody(html, expectJson: true),
      isTrue,
    );
  });

  test('expectJson accepts short JSON ajax payloads', () {
    expect(
      MaWebHtmlFetch.isAcceptableMaBody(
        '{"aaData":[]}',
        expectJson: true,
      ),
      isTrue,
    );
  });
}
