import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/platform_http.dart';
import 'package:promoter_admin/src/services/schedule_export/event_type_labeling.dart';
import 'package:promoter_admin/src/services/schedule_export/html_exporter.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_layout.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_validation.dart';

enum ScheduleExportColorMode { color, blackAndWhite }

/// Shared running-order export options (event types, layout, HTML bytes).
class RunningOrderExportConfig {
  RunningOrderExportConfig({
    required this.workspace,
    required this.events,
    Set<String>? selectedTypes,
    this.colorMode = ScheduleExportColorMode.color,
  }) : availableTypes = collectEventTypes(workspace, events),
       selectedTypes =
           selectedTypes ?? defaultSelectedTypes(collectEventTypes(workspace, events));

  final FestivalWorkspace workspace;
  final List<ScheduleEvent> events;
  final List<String> availableTypes;
  Set<String> selectedTypes;
  ScheduleExportColorMode colorMode;

  List<ScheduleEvent> get filteredEvents =>
      RunningOrderLayout.filterByTypes(events, selectedTypes);

  RunningOrderLayout get layout => RunningOrderLayout.build(filteredEvents, workspace);

  int get dayCount => filteredEvents.map((event) => event.day.trim()).toSet().length;

  static List<String> collectEventTypes(
    FestivalWorkspace workspace,
    List<ScheduleEvent> events,
  ) {
    final seen = <String>{};
    return [
      ...ScheduleValidation.withDefaultEventTypes(workspace.eventTypes),
      ...events.map((event) => event.type.trim()),
    ].where((type) => type.isNotEmpty && seen.add(type.toLowerCase())).toList();
  }

  static Set<String> defaultSelectedTypes(List<String> types) {
    final preferred = types
        .where((type) {
          final key = type.trim().toLowerCase();
          return key == 'show' || key == 'special event';
        })
        .toSet();
    return preferred.isEmpty ? types.toSet() : preferred;
  }

  Future<Uint8List> buildHtmlBytes() async {
    final built = layout;
    if (built.pages.isEmpty) {
      throw StateError('Select at least one event type with events.');
    }
    final logo = await fetchFestivalLogoBytes(workspace.festivalLogoUrl);
    final logoUrl = workspace.festivalLogoUrl.trim();
    return HtmlExporter.build(
      layout: built,
      festivalName: workspace.displayName,
      logoBytes: logo,
      logoMimeType: logoMimeType(logoUrl),
      useColor: colorMode == ScheduleExportColorMode.color,
      labeling: EventTypeLabeling.forSelection(selectedTypes),
    );
  }

  static Future<Uint8List?> fetchFestivalLogoBytes(String rawUrl) async {
    final url = normalizeDropboxUrl(rawUrl.trim());
    if (url.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': kSafariUserAgent})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (response.bodyBytes.isEmpty) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  static String logoMimeType(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.gif')) return 'image/gif';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }
}
