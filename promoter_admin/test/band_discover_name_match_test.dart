import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/band_discover_service.dart';

void main() {
  group('foldBandNameForMatch', () {
    test('folds case and common diacritics including Spanish ñ', () {
      expect(foldBandNameForMatch('  Gürschach '), 'gurschach');
      expect(foldBandNameForMatch('Gurschach'), 'gurschach');
      expect(foldBandNameForMatch('Green Jellÿ'), 'green jelly');
      expect(foldBandNameForMatch('Sólstafir'), 'solstafir');
      expect(foldBandNameForMatch('Señor'), 'senor');
      expect(foldBandNameForMatch('NIÑO'), 'nino');
      // n + combining tilde (NFD)
      expect(foldBandNameForMatch('n\u0303ino'), 'nino');
    });
  });

  group('bandNamesEqualForDiscover', () {
    test('matches same name ignoring case and accents', () {
      expect(bandNamesEqualForDiscover('Exhumed', 'exhumed'), isTrue);
      expect(bandNamesEqualForDiscover('Gürschach', 'Gurschach'), isTrue);
      expect(bandNamesEqualForDiscover('Señor', 'Senor'), isTrue);
      expect(bandNamesEqualForDiscover('El Niño', 'El Nino'), isTrue);
      expect(bandNamesEqualForDiscover('  Vreid ', 'Vreid'), isTrue);
    });

    test('does not fuzzy-match different spelling or spacing', () {
      expect(bandNamesEqualForDiscover('Exhumed', 'Ex humed'), isFalse);
      expect(bandNamesEqualForDiscover('Exhumed', 'Exhumeds'), isFalse);
      expect(bandNamesEqualForDiscover('Exhumed', 'The Exhumed'), isFalse);
      expect(bandNamesEqualForDiscover('Exhumed', 'Exumed'), isFalse);
      expect(bandNamesEqualForDiscover('Señor', 'Senora'), isFalse);
    });
  });

  group('parseMetalArchivesSearchHit', () {
    test('parses name, url, and metadata from an ajax row', () {
      final hit = parseMetalArchivesSearchHit([
        '<a href="https://www.metal-archives.com/bands/Exhumed/143">Exhumed</a>  <!-- 11 -->',
        'Death Metal',
        'United States',
        '1990',
      ]);
      expect(hit, isNotNull);
      expect(hit!.name, 'Exhumed');
      expect(hit.url, 'https://www.metal-archives.com/bands/Exhumed/143');
      expect(hit.genre, 'Death Metal');
      expect(hit.country, 'United States');
      expect(hit.formedYear, '1990');
    });

    test('returns null for malformed rows', () {
      expect(parseMetalArchivesSearchHit(const []), isNull);
      expect(parseMetalArchivesSearchHit(['no link here']), isNull);
    });
  });

  group('exact-name filtering', () {
    test('keeps diacritic-equivalent primary names only', () {
      final rows = [
        [
          '<a href="https://www.metal-archives.com/bands/G%C3%BCrschach/3540404850">Gürschach</a>',
          'Heavy Metal',
          'United States',
          '2018',
        ],
        [
          '<a href="https://www.metal-archives.com/bands/Exhumed_Alive/999">Exhumed Alive</a>',
          'Death Metal',
          'Germany',
          '2001',
        ],
      ];
      final hits = rows
          .map(parseMetalArchivesSearchHit)
          .whereType<MaBandSearchHit>()
          .where((h) => bandNamesEqualForDiscover(h.name, 'Gurschach'))
          .toList();
      expect(hits, hasLength(1));
      expect(hits.single.url, contains('3540404850'));
    });
  });

  group('musicBrainzArtistMatchesExactName', () {
    test('matches on Name ignoring case', () {
      expect(
        musicBrainzArtistMatchesExactName(
          {'name': 'Vreid', 'sort-name': 'Vreid'},
          'vreid',
        ),
        isTrue,
      );
    });

    test('matches folded Name and Sort Name with special characters', () {
      expect(
        musicBrainzArtistMatchesExactName(
          {'name': 'Green Jellÿ', 'sort-name': 'Green Jelly'},
          'Green Jelly',
        ),
        isTrue,
      );
      expect(
        musicBrainzArtistMatchesExactName(
          {'name': 'Gürschach', 'sort-name': 'Gürschach'},
          'Gurschach',
        ),
        isTrue,
      );
    });

    test('does not match unrelated names', () {
      expect(
        musicBrainzArtistMatchesExactName(
          {'name': 'Green Day', 'sort-name': 'Green Day'},
          'Green Jelly',
        ),
        isFalse,
      );
    });
  });

  group('ambiguous pick-list URLs', () {
    test('builds Metal Archives and MusicBrainz search links', () {
      expect(
        metalArchivesSearchUrl('Exhumed'),
        'https://www.metal-archives.com/search?searchString=Exhumed&type=band_name',
      );
      expect(
        musicBrainzSearchUrl('Green Jelly'),
        contains('musicbrainz.org/search'),
      );
      expect(musicBrainzSearchUrl('Green Jelly'), contains('type=artist'));
      expect(musicBrainzSearchUrl('Green Jelly'), contains('Green+Jelly'));
    });
  });
}
