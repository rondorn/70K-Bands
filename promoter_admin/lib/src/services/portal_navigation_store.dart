import 'dart:convert';

import 'package:promoter_admin/src/services/app_data_paths.dart';
import 'package:promoter_admin/src/services/durable_json_store.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

/// Last portal section per festival, stored in Application Support / iCloud
/// (same durable path as festival registry — survives app upgrades).
///
/// Data-entry tabs (Schedule Entry, Add Artist, Description form) are never
/// restored on launch — those always open on their list/view screens.
class PortalNavigation {
  const PortalNavigation({
    this.section = AppSection.settings,
    this.scheduleTab = ScheduleTab.view,
  });

  final AppSection section;
  final ScheduleTab scheduleTab;

  Map<String, dynamic> toJson() => {
        'section': section.name,
        'scheduleTab': scheduleTab.name,
      };

  static PortalNavigation? fromJson(Map<String, dynamic>? data) {
    if (data == null) return null;
    final section = _parseSection(data['section']);
    if (section == null) return null;
    return PortalNavigation(
      section: section,
      scheduleTab: listSafeScheduleTab(
        _parseScheduleTab(data['scheduleTab']) ?? ScheduleTab.view,
      ),
    );
  }

  /// Schedule Entry is intentionally not restored on launch.
  static ScheduleTab listSafeScheduleTab(ScheduleTab tab) =>
      tab == ScheduleTab.entry ? ScheduleTab.view : tab;

  static AppSection? _parseSection(Object? raw) {
    final name = raw?.toString().trim();
    if (name == null || name.isEmpty) return null;
    for (final section in AppSection.values) {
      if (section.name == name) return section;
    }
    return null;
  }

  static ScheduleTab? _parseScheduleTab(Object? raw) {
    final name = raw?.toString().trim();
    if (name == null || name.isEmpty) return null;
    for (final tab in ScheduleTab.values) {
      if (tab.name == name) return tab;
    }
    return null;
  }
}

class PortalNavigationStore {
  PortalNavigationStore({ConfigDocumentStore? documents})
      : _documents = documents ?? const ConfigDocumentStore();

  final ConfigDocumentStore _documents;

  Future<PortalNavigation?> loadForFestival(String festivalId) async {
    final id = festivalId.trim();
    if (id.isEmpty) return null;

    final raw = await _readDocument();
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final byFestival = decoded['byFestival'];
      if (byFestival is! Map) return null;
      final entry = byFestival[id];
      if (entry is Map<String, dynamic>) {
        return PortalNavigation.fromJson(entry);
      }
      if (entry is Map) {
        return PortalNavigation.fromJson(
          entry.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveForFestival(
    String festivalId,
    PortalNavigation navigation,
  ) async {
    final id = festivalId.trim();
    if (id.isEmpty) return;

    final existing = await _readDocument();
    final root = <String, dynamic>{};
    if (existing != null && existing.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(existing);
        if (decoded is Map<String, dynamic>) {
          root.addAll(decoded);
        }
      } catch (_) {
        // Replace corrupt file.
      }
    }

    final byFestival = <String, dynamic>{};
    final current = root['byFestival'];
    if (current is Map) {
      for (final entry in current.entries) {
        byFestival[entry.key.toString()] = entry.value;
      }
    }
    byFestival[id] = navigation.toJson();
    root['byFestival'] = byFestival;

    final contents =
        '${const JsonEncoder.withIndent('  ').convert(root)}\n';
    await _documents.writeDocument(
      iCloudRelativePath: AppDataPaths.portalNavigationRelativePath,
      localFile: AppDataPaths.localPortalNavigationFile,
      contents: contents,
    );
  }

  Future<String?> _readDocument() => _documents.readDocument(
        iCloudRelativePath: AppDataPaths.portalNavigationRelativePath,
        localFile: AppDataPaths.localPortalNavigationFile,
      );
}
