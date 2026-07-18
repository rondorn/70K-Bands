import 'dart:io';

import 'package:icloud_storage_plus/icloud_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Shared config locations for festival registry + Dropbox auth.
///
/// On Apple platforms, config syncs via the app's iCloud Documents container
/// when iCloud is **configured** for this device (signed in + container
/// available). If iCloud is not set up on the device, everything stays in a
/// local Application Support folder. Transient network outages do not switch
/// modes: once the container resolves, writes still go to the ubiquity folder
/// (they sync when connectivity returns).
class AppDataPaths {
  static const folderName = 'OpenMetalFestAdmin';
  static const iCloudContainerId = 'iCloud.com.rdorn.open-metal-fest-admin';

  static const registryRelativePath =
      'Documents/$folderName/festival_registry.json';
  static const dropboxAuthRelativePath =
      'Documents/$folderName/dropbox_auth.json';
  static const portalNavigationRelativePath =
      'Documents/$folderName/portal_navigation.json';

  /// True when this platform can use iCloud Documents (iOS / macOS).
  static bool get prefersICloud => Platform.isIOS || Platform.isMacOS;

  /// Cached result of [iCloudReady] for this process. Null until probed.
  static bool? _iCloudConfigured;

  /// Test seam: when set, [iCloudReady] uses this instead of the native probe.
  static Future<bool> Function()? debugICloudProbeOverride;

  /// Clears the process cache (tests / after enabling iCloud mid-session).
  static void resetICloudConfiguredCache() {
    _iCloudConfigured = null;
  }

  /// True when iCloud Documents is configured for this app on this device.
  ///
  /// Requires both an iCloud account (`ubiquityIdentityToken`) **and** a
  /// resolvable ubiquity container URL. A signed-in Apple ID with iCloud Drive
  /// off (or no container) returns false → local storage only.
  ///
  /// Does **not** mean "network is up". Container resolution works offline when
  /// iCloud is configured; temporary connectivity loss still uses iCloud paths.
  static Future<bool> iCloudReady() async {
    final cached = _iCloudConfigured;
    if (cached != null) return cached;

    if (!prefersICloud) {
      _iCloudConfigured = false;
      return false;
    }

    final override = debugICloudProbeOverride;
    if (override != null) {
      final value = await override();
      _iCloudConfigured = value;
      return value;
    }

    try {
      final signedIn = await ICloudStorage.icloudAvailable();
      if (!signedIn) {
        _iCloudConfigured = false;
        return false;
      }
      final container = await ICloudStorage.getContainerPath(
        containerId: iCloudContainerId,
      );
      final configured =
          container != null && container.trim().isNotEmpty;
      _iCloudConfigured = configured;
      return configured;
    } catch (_) {
      // Not configured / container inaccessible — use local, do not retry
      // iCloud for the rest of this launch.
      _iCloudConfigured = false;
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

  /// Prefer iCloud container Documents path when configured; else [localRoot].
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
