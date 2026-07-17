import 'dart:io';

import 'package:icloud_storage_plus/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Shared config locations for festival registry + Dropbox auth.
///
/// On Apple platforms (when signed into iCloud), config lives in the app's
/// iCloud Documents container so Mac and iPad share the same files.
/// Elsewhere (Windows, or iCloud unavailable), falls back to a local folder.
class AppDataPaths {
  static const folderName = 'OpenMetalFestAdmin';
  static const iCloudContainerId = 'iCloud.com.rdorn.open-metal-fest-admin';

  static const registryRelativePath =
      'Documents/$folderName/festival_registry.json';
  static const dropboxAuthRelativePath =
      'Documents/$folderName/dropbox_auth.json';
  static const portalNavigationRelativePath =
      'Documents/$folderName/portal_navigation.json';

  /// True when we should use iCloud Documents for synced config.
  static bool get prefersICloud => Platform.isIOS || Platform.isMacOS;

  static Future<bool> iCloudReady() async {
    if (!prefersICloud) return false;
    try {
      return await ICloudStorage.icloudAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Local-only root (also used as fallback and for schedule staging).
  static Future<Directory> localRoot() async {
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME']?.trim() ?? '';
      if (home.isNotEmpty) {
        final dir = Directory('$home/Library/Application Support/$folderName');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    }
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/$folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Prefer iCloud container Documents path when available; else [localRoot].
  static Future<Directory> root() async {
    if (await iCloudReady()) {
      try {
        final container = await ICloudStorage.getContainerPath(
          containerId: iCloudContainerId,
        );
        if (container != null && container.trim().isNotEmpty) {
          final dir = Directory('$container/Documents/$folderName');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      } catch (_) {
        // Fall through to local.
      }
    }
    return localRoot();
  }

  static Future<File> localFestivalRegistryFile() async {
    final dir = await localRoot();
    return File('${dir.path}/festival_registry.json');
  }

  static Future<File> localDropboxAuthFile() async {
    final dir = await localRoot();
    return File('${dir.path}/dropbox_auth.json');
  }

  static Future<File> localPortalNavigationFile() async {
    final dir = await localRoot();
    return File('${dir.path}/portal_navigation.json');
  }

  static Future<File> festivalRegistryFile() async {
    final dir = await root();
    return File('${dir.path}/festival_registry.json');
  }

  static Future<File> dropboxAuthFile() async {
    final dir = await root();
    return File('${dir.path}/dropbox_auth.json');
  }

  /// Schedule staging stays device-local (not synced).
  static Future<Directory> scheduleStagingDir() async {
    final dir = await localRoot();
    final staging = Directory('${dir.path}/schedule_staging');
    if (!await staging.exists()) {
      await staging.create(recursive: true);
    }
    return staging;
  }
}
