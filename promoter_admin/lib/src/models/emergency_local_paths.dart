/// Explicit local file/folder paths for Local File Mode.
///
/// Each path is chosen by the operator — no layout assumptions.
class EmergencyLocalPaths {
  const EmergencyLocalPaths({
    this.artistsCsv = '',
    this.scheduleCsv = '',
    this.descriptionMapCsv = '',
    this.descriptionsDir = '',
    this.alertsDir = '',
  });

  final String artistsCsv;
  final String scheduleCsv;
  final String descriptionMapCsv;
  final String descriptionsDir;
  final String alertsDir;

  bool get hasAnyPath =>
      artistsCsv.trim().isNotEmpty ||
      scheduleCsv.trim().isNotEmpty ||
      descriptionMapCsv.trim().isNotEmpty ||
      descriptionsDir.trim().isNotEmpty ||
      alertsDir.trim().isNotEmpty;

  EmergencyLocalPaths copyWith({
    String? artistsCsv,
    String? scheduleCsv,
    String? descriptionMapCsv,
    String? descriptionsDir,
    String? alertsDir,
  }) {
    return EmergencyLocalPaths(
      artistsCsv: artistsCsv ?? this.artistsCsv,
      scheduleCsv: scheduleCsv ?? this.scheduleCsv,
      descriptionMapCsv: descriptionMapCsv ?? this.descriptionMapCsv,
      descriptionsDir: descriptionsDir ?? this.descriptionsDir,
      alertsDir: alertsDir ?? this.alertsDir,
    );
  }

  Map<String, String> toPrefs() => {
        'artistsCsv': artistsCsv,
        'scheduleCsv': scheduleCsv,
        'descriptionMapCsv': descriptionMapCsv,
        'descriptionsDir': descriptionsDir,
        'alertsDir': alertsDir,
      };

  static EmergencyLocalPaths fromPrefs(Map<String, String> map) {
    return EmergencyLocalPaths(
      artistsCsv: map['artistsCsv'] ?? '',
      scheduleCsv: map['scheduleCsv'] ?? '',
      descriptionMapCsv: map['descriptionMapCsv'] ?? '',
      descriptionsDir: map['descriptionsDir'] ?? '',
      alertsDir: map['alertsDir'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EmergencyLocalPaths &&
        other.artistsCsv == artistsCsv &&
        other.scheduleCsv == scheduleCsv &&
        other.descriptionMapCsv == descriptionMapCsv &&
        other.descriptionsDir == descriptionsDir &&
        other.alertsDir == alertsDir;
  }

  @override
  int get hashCode => Object.hash(
        artistsCsv,
        scheduleCsv,
        descriptionMapCsv,
        descriptionsDir,
        alertsDir,
      );
}
