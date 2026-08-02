import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:promoter_admin/src/models/emergency_local_paths.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/emergency_local_mode_support.dart';

/// Result of checking a mapped local path.
class LocalPathCheck {
  const LocalPathCheck({
    required this.path,
    required this.exists,
    required this.readable,
    required this.writable,
    this.isDirectory = false,
    this.sizeBytes,
    this.error = '',
  });

  final String path;
  final bool exists;
  final bool readable;
  final bool writable;
  final bool isDirectory;
  final int? sizeBytes;
  final String error;

  bool get ok => exists && readable && writable && error.isEmpty;

  String get summary {
    if (error.isNotEmpty) return error;
    if (!exists) return 'Not found';
    if (!readable) return 'Not readable';
    if (!writable) return 'Not writable';
    if (isDirectory) return 'Folder OK';
    final size = sizeBytes;
    if (size == null) return 'File OK';
    return 'File OK ($size bytes)';
  }
}

/// Read/write helpers for Local File Mode.
class LocalContentStore {
  const LocalContentStore._();

  static bool isLocalLocator(String locator) {
    final trimmed = locator.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    return !lower.startsWith('http://') && !lower.startsWith('https://');
  }

  static String expandPath(String raw) {
    var path = raw.trim();
    if (path.startsWith('~/')) {
      final home = Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        path = '$home/${path.substring(2)}';
      }
    } else if (path == '~') {
      path = Platform.environment['HOME'] ?? path;
    }
    return path;
  }

  static Future<String> readText(String rawPath) async {
    final path = expandPath(rawPath);
    if (path.isEmpty) {
      throw StateError('Local path is not configured.');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('File not found: $path');
    }
    return file.readAsString();
  }

  static Future<void> writeText(String rawPath, String text) async {
    final path = expandPath(rawPath);
    if (path.isEmpty) {
      throw StateError('Local path is not configured.');
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  static Future<LocalPathCheck> checkPath(
    String rawPath, {
    required bool directory,
  }) async {
    final path = expandPath(rawPath);
    if (path.isEmpty) {
      return const LocalPathCheck(
        path: '',
        exists: false,
        readable: false,
        writable: false,
        error: 'Path is empty',
      );
    }
    try {
      if (directory) {
        final dir = Directory(path);
        final exists = await dir.exists();
        if (!exists) {
          return LocalPathCheck(
            path: path,
            exists: false,
            readable: false,
            writable: false,
            isDirectory: true,
          );
        }
        var readable = false;
        var writable = false;
        try {
          await dir.list(followLinks: false).take(1).toList();
          readable = true;
        } catch (_) {}
        try {
          final probe = File('${dir.path}/.omf_write_probe');
          await probe.writeAsString('', flush: true);
          await probe.delete();
          writable = true;
        } catch (_) {}
        return LocalPathCheck(
          path: path,
          exists: true,
          readable: readable,
          writable: writable,
          isDirectory: true,
        );
      }
      final file = File(path);
      final exists = await file.exists();
      if (!exists) {
        final parent = file.parent;
        final parentExists = await parent.exists();
        var parentWritable = false;
        if (parentExists) {
          try {
            final probe = File('${parent.path}/.omf_write_probe');
            await probe.writeAsString('', flush: true);
            await probe.delete();
            parentWritable = true;
          } catch (_) {}
        }
        return LocalPathCheck(
          path: path,
          exists: false,
          readable: false,
          writable: parentWritable,
          isDirectory: false,
          error: parentWritable
              ? 'File not found (parent folder is writable — save will create it)'
              : 'File not found (parent folder missing or not writable)',
        );
      }
      var readable = false;
      var writable = false;
      int? sizeBytes;
      try {
        final text = await file.readAsString();
        readable = true;
        sizeBytes = text.length;
      } catch (_) {}
      try {
        await file.writeAsString(await file.readAsString(), flush: true);
        writable = true;
      } catch (_) {}
      try {
        sizeBytes ??= (await file.stat()).size;
      } catch (_) {}
      return LocalPathCheck(
        path: path,
        exists: true,
        readable: readable,
        writable: writable,
        isDirectory: false,
        sizeBytes: sizeBytes,
      );
    } catch (e) {
      return LocalPathCheck(
        path: path,
        exists: false,
        readable: false,
        writable: false,
        isDirectory: directory,
        error: e.toString(),
      );
    }
  }

  static Future<String?> pickFile({String? initialDirectory}) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv', 'txt']),
        XTypeGroup(label: 'All files', extensions: ['*']),
      ],
      initialDirectory: initialDirectory,
    );
    return file?.path;
  }

  static Future<String?> pickDirectory({String? initialDirectory}) async {
    return getDirectoryPath(initialDirectory: initialDirectory);
  }

  static Future<void> writeAlertPendingFile({
    required String alertsDir,
    required String fileName,
    required String text,
  }) async {
    final dirPath = expandPath(alertsDir);
    if (dirPath.isEmpty) {
      throw StateError('Alerts folder path is not configured.');
    }
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw StateError('Alerts folder not found: $dirPath');
    }
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(text);
  }

  static String descriptionFilePath({
    required EmergencyLocalPaths paths,
    required String labelName,
  }) {
    final dir = expandPath(paths.descriptionsDir.trim());
    if (dir.isEmpty) {
      throw StateError('Descriptions folder path is not configured.');
    }
    final safe = _safeFileStem(labelName);
    if (safe.isEmpty) {
      throw StateError('Band / event name is required.');
    }
    return '$dir/$safe.txt';
  }

  static String _safeFileStem(String labelName) {
    return labelName
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-.]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}

extension FestivalWorkspaceEmergencyLocal on FestivalWorkspace {
  bool get hasArtistsLocalPath =>
      usesEmergencyLocalMode && emergencyLocalPaths.artistsCsv.trim().isNotEmpty;

  bool get hasScheduleLocalPath =>
      usesEmergencyLocalMode && emergencyLocalPaths.scheduleCsv.trim().isNotEmpty;

  bool get hasDescriptionMapLocalPath =>
      usesEmergencyLocalMode &&
      emergencyLocalPaths.descriptionMapCsv.trim().isNotEmpty;

  bool get hasDescriptionsDirLocalPath =>
      usesEmergencyLocalMode &&
      emergencyLocalPaths.descriptionsDir.trim().isNotEmpty;

  bool get hasAlertsLocalPath =>
      usesEmergencyLocalMode && emergencyLocalPaths.alertsDir.trim().isNotEmpty;

  bool get artistsDataReady =>
      usesEmergencyLocalMode ? hasArtistsLocalPath : bandListUrl.trim().isNotEmpty;

  bool get scheduleDataReady =>
      usesEmergencyLocalMode ? hasScheduleLocalPath : scheduleUrl.trim().isNotEmpty;

  bool get descriptionMapDataReady => usesEmergencyLocalMode
      ? hasDescriptionMapLocalPath
      : descriptionMapUrl.trim().isNotEmpty;

  bool get effectiveCanEditBands =>
      usesEmergencyLocalMode ? hasArtistsLocalPath : canEditBands;

  bool get effectiveCanEditSchedule =>
      usesEmergencyLocalMode ? hasScheduleLocalPath : canEditSchedule;

  bool get effectiveCanEditDescriptions =>
      usesEmergencyLocalMode ? hasDescriptionMapLocalPath : canEditDescriptions;

  bool get effectiveCanEditAlerts =>
      usesEmergencyLocalMode ? hasAlertsLocalPath : canEditAlerts;

  bool get effectiveCustomAlertsUiEnabled => usesEmergencyLocalMode
      ? hasAlertsLocalPath
      : customAlertsUiEnabled;

  bool get effectiveReportsUiEnabled =>
      usesEmergencyLocalMode ? false : reportsUiEnabled;
}
