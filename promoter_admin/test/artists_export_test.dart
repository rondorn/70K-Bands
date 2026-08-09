import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/artists_export/artist_export_entry.dart';
import 'package:promoter_admin/src/services/artists_export/html_exporter.dart';
import 'package:promoter_admin/src/services/artists_export/logo_fetcher.dart';

void main() {
  group('ensureHttpUrl', () {
    test('adds https for scheme-stripped paths', () {
      expect(
        ensureHttpUrl('www.example.com/band'),
        'https://www.example.com/band',
      );
    });

    test('keeps existing schemes and blanks', () {
      expect(ensureHttpUrl('https://a.test'), 'https://a.test');
      expect(ensureHttpUrl('http://a.test'), 'http://a.test');
      expect(ensureHttpUrl(''), '');
      expect(ensureHttpUrl(' '), '');
    });
  });

  group('ArtistExportEntry.fromBands', () {
    test('sorts alphabetically and maps official site / image', () {
      final entries = ArtistExportEntry.fromBands([
        BandRow({
          'bandName': 'Zeal',
          'imageUrl': 'cdn.example/z.png',
          'officalSite': 'zeal.example',
        }),
        BandRow({
          'bandName': 'Alpha',
          'imageUrl': ' ',
          'officalSite': 'https://alpha.example',
        }),
        BandRow({'bandName': '', 'imageUrl': 'x', 'officalSite': 'y'}),
      ]);

      expect(entries.map((e) => e.name), ['Alpha', 'Zeal']);
      expect(entries[0].officialUrl, 'https://alpha.example');
      expect(entries[0].imageUrl, '');
      expect(entries[1].imageUrl, 'https://cdn.example/z.png');
      expect(entries[1].officialUrl, 'https://zeal.example');
    });
  });

  group('LogoFetcher', () {
    test('normalizeFetchUrl adds https and recognizes MA hosts', () {
      expect(
        LogoFetcher.normalizeFetchUrl('www.metal-archives.com/images/1.png'),
        'https://www.metal-archives.com/images/1.png',
      );
      expect(
        LogoFetcher.isMetalArchivesHost(
          'https://www.metal-archives.com/images/1.png',
        ),
        isTrue,
      );
      expect(
        LogoFetcher.isMetalArchivesHost('https://cdn.example/logo.png'),
        isFalse,
      );
    });

    test('retries HTTP 429 then embeds logo bytes', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        if (attempts < 3) {
          return http.Response('slow down', 429);
        }
        return http.Response.bytes(
          const [1, 2, 3, 4],
          200,
          headers: {'content-type': 'image/png'},
        );
      });

      final withLogos = await LogoFetcher.attachBandLogos(
        const [
          ArtistExportEntry(
            name: 'Akercocke',
            imageUrl: 'https://www.metal-archives.com/images/a.gif',
            officialUrl: '',
          ),
        ],
        metalArchivesClient: client,
        concurrency: 1,
        backoff: (_) => Duration.zero,
        interRequestDelay: () => Duration.zero,
      );

      expect(attempts, 3);
      expect(withLogos.single.imageBytes, isNotNull);
      expect(withLogos.single.imageBytes, [1, 2, 3, 4]);
    });

    test('does not retry hard 404 failures', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        return http.Response('gone', 404);
      });

      final withLogos = await LogoFetcher.attachBandLogos(
        const [
          ArtistExportEntry(
            name: 'Missing',
            imageUrl: 'https://cdn.example/missing.png',
            officialUrl: '',
          ),
        ],
        client: client,
        concurrency: 1,
        backoff: (_) => Duration.zero,
        interRequestDelay: () => Duration.zero,
      );

      expect(attempts, 1);
      expect(withLogos.single.imageBytes, isNull);
    });

    test('applies inter-request delay before each logo fetch', () async {
      var pauses = 0;
      final client = MockClient((request) async {
        return http.Response.bytes(const [9], 200);
      });

      await LogoFetcher.attachBandLogos(
        const [
          ArtistExportEntry(
            name: 'A',
            imageUrl: 'https://cdn.example/a.png',
            officialUrl: '',
          ),
          ArtistExportEntry(
            name: 'B',
            imageUrl: 'https://cdn.example/b.png',
            officialUrl: '',
          ),
        ],
        client: client,
        concurrency: 1,
        backoff: (_) => Duration.zero,
        interRequestDelay: () {
          pauses++;
          return Duration.zero;
        },
      );

      expect(pauses, 2);
    });
  });

  group('ArtistsHtmlExporter', () {
    test('builds 4-column grid with title hover and official link', () {
      final bytes = ArtistsHtmlExporter.build(
        artists: const [
          ArtistExportEntry(
            name: 'Alpha',
            imageUrl: '',
            officialUrl: 'https://alpha.example',
          ),
          ArtistExportEntry(
            name: 'Beta',
            imageUrl: '',
            officialUrl: '',
          ),
        ],
        festivalName: 'Test Fest',
        year: '2026',
        useColor: true,
      );
      final html = String.fromCharCodes(bytes);
      expect(html, contains('grid-template-columns: repeat(4'));
      expect(html, contains('title="Alpha"'));
      expect(html, contains('href="https://alpha.example"'));
      expect(html, contains('name-fallback'));
      expect(html, contains('Test Fest'));
      expect(html, contains('2026'));
      expect(html, contains('class="color"'));
    });

    test('applies monochrome class for black and white', () {
      final bytes = ArtistsHtmlExporter.build(
        artists: const [],
        festivalName: 'Fest',
        useColor: false,
      );
      expect(String.fromCharCodes(bytes), contains('class="monochrome"'));
    });
  });
}
