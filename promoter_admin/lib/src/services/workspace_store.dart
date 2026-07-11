import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/app_data_paths.dart';
import 'package:promoter_admin/src/services/durable_json_store.dart';

/// Multi-festival registry persisted under Application Support (survives
/// reinstall / bundle-id changes when the durable path is used).
class FestivalRegistry {
  const FestivalRegistry({
    required this.activeFestivalId,
    required this.festivals,
  });

  final String activeFestivalId;
  final Map<String, FestivalWorkspace> festivals;

  FestivalWorkspace get active {
    if (festivals.containsKey(activeFestivalId)) {
      return festivals[activeFestivalId]!;
    }
    if (festivals.isNotEmpty) return festivals.values.first;
    return FestivalWorkspace(id: activeFestivalId.isEmpty ? 'festival-1' : activeFestivalId);
  }

  List<({String id, String name})> get choices {
    final items = festivals.entries
        .map(
          (e) => (
            id: e.key,
            name: e.value.festivalName.trim().isEmpty
                ? e.key
                : e.value.festivalName.trim(),
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  FestivalRegistry copyWith({
    String? activeFestivalId,
    Map<String, FestivalWorkspace>? festivals,
  }) {
    return FestivalRegistry(
      activeFestivalId: activeFestivalId ?? this.activeFestivalId,
      festivals: festivals ?? this.festivals,
    );
  }

  FestivalRegistry upsertActive(FestivalWorkspace workspace) {
    final id = workspace.id.trim().isEmpty ? activeFestivalId : workspace.id;
    final updated = Map<String, FestivalWorkspace>.from(festivals)
      ..[id] = workspace.copyWith(id: id);
    return FestivalRegistry(activeFestivalId: id, festivals: updated);
  }
}

class WorkspaceStore {
  WorkspaceStore({ConfigDocumentStore? documents})
      : _documents = documents ?? const ConfigDocumentStore();

  final ConfigDocumentStore _documents;

  static const _registryKey = 'festivalRegistryV1';
  static const _legacyKeys = [
    'festivalName',
    'testingPointerUrl',
    'productionPointerUrl',
    'eventYear',
    'bandListUrl',
    'scheduleUrl',
    'descriptionMapUrl',
    'venues',
    'dates',
    'days',
    'eventTypes',
  ];

  Future<FestivalRegistry> loadRegistry() async {
    await _documents.migrateLocalConfigToICloudIfNeeded();

    final raw = await _documents.readDocument(
      iCloudRelativePath: AppDataPaths.registryRelativePath,
      localFile: AppDataPaths.localFestivalRegistryFile,
    );
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        return _fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Fall through.
      }
    }

    final migrated = await _migrateFromSharedPreferences();
    if (migrated != null) {
      await saveRegistry(migrated);
      return migrated;
    }

    final blank = FestivalWorkspace(id: 'festival-1');
    return FestivalRegistry(
      activeFestivalId: 'festival-1',
      festivals: {'festival-1': blank},
    );
  }

  /// Convenience: active festival only (migrates registry if needed).
  Future<FestivalWorkspace> load() async {
    final registry = await loadRegistry();
    return registry.active;
  }

  Future<void> saveRegistry(FestivalRegistry registry) async {
    final contents =
        '${const JsonEncoder.withIndent('  ').convert(_toJson(registry))}\n';
    await _documents.writeDocument(
      iCloudRelativePath: AppDataPaths.registryRelativePath,
      localFile: AppDataPaths.localFestivalRegistryFile,
      contents: contents,
    );
  }

  Future<void> save(FestivalWorkspace workspace) async {
    final registry = await loadRegistry();
    await saveRegistry(registry.upsertActive(workspace));
  }

  Future<FestivalRegistry> switchActive(String festivalId) async {
    final registry = await loadRegistry();
    if (!registry.festivals.containsKey(festivalId)) {
      throw StateError('Unknown festival id: $festivalId');
    }
    final next = registry.copyWith(activeFestivalId: festivalId);
    await saveRegistry(next);
    return next;
  }

  Future<FestivalRegistry> addFestival({
    String name = '',
    FestivalWorkspace? seed,
  }) async {
    final registry = await loadRegistry();
    final id = _allocateId(registry.festivals.keys.toSet());
    final resolvedName = name.trim().isNotEmpty
        ? name.trim()
        : (seed?.festivalName.trim().isNotEmpty == true
            ? seed!.festivalName.trim()
            : 'New Festival');
    final workspace = (seed ?? const FestivalWorkspace()).copyWith(
      id: id,
      festivalName: resolvedName,
    );
    final festivals = Map<String, FestivalWorkspace>.from(registry.festivals)
      ..[id] = workspace;
    final next = FestivalRegistry(activeFestivalId: id, festivals: festivals);
    await saveRegistry(next);
    return next;
  }

  Future<FestivalRegistry> deleteFestival(String festivalId) async {
    final registry = await loadRegistry();
    if (registry.festivals.length <= 1) {
      throw StateError('Cannot delete the only festival configuration.');
    }
    if (!registry.festivals.containsKey(festivalId)) {
      return registry;
    }
    final festivals = Map<String, FestivalWorkspace>.from(registry.festivals)
      ..remove(festivalId);
    final active = registry.activeFestivalId == festivalId
        ? festivals.keys.first
        : registry.activeFestivalId;
    final next = FestivalRegistry(activeFestivalId: active, festivals: festivals);
    await saveRegistry(next);
    return next;
  }

  Future<FestivalRegistry?> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_registryKey);
      if (raw != null && raw.trim().isNotEmpty) {
        try {
          return _fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {
          // Fall through to legacy keys.
        }
      }

      final legacy = <String, String>{};
      for (final key in _legacyKeys) {
        legacy[key] = prefs.getString(key) ?? '';
      }
      final hasLegacy = legacy.values.any((v) => v.trim().isNotEmpty);
      if (hasLegacy) {
        final workspace =
            FestivalWorkspace.fromPrefs(legacy).copyWith(id: 'festival-1');
        return FestivalRegistry(
          activeFestivalId: 'festival-1',
          festivals: {'festival-1': workspace},
        );
      }
    } catch (_) {
      // SharedPreferences unavailable — start blank.
    }
    return null;
  }

  String _allocateId(Set<String> existing) {
    var index = existing.length + 1;
    var candidate = 'festival-$index';
    while (existing.contains(candidate)) {
      index++;
      candidate = 'festival-$index';
    }
    return candidate;
  }

  Map<String, dynamic> _toJson(FestivalRegistry registry) {
    return {
      'activeFestivalId': registry.activeFestivalId,
      'festivals': {
        for (final e in registry.festivals.entries) e.key: e.value.toPrefs(),
      },
    };
  }

  FestivalRegistry _fromJson(Map<String, dynamic> data) {
    final festivalsRaw = data['festivals'];
    final festivals = <String, FestivalWorkspace>{};
    if (festivalsRaw is Map) {
      for (final e in festivalsRaw.entries) {
        final id = e.key.toString();
        final value = e.value;
        if (value is Map) {
          final map = <String, String>{
            for (final entry in value.entries)
              entry.key.toString(): entry.value?.toString() ?? '',
          };
          festivals[id] = FestivalWorkspace.fromPrefs(map).copyWith(id: id);
        }
      }
    }
    if (festivals.isEmpty) {
      festivals['festival-1'] = const FestivalWorkspace(id: 'festival-1');
    }
    var active = (data['activeFestivalId'] ?? '').toString();
    if (!festivals.containsKey(active)) {
      active = festivals.keys.first;
    }
    return FestivalRegistry(activeFestivalId: active, festivals: festivals);
  }
}
