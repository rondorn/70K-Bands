/// Local workspace config for one festival (pointers from app maintainer).
class FestivalWorkspace {
  const FestivalWorkspace({
    this.id = '',
    this.festivalName = '',
    this.testingPointerUrl = '',
    this.productionPointerUrl = '',
    this.eventYear = '',
    this.bandListUrl = '',
    this.scheduleUrl = '',
    this.descriptionMapUrl = '',
    this.venues = const [],
    this.dates = const [],
    this.days = const [],
    this.eventTypes = const [],
    this.canEditBands = true,
    this.canEditSchedule = true,
    this.canEditDescriptions = true,
    this.canEditPointers = false,
    this.useCityStateField = false,
  });

  /// Stable id within the local multi-festival registry.
  final String id;
  final String festivalName;
  final String testingPointerUrl;
  final String productionPointerUrl;
  final String eventYear;

  /// Derived from testing pointer Current::artistUrl (not edited by hand).
  final String bandListUrl;
  final String scheduleUrl;
  final String descriptionMapUrl;

  /// Schedule vocabulary (venues/types from production pointer load).
  final List<String> venues;
  final List<String> dates;
  final List<String> days;
  final List<String> eventTypes;

  /// Write access to testing data files (Dropbox probe + optional override).
  final bool canEditBands;
  final bool canEditSchedule;
  final bool canEditDescriptions;

  /// Write access to the testing pointer (year-roll / Add new year).
  final bool canEditPointers;

  /// When true, band form/CSV include city and state columns.
  final bool useCityStateField;

  bool get hasTestingPointer => testingPointerUrl.trim().isNotEmpty;

  /// True once the festival has a name and testing pointer (ready for normal use).
  bool get isConfigured =>
      festivalName.trim().isNotEmpty && testingPointerUrl.trim().isNotEmpty;

  bool get hasAnyEditAccess =>
      canEditBands || canEditSchedule || canEditDescriptions;

  String get displayName {
    final n = festivalName.trim();
    return n.isEmpty ? (id.isEmpty ? 'Untitled Festival' : id) : n;
  }

  FestivalWorkspace copyWith({
    String? id,
    String? festivalName,
    String? testingPointerUrl,
    String? productionPointerUrl,
    String? eventYear,
    String? bandListUrl,
    String? scheduleUrl,
    String? descriptionMapUrl,
    List<String>? venues,
    List<String>? dates,
    List<String>? days,
    List<String>? eventTypes,
    bool? canEditBands,
    bool? canEditSchedule,
    bool? canEditDescriptions,
    bool? canEditPointers,
    bool? useCityStateField,
  }) {
    return FestivalWorkspace(
      id: id ?? this.id,
      festivalName: festivalName ?? this.festivalName,
      testingPointerUrl: testingPointerUrl ?? this.testingPointerUrl,
      productionPointerUrl: productionPointerUrl ?? this.productionPointerUrl,
      eventYear: eventYear ?? this.eventYear,
      bandListUrl: bandListUrl ?? this.bandListUrl,
      scheduleUrl: scheduleUrl ?? this.scheduleUrl,
      descriptionMapUrl: descriptionMapUrl ?? this.descriptionMapUrl,
      venues: venues ?? this.venues,
      dates: dates ?? this.dates,
      days: days ?? this.days,
      eventTypes: eventTypes ?? this.eventTypes,
      canEditBands: canEditBands ?? this.canEditBands,
      canEditSchedule: canEditSchedule ?? this.canEditSchedule,
      canEditDescriptions: canEditDescriptions ?? this.canEditDescriptions,
      canEditPointers: canEditPointers ?? this.canEditPointers,
      useCityStateField: useCityStateField ?? this.useCityStateField,
    );
  }

  Map<String, String> toPrefs() => {
        'id': id,
        'festivalName': festivalName,
        'testingPointerUrl': testingPointerUrl,
        'productionPointerUrl': productionPointerUrl,
        'eventYear': eventYear,
        'bandListUrl': bandListUrl,
        'scheduleUrl': scheduleUrl,
        'descriptionMapUrl': descriptionMapUrl,
        'venues': venues.join('\n'),
        'dates': dates.join('\n'),
        'days': days.join('\n'),
        'eventTypes': eventTypes.join('\n'),
        'canEditBands': canEditBands ? '1' : '0',
        'canEditSchedule': canEditSchedule ? '1' : '0',
        'canEditDescriptions': canEditDescriptions ? '1' : '0',
        'canEditPointers': canEditPointers ? '1' : '0',
        'useCityStateField': useCityStateField ? '1' : '0',
      };

  static bool _boolPref(Map<String, String> map, String key, {bool fallback = true}) {
    final raw = map[key];
    if (raw == null) return fallback;
    final v = raw.trim().toLowerCase();
    if (v == '1' || v == 'true' || v == 'yes') return true;
    if (v == '0' || v == 'false' || v == 'no') return false;
    return fallback;
  }

  static FestivalWorkspace fromPrefs(Map<String, String> map) {
    List<String> list(String key) => (map[key] ?? '')
        .split('\n')
        .map((s) => s.trimRight())
        .where((s) => s.isNotEmpty || s == ' ')
        .toList();

    return FestivalWorkspace(
      id: map['id'] ?? '',
      festivalName: map['festivalName'] ?? '',
      testingPointerUrl: map['testingPointerUrl'] ?? '',
      productionPointerUrl: map['productionPointerUrl'] ?? '',
      eventYear: map['eventYear'] ?? '',
      bandListUrl: map['bandListUrl'] ?? '',
      scheduleUrl: map['scheduleUrl'] ?? '',
      descriptionMapUrl: map['descriptionMapUrl'] ?? '',
      venues: list('venues'),
      dates: list('dates'),
      days: list('days'),
      eventTypes: list('eventTypes'),
      canEditBands: _boolPref(map, 'canEditBands'),
      canEditSchedule: _boolPref(map, 'canEditSchedule'),
      canEditDescriptions: _boolPref(map, 'canEditDescriptions'),
      canEditPointers: _boolPref(map, 'canEditPointers', fallback: false),
      useCityStateField: _boolPref(map, 'useCityStateField', fallback: false),
    );
  }
}

class BandRow {
  BandRow(this.fields);

  final Map<String, String> fields;

  String get name => (fields['bandName'] ?? '').trim();
  String get genre => (fields['genre'] ?? '').trim();
  String get country => (fields['country'] ?? '').trim();
  String get noteworthy => (fields['noteworthy'] ?? '').trim();
}
