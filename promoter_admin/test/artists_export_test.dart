import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/artists_export/artist_export_entry.dart';
import 'package:promoter_admin/src/services/artists_export/html_exporter.dart';

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
