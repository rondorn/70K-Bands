import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/location_parse.dart';

void main() {
  group('stateNameToCode', () {
    test('maps full US state names to two-letter codes', () {
      expect(stateNameToCode('California'), 'CA');
      expect(stateNameToCode('New York'), 'NY');
      expect(stateNameToCode('district of columbia'), 'DC');
    });

    test('passes through existing two-letter codes', () {
      expect(stateNameToCode('ca'), 'CA');
      expect(stateNameToCode('TX'), 'TX');
    });
  });

  group('parseMaLocation', () {
    test('splits city and converts full state name', () {
      final parsed = parseMaLocation('Atlanta, Georgia', country: 'United States');
      expect(parsed.city, 'Atlanta');
      expect(parsed.state, 'GA');
    });

    test('handles city-only non-US locations', () {
      final parsed = parseMaLocation('Gothenburg', country: 'Sweden');
      expect(parsed.city, 'Gothenburg');
      expect(parsed.state, '');
    });
  });

  group('parseMusicBrainzLocation', () {
    test('uses begin-area city and subdivision state', () {
      final parsed = parseMusicBrainzLocation({
        'country': 'US',
        'begin-area': {'name': 'Oakland'},
        'area': {'type': 'Subdivision', 'name': 'California'},
      });
      expect(parsed.city, 'Oakland');
      expect(parsed.state, 'CA');
    });
  });

  group('LineupService fields', () {
    test('appends city and state when enabled', () {
      expect(LineupService.fieldsFor(useCityState: false), LineupService.fields);
      expect(
        LineupService.fieldsFor(useCityState: true),
        [...LineupService.fields, 'city', 'state'],
      );
    });
  });
}
