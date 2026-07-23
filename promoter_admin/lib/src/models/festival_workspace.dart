/// Local workspace config for one festival (pointers from app maintainer).
class FestivalWorkspace {
  const FestivalWorkspace({
    this.id = '',
    this.festivalName = '',
    this.testingPointerUrl = '',
    this.productionPointerUrl = '',
    this.alertFolderUrl = '',
    this.festivalLogoUrl = '',
    this.eventYear = '',
    this.dataSourceYearOverride = '',
    this.bandListUrl = '',
    this.scheduleUrl = '',
    this.descriptionMapUrl = '',
    this.venues = const [],
    this.dates = const [],
    this.days = const [],
    this.dateRolloverTime = '8:00',
    this.eventTypes = const [],
    this.canEditBands = true,
    this.canEditSchedule = true,
    this.canEditDescriptions = true,
    this.canEditPointers = false,
    this.canEditAlerts = false,
    this.allowCustomAlerts = false,
    this.useCityStateField = false,
    this.artistFilesFolderPath = '',
    this.scheduleFilesFolderPath = '',
    this.descriptionFilesFolderPath = '',
    this.alertFilesFolderPath = '',
    this.masterFilesFolderPath = '',
    this.ownsArtistFilesFolder = false,
    this.ownsScheduleFilesFolder = false,
    this.ownsDescriptionFilesFolder = false,
    this.ownsAlertFilesFolder = false,
    this.ownsMasterFilesFolder = false,
  });

  /// Stable id within the local multi-festival registry.
  final String id;
  final String festivalName;
  final String testingPointerUrl;
  final String productionPointerUrl;

  /// Dropbox folder share link for band-add announcement `.pending` files.
  /// Pasted manually in Settings (not created by festival bootstrap).
  final String alertFolderUrl;

  /// Optional image URL (typically a Dropbox share link) used only in
  /// PDF/HTML running-order exports, where it replaces the festival name.
  final String festivalLogoUrl;
  final String eventYear;

  /// When non-empty, Artists / Schedule / Descriptions load from this archived
  /// pointer year section instead of Testing Current (local demo/test override;
  /// does not rewrite Dropbox pointer files).
  final String dataSourceYearOverride;

  /// Derived from testing pointer Current::artistUrl (not edited by hand).
  final String bandListUrl;
  final String scheduleUrl;
  final String descriptionMapUrl;

  /// Schedule vocabulary (venues/types from production pointer load).
  final List<String> venues;
  final List<String> dates;
  final List<String> days;

  /// Start times from midnight until this clock time use the *next* date
  /// in the ordered Dates list (overnight on the same festival Day).
  final String dateRolloverTime;

  final List<String> eventTypes;

  /// Write access to testing data files (Dropbox probe + optional override).
  final bool canEditBands;
  final bool canEditSchedule;
  final bool canEditDescriptions;

  /// Write access to the testing pointer (year-roll / Add new year).
  final bool canEditPointers;

  /// Write access to [alertFolderUrl] (Dropbox probe on save / refresh).
  final bool canEditAlerts;

  /// From Production pointer `Current::allowCustomAlerts` (festival-wide grant).
  final bool allowCustomAlerts;

  /// When true, band form/CSV include city and state columns.
  final bool useCityStateField;

  /// Dropbox API paths for split access-control folders (new festivals).
  final String artistFilesFolderPath;
  final String scheduleFilesFolderPath;
  final String descriptionFilesFolderPath;

  /// Dropbox API path for [alertFolderUrl] (resolved from the folder share link).
  final String alertFilesFolderPath;

  /// Dropbox API path for testing/production pointer files (`/{Name}_MasterFiles`).
  final String masterFilesFolderPath;

  /// Whether the signed-in Dropbox user owns each folder (can grant access).
  final bool ownsArtistFilesFolder;
  final bool ownsScheduleFilesFolder;
  final bool ownsDescriptionFilesFolder;
  final bool ownsAlertFilesFolder;
  final bool ownsMasterFilesFolder;

  bool get hasSplitAccessFolders =>
      artistFilesFolderPath.trim().isNotEmpty ||
      scheduleFilesFolderPath.trim().isNotEmpty ||
      descriptionFilesFolderPath.trim().isNotEmpty ||
      alertFilesFolderPath.trim().isNotEmpty ||
      masterFilesFolderPath.trim().isNotEmpty;

  bool get canManageAnyFolderAccess =>
      ownsArtistFilesFolder ||
      ownsScheduleFilesFolder ||
      ownsDescriptionFilesFolder ||
      ownsAlertFilesFolder ||
      ownsMasterFilesFolder;

  bool get hasTestingPointer => testingPointerUrl.trim().isNotEmpty;

  /// True once the festival has a name and testing pointer (ready for normal use).
  bool get isConfigured =>
      festivalName.trim().isNotEmpty && testingPointerUrl.trim().isNotEmpty;

  bool get hasAnyEditAccess =>
      canEditBands || canEditSchedule || canEditDescriptions;

  /// True when Artists / Schedule / Descriptions are pointed at an archived year.
  bool get hasDataSourceYearOverride => dataSourceYearOverride.trim().isNotEmpty;

  /// Show the Alerts (custom push) section when an alert folder is configured and
  /// either:
  /// - Production pointer has `Current::allowCustomAlerts::1`, or
  /// - this Dropbox user can write the testing pointer ([canEditPointers]).
  ///
  /// Sending still requires [canEditAlerts] (alert folder write access).
  bool get customAlertsUiEnabled =>
      alertFolderUrl.trim().isNotEmpty &&
      (allowCustomAlerts || canEditPointers);

  String get displayName {
    final n = festivalName.trim();
    return n.isEmpty ? (id.isEmpty ? 'Untitled Festival' : id) : n;
  }

  FestivalWorkspace copyWith({
    String? id,
    String? festivalName,
    String? testingPointerUrl,
    String? productionPointerUrl,
    String? alertFolderUrl,
    String? festivalLogoUrl,
    String? eventYear,
    String? dataSourceYearOverride,
    bool clearDataSourceYearOverride = false,
    String? bandListUrl,
    String? scheduleUrl,
    String? descriptionMapUrl,
    List<String>? venues,
    List<String>? dates,
    List<String>? days,
    String? dateRolloverTime,
    List<String>? eventTypes,
    bool? canEditBands,
    bool? canEditSchedule,
    bool? canEditDescriptions,
    bool? canEditPointers,
    bool? canEditAlerts,
    bool? allowCustomAlerts,
    bool? useCityStateField,
    String? artistFilesFolderPath,
    String? scheduleFilesFolderPath,
    String? descriptionFilesFolderPath,
    String? alertFilesFolderPath,
    String? masterFilesFolderPath,
    bool? ownsArtistFilesFolder,
    bool? ownsScheduleFilesFolder,
    bool? ownsDescriptionFilesFolder,
    bool? ownsAlertFilesFolder,
    bool? ownsMasterFilesFolder,
  }) {
    return FestivalWorkspace(
      id: id ?? this.id,
      festivalName: festivalName ?? this.festivalName,
      testingPointerUrl: testingPointerUrl ?? this.testingPointerUrl,
      productionPointerUrl: productionPointerUrl ?? this.productionPointerUrl,
      alertFolderUrl: alertFolderUrl ?? this.alertFolderUrl,
      festivalLogoUrl: festivalLogoUrl ?? this.festivalLogoUrl,
      eventYear: eventYear ?? this.eventYear,
      dataSourceYearOverride: clearDataSourceYearOverride
          ? ''
          : (dataSourceYearOverride ?? this.dataSourceYearOverride),
      bandListUrl: bandListUrl ?? this.bandListUrl,
      scheduleUrl: scheduleUrl ?? this.scheduleUrl,
      descriptionMapUrl: descriptionMapUrl ?? this.descriptionMapUrl,
      venues: venues ?? this.venues,
      dates: dates ?? this.dates,
      days: days ?? this.days,
      dateRolloverTime: dateRolloverTime ?? this.dateRolloverTime,
      eventTypes: eventTypes ?? this.eventTypes,
      canEditBands: canEditBands ?? this.canEditBands,
      canEditSchedule: canEditSchedule ?? this.canEditSchedule,
      canEditDescriptions: canEditDescriptions ?? this.canEditDescriptions,
      canEditPointers: canEditPointers ?? this.canEditPointers,
      canEditAlerts: canEditAlerts ?? this.canEditAlerts,
      allowCustomAlerts: allowCustomAlerts ?? this.allowCustomAlerts,
      useCityStateField: useCityStateField ?? this.useCityStateField,
      artistFilesFolderPath:
          artistFilesFolderPath ?? this.artistFilesFolderPath,
      scheduleFilesFolderPath:
          scheduleFilesFolderPath ?? this.scheduleFilesFolderPath,
      descriptionFilesFolderPath:
          descriptionFilesFolderPath ?? this.descriptionFilesFolderPath,
      alertFilesFolderPath: alertFilesFolderPath ?? this.alertFilesFolderPath,
      masterFilesFolderPath:
          masterFilesFolderPath ?? this.masterFilesFolderPath,
      ownsArtistFilesFolder:
          ownsArtistFilesFolder ?? this.ownsArtistFilesFolder,
      ownsScheduleFilesFolder:
          ownsScheduleFilesFolder ?? this.ownsScheduleFilesFolder,
      ownsDescriptionFilesFolder:
          ownsDescriptionFilesFolder ?? this.ownsDescriptionFilesFolder,
      ownsAlertFilesFolder: ownsAlertFilesFolder ?? this.ownsAlertFilesFolder,
      ownsMasterFilesFolder:
          ownsMasterFilesFolder ?? this.ownsMasterFilesFolder,
    );
  }

  Map<String, String> toPrefs() => {
    'id': id,
    'festivalName': festivalName,
    'testingPointerUrl': testingPointerUrl,
    'productionPointerUrl': productionPointerUrl,
    'alertFolderUrl': alertFolderUrl,
    'festivalLogoUrl': festivalLogoUrl,
    'eventYear': eventYear,
    'dataSourceYearOverride': dataSourceYearOverride,
    'bandListUrl': bandListUrl,
    'scheduleUrl': scheduleUrl,
    'descriptionMapUrl': descriptionMapUrl,
    'venues': venues.join('\n'),
    'dates': dates.join('\n'),
    'days': days.join('\n'),
    'dateRolloverTime': dateRolloverTime,
    'eventTypes': eventTypes.join('\n'),
    'canEditBands': canEditBands ? '1' : '0',
    'canEditSchedule': canEditSchedule ? '1' : '0',
    'canEditDescriptions': canEditDescriptions ? '1' : '0',
    'canEditPointers': canEditPointers ? '1' : '0',
    'canEditAlerts': canEditAlerts ? '1' : '0',
    'allowCustomAlerts': allowCustomAlerts ? '1' : '0',
    'useCityStateField': useCityStateField ? '1' : '0',
    'artistFilesFolderPath': artistFilesFolderPath,
    'scheduleFilesFolderPath': scheduleFilesFolderPath,
    'descriptionFilesFolderPath': descriptionFilesFolderPath,
    'alertFilesFolderPath': alertFilesFolderPath,
    'masterFilesFolderPath': masterFilesFolderPath,
  };

  static bool _boolPref(
    Map<String, String> map,
    String key, {
    bool fallback = true,
  }) {
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
      alertFolderUrl: map['alertFolderUrl'] ?? '',
      festivalLogoUrl: (map['festivalLogoUrl'] ?? '').trim().isNotEmpty
          ? (map['festivalLogoUrl'] ?? '').trim()
          : (map['festivalLogoPath'] ?? '').trim(),
      eventYear: map['eventYear'] ?? '',
      dataSourceYearOverride: map['dataSourceYearOverride'] ?? '',
      bandListUrl: map['bandListUrl'] ?? '',
      scheduleUrl: map['scheduleUrl'] ?? '',
      descriptionMapUrl: map['descriptionMapUrl'] ?? '',
      venues: list('venues'),
      dates: list('dates'),
      days: list('days'),
      dateRolloverTime: (map['dateRolloverTime'] ?? '8:00').trim().isEmpty
          ? '8:00'
          : (map['dateRolloverTime'] ?? '8:00').trim(),
      eventTypes: list('eventTypes'),
      canEditBands: _boolPref(map, 'canEditBands'),
      canEditSchedule: _boolPref(map, 'canEditSchedule'),
      canEditDescriptions: _boolPref(map, 'canEditDescriptions'),
      canEditPointers: _boolPref(map, 'canEditPointers', fallback: false),
      canEditAlerts: _boolPref(map, 'canEditAlerts', fallback: false),
      allowCustomAlerts: _boolPref(map, 'allowCustomAlerts', fallback: false),
      useCityStateField: _boolPref(map, 'useCityStateField', fallback: false),
      artistFilesFolderPath: map['artistFilesFolderPath'] ?? '',
      scheduleFilesFolderPath: map['scheduleFilesFolderPath'] ?? '',
      descriptionFilesFolderPath: map['descriptionFilesFolderPath'] ?? '',
      alertFilesFolderPath: map['alertFilesFolderPath'] ?? '',
      masterFilesFolderPath: map['masterFilesFolderPath'] ?? '',
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
