import 'dart:convert';

import 'package:promoter_admin/src/models/festival_workspace.dart';

/// Portable festival admin configuration (share as a Dropbox link).
///
/// Not a pointer file — this packages workspace settings so a recruited admin
/// can paste one URL and be ready to work.
class FestivalSetupPackage {
  const FestivalSetupPackage({
    required this.festivalName,
    required this.testingPointerUrl,
    this.productionPointerUrl = '',
    this.festivalLogoUrl = '',
    this.eventYear = '',
    this.venues = const [],
    this.dates = const [],
    this.days = const [],
    this.dateRolloverTime = '8:00',
    this.eventTypes = const [],
    this.useCityStateField = false,
    this.reportsFolderUrl = '',
    this.alertFolderUrl = '',
    this.includesReports = false,
    this.includesAlerts = false,
    this.version = currentVersion,
  });

  static const formatId = 'omf-festival-setup';
  static const currentVersion = 1;

  final int version;
  final String festivalName;
  final String testingPointerUrl;
  final String productionPointerUrl;
  final String festivalLogoUrl;
  final String eventYear;
  final List<String> venues;
  final List<String> dates;
  final List<String> days;
  final String dateRolloverTime;
  final List<String> eventTypes;
  final bool useCityStateField;
  final String reportsFolderUrl;
  final String alertFolderUrl;
  final bool includesReports;
  final bool includesAlerts;

  /// Build an export package from the active workspace.
  factory FestivalSetupPackage.fromWorkspace(
    FestivalWorkspace workspace, {
    required bool includeReports,
    required bool includeAlerts,
  }) {
    return FestivalSetupPackage(
      festivalName: workspace.festivalName.trim(),
      testingPointerUrl: workspace.testingPointerUrl.trim(),
      productionPointerUrl: workspace.productionPointerUrl.trim(),
      festivalLogoUrl: workspace.festivalLogoUrl.trim(),
      eventYear: workspace.eventYear.trim(),
      venues: List<String>.from(workspace.venues),
      dates: List<String>.from(workspace.dates),
      days: List<String>.from(workspace.days),
      dateRolloverTime: workspace.dateRolloverTime.trim().isEmpty
          ? '8:00'
          : workspace.dateRolloverTime.trim(),
      eventTypes: List<String>.from(workspace.eventTypes),
      useCityStateField: workspace.useCityStateField,
      includesReports: includeReports,
      includesAlerts: includeAlerts,
      reportsFolderUrl:
          includeReports ? workspace.reportsFolderUrl.trim() : '',
      alertFolderUrl: includeAlerts ? workspace.alertFolderUrl.trim() : '',
    );
  }

  FestivalWorkspace toWorkspace({String id = ''}) {
    return FestivalWorkspace(
      id: id,
      festivalName: festivalName.trim(),
      testingPointerUrl: testingPointerUrl.trim(),
      productionPointerUrl: productionPointerUrl.trim(),
      festivalLogoUrl: festivalLogoUrl.trim(),
      eventYear: eventYear.trim(),
      venues: List<String>.from(venues),
      dates: List<String>.from(dates),
      days: List<String>.from(days),
      dateRolloverTime:
          dateRolloverTime.trim().isEmpty ? '8:00' : dateRolloverTime.trim(),
      eventTypes: List<String>.from(eventTypes),
      useCityStateField: useCityStateField,
      reportsFolderUrl: includesReports ? reportsFolderUrl.trim() : '',
      alertFolderUrl: includesAlerts ? alertFolderUrl.trim() : '',
    );
  }

  Map<String, Object?> toJson() => {
        'format': formatId,
        'version': version,
        'festivalName': festivalName,
        'testingPointerUrl': testingPointerUrl,
        'productionPointerUrl': productionPointerUrl,
        'festivalLogoUrl': festivalLogoUrl,
        'eventYear': eventYear,
        'venues': venues,
        'dates': dates,
        'days': days,
        'dateRolloverTime': dateRolloverTime,
        'eventTypes': eventTypes,
        'useCityStateField': useCityStateField,
        'includesReports': includesReports,
        'includesAlerts': includesAlerts,
        if (includesReports) 'reportsFolderUrl': reportsFolderUrl,
        if (includesAlerts) 'alertFolderUrl': alertFolderUrl,
      };

  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJson())}\n';
  }

  static FestivalSetupPackage parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Setup file is empty.');
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      throw const FormatException(
        'This does not look like a festival setup file. '
        'Ask your festival contact for a setup link from Export festival setup.',
      );
    }
    if (decoded is! Map) {
      throw const FormatException('Invalid festival setup file.');
    }
    final map = Map<String, dynamic>.from(decoded);
    final format = (map['format'] as String?)?.trim() ?? '';
    if (format.isNotEmpty && format != formatId) {
      throw FormatException('Unsupported setup format “$format".');
    }
    final version = map['version'] is int
        ? map['version'] as int
        : int.tryParse('${map['version'] ?? 1}') ?? 1;
    if (version > currentVersion) {
      throw FormatException(
        'This setup file is version $version, which is newer than this app '
        'supports. Update Open Metal Fest Admin and try again.',
      );
    }

    final name = _string(map, 'festivalName');
    final testing = _string(map, 'testingPointerUrl');
    if (name.isEmpty) {
      throw const FormatException('Setup file is missing the festival name.');
    }
    if (testing.isEmpty) {
      throw const FormatException('Setup file is missing the Testing link.');
    }

    final reportsUrl = _string(map, 'reportsFolderUrl');
    final alertUrl = _string(map, 'alertFolderUrl');
    // Legacy combined flag: treat as both when the separate keys are absent.
    final legacyBoth = map['includesReportsAndAlerts'] == true;
    final includesReports = map.containsKey('includesReports')
        ? map['includesReports'] == true
        : (legacyBoth || reportsUrl.isNotEmpty);
    final includesAlerts = map.containsKey('includesAlerts')
        ? map['includesAlerts'] == true
        : (legacyBoth || alertUrl.isNotEmpty);

    return FestivalSetupPackage(
      version: version,
      festivalName: name,
      testingPointerUrl: testing,
      productionPointerUrl: _string(map, 'productionPointerUrl'),
      festivalLogoUrl: _string(map, 'festivalLogoUrl'),
      eventYear: _string(map, 'eventYear'),
      venues: _stringList(map, 'venues'),
      dates: _stringList(map, 'dates'),
      days: _stringList(map, 'days'),
      dateRolloverTime: () {
        final v = _string(map, 'dateRolloverTime');
        return v.isEmpty ? '8:00' : v;
      }(),
      eventTypes: _stringList(map, 'eventTypes'),
      useCityStateField: map['useCityStateField'] == true,
      includesReports: includesReports,
      includesAlerts: includesAlerts,
      reportsFolderUrl: reportsUrl,
      alertFolderUrl: alertUrl,
    );
  }

  static String _string(Map<String, dynamic> map, String key) =>
      (map[key] ?? '').toString().trim();

  static List<String> _stringList(Map<String, dynamic> map, String key) {
    final raw = map[key];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trimRight())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      return raw
          .split('\n')
          .map((s) => s.trimRight())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Suggested download / share file name.
  static String suggestedFileName(String festivalName) {
    final slug = festivalName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'festival' : slug;
    return '$base-admin-setup.json';
  }
}
