import 'dart:convert';
import 'dart:io';

import 'package:icloud_storage_plus/icloud_storage.dart';
import 'package:promoter_admin/src/services/app_data_paths.dart';

/// Read/write small UTF-8 config documents.
///
/// When iCloud Documents is configured on the device, prefers the ubiquity
/// container and keeps a local mirror. When iCloud is not configured (no
/// account / no container), reads and writes local Application Support only.
/// Network outages do not change that decision.
class ConfigDocumentStore {
  const ConfigDocumentStore();

  Future<String?> readDocument({
    required String iCloudRelativePath,
    required Future<File> Function() localFile,
  }) async {
    if (await AppDataPaths.iCloudReady()) {
      try {
        final text = await ICloudStorage.readInPlace(
          containerId: AppDataPaths.iCloudContainerId,
          relativePath: iCloudRelativePath,
        );
        if (text != null && text.trim().isNotEmpty) return text;
      } catch (_) {
        // Fall through to local mirror (offline / first run).
      }
    }
    final file = await localFile();
    if (!await file.exists()) return null;
    try {
      final text = await file.readAsString();
      return text.trim().isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeDocument({
    required String iCloudRelativePath,
    required Future<File> Function() localFile,
    required String contents,
  }) async {
    // Always keep a local mirror so a device without iCloud (or before the
    // container is ready) still persists festival config and Dropbox auth.
    final file = await localFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);

    if (await AppDataPaths.iCloudReady()) {
      try {
        await ICloudStorage.writeInPlace(
          containerId: AppDataPaths.iCloudContainerId,
          relativePath: iCloudRelativePath,
          contents: contents,
        );
      } catch (_) {
        // Local write already succeeded; sync can retry on a later launch.
      }
    }
  }

  /// Copy local Application Support config into iCloud once (no-op if iCloud
  /// is not configured on this device, or already has a non-empty registry).
  Future<bool> migrateLocalConfigToICloudIfNeeded() async {
    if (!await AppDataPaths.iCloudReady()) return false;

    var cloudRegistry = '';
    try {
      cloudRegistry = (await ICloudStorage.readInPlace(
            containerId: AppDataPaths.iCloudContainerId,
            relativePath: AppDataPaths.registryRelativePath,
          ))
              ?.trim() ??
          '';
    } catch (_) {
      cloudRegistry = '';
    }
    if (cloudRegistry.isNotEmpty) return false;

    final localReg = await AppDataPaths.localFestivalRegistryFile();
    final localAuth = await AppDataPaths.localDropboxAuthFile();
    var migrated = false;

    if (await localReg.exists()) {
      final text = await localReg.readAsString();
      if (text.trim().isNotEmpty) {
        await ICloudStorage.writeInPlace(
          containerId: AppDataPaths.iCloudContainerId,
          relativePath: AppDataPaths.registryRelativePath,
          contents: text.endsWith('\n') ? text : '$text\n',
        );
        migrated = true;
      }
    }

    if (await localAuth.exists()) {
      final text = await localAuth.readAsString();
      if (text.trim().isNotEmpty) {
        await ICloudStorage.writeInPlace(
          containerId: AppDataPaths.iCloudContainerId,
          relativePath: AppDataPaths.dropboxAuthRelativePath,
          contents: text.endsWith('\n') ? text : '$text\n',
        );
        migrated = true;
      }
    }

    if (migrated) {
      final marker = File(
        '${(await AppDataPaths.localRoot()).path}/.migrated_to_icloud',
      );
      await marker.writeAsString('${DateTime.now().toUtc().toIso8601String()}\n');
    }
    return migrated;
  }
}

/// Tiny JSON key/value file used for Dropbox auth (and similar).
class DurableJsonStore {
  DurableJsonStore({
    required this.iCloudRelativePath,
    required this.localFile,
    ConfigDocumentStore? documents,
  }) : _documents = documents ?? const ConfigDocumentStore();

  final String iCloudRelativePath;
  final Future<File> Function() localFile;
  final ConfigDocumentStore _documents;
  Map<String, String>? _cache;

  Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    final text = await _documents.readDocument(
      iCloudRelativePath: iCloudRelativePath,
      localFile: localFile,
    );
    if (text == null || text.trim().isEmpty) {
      _cache = {};
      return _cache!;
    }
    try {
      final raw = jsonDecode(text);
      if (raw is Map) {
        _cache = {
          for (final e in raw.entries)
            e.key.toString(): e.value?.toString() ?? '',
        };
      } else {
        _cache = {};
      }
    } catch (_) {
      _cache = {};
    }
    return _cache!;
  }

  Future<void> _save(Map<String, String> data) async {
    _cache = Map<String, String>.from(data);
    final contents =
        '${const JsonEncoder.withIndent('  ').convert(_cache)}\n';
    await _documents.writeDocument(
      iCloudRelativePath: iCloudRelativePath,
      localFile: localFile,
      contents: contents,
    );
  }

  Future<String?> getString(String key) async {
    final data = await _load();
    final v = data[key];
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setString(String key, String value) async {
    final data = await _load();
    data[key] = value;
    await _save(data);
  }

  Future<void> remove(String key) async {
    final data = await _load();
    data.remove(key);
    await _save(data);
  }
}

/// Dropbox auth document (iCloud when configured on device, else local-only).
DurableJsonStore dropboxAuthStore() => DurableJsonStore(
      iCloudRelativePath: AppDataPaths.dropboxAuthRelativePath,
      localFile: AppDataPaths.localDropboxAuthFile,
    );
