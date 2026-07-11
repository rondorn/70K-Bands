/// Parse city and US state from Metal Archives and MusicBrainz location data.

const _usStateNameToCode = <String, String>{
  'alabama': 'AL',
  'alaska': 'AK',
  'arizona': 'AZ',
  'arkansas': 'AR',
  'california': 'CA',
  'colorado': 'CO',
  'connecticut': 'CT',
  'delaware': 'DE',
  'district of columbia': 'DC',
  'florida': 'FL',
  'georgia': 'GA',
  'hawaii': 'HI',
  'idaho': 'ID',
  'illinois': 'IL',
  'indiana': 'IN',
  'iowa': 'IA',
  'kansas': 'KS',
  'kentucky': 'KY',
  'louisiana': 'LA',
  'maine': 'ME',
  'maryland': 'MD',
  'massachusetts': 'MA',
  'michigan': 'MI',
  'minnesota': 'MN',
  'mississippi': 'MS',
  'missouri': 'MO',
  'montana': 'MT',
  'nebraska': 'NE',
  'nevada': 'NV',
  'new hampshire': 'NH',
  'new jersey': 'NJ',
  'new mexico': 'NM',
  'new york': 'NY',
  'north carolina': 'NC',
  'north dakota': 'ND',
  'ohio': 'OH',
  'oklahoma': 'OK',
  'oregon': 'OR',
  'pennsylvania': 'PA',
  'rhode island': 'RI',
  'south carolina': 'SC',
  'south dakota': 'SD',
  'tennessee': 'TN',
  'texas': 'TX',
  'utah': 'UT',
  'vermont': 'VT',
  'virginia': 'VA',
  'washington': 'WA',
  'west virginia': 'WV',
  'wisconsin': 'WI',
  'wyoming': 'WY',
};

const _countryTokens = {
  'united states',
  'usa',
  'us',
  'u.s.',
  'u.s.a.',
  'united kingdom',
  'uk',
  'u.k.',
  'england',
  'scotland',
  'wales',
  'northern ireland',
};

/// Convert a US state name or existing abbreviation to a two-letter code.
String stateNameToCode(String value) {
  final raw = _normalizeToken(value);
  if (raw.isEmpty) return '';
  if (raw.length == 2 && RegExp(r'^[A-Za-z]+$').hasMatch(raw)) {
    return raw.toUpperCase();
  }
  final compact = raw.replaceAll('.', '');
  if (compact.length == 2 && RegExp(r'^[A-Za-z]+$').hasMatch(compact)) {
    return compact.toUpperCase();
  }
  return _usStateNameToCode[raw.toLowerCase()] ?? '';
}

String _normalizeToken(String value) => value.trim().replaceFirst(RegExp(r'\.$'), '');

bool _isUnitedStates(String country) {
  final normalized = country.trim().toLowerCase();
  return normalized == 'united states' ||
      normalized == 'usa' ||
      normalized == 'us' ||
      normalized == 'u.s.' ||
      normalized == 'u.s.a.';
}

bool _allowUsStateInLocation(String country) {
  final normalized = country.trim().toLowerCase();
  if (normalized.isEmpty || _isUnitedStates(country)) return true;
  return false;
}

/// Parse Metal Archives Location text into city and optional US state code.
({String city, String state}) parseMaLocation(
  String location, {
  String country = '',
}) {
  final trimmed = location.trim();
  if (trimmed.isEmpty) return (city: '', state: '');

  final parts = trimmed
      .split(',')
      .map(_normalizeToken)
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return (city: '', state: '');

  if (_allowUsStateInLocation(country)) {
    var stateIndex = -1;
    var stateCode = '';
    for (var index = parts.length - 1; index >= 0; index--) {
      final token = parts[index].toLowerCase();
      if (_countryTokens.contains(token)) continue;
      final code = stateNameToCode(parts[index]);
      if (code.isNotEmpty) {
        stateCode = code;
        stateIndex = index;
        break;
      }
    }

    if (stateCode.isNotEmpty) {
      final city =
          stateIndex > 0 ? parts.sublist(0, stateIndex).join(', ').trim() : '';
      return (city: city, state: stateCode);
    }

    if (parts.length == 1) {
      final code = stateNameToCode(parts[0]);
      if (code.isNotEmpty) return (city: '', state: code);
    }
  }

  return (city: parts[0], state: '');
}

/// Extract city and US state code from a MusicBrainz artist record.
({String city, String state}) parseMusicBrainzLocation(
  Map<String, dynamic> detail,
) {
  final countryCode = (detail['country']?.toString() ?? '').trim().toUpperCase();
  final beginArea = detail['begin-area'];
  final area = detail['area'];
  final beginMap =
      beginArea is Map ? Map<String, dynamic>.from(beginArea) : <String, dynamic>{};
  final areaMap =
      area is Map ? Map<String, dynamic>.from(area) : <String, dynamic>{};

  var city = (beginMap['name']?.toString() ?? '').trim();
  var state = '';

  final areaType = (areaMap['type']?.toString() ?? '').trim().toLowerCase();
  final areaName = (areaMap['name']?.toString() ?? '').trim();

  if (countryCode == 'US') {
    if (areaType == 'subdivision' && areaName.isNotEmpty) {
      state = stateNameToCode(areaName);
    } else if (city.isEmpty &&
        {'city', 'municipality', 'town'}.contains(areaType) &&
        areaName.isNotEmpty) {
      city = areaName;
    }
  } else if (city.isEmpty &&
      areaName.isNotEmpty &&
      {'city', 'municipality', 'town'}.contains(areaType)) {
    city = areaName;
  }

  return (city: city, state: state);
}
