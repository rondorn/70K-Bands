import 'dart:io';
import 'dart:ui' show Rect;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Result of writing an export file (desktop save dialog or mobile share sheet).
class SavedExport {
  const SavedExport({required this.path, required this.shared});

  /// Absolute path on desktop; suggested file name on iOS/Android.
  final String path;

  /// True when the user was offered the system share sheet (mobile).
  final bool shared;

  String get snackbarLocation => shared ? 'the share sheet' : path;
}

/// Saves [bytes] via a desktop "Save As" dialog, or on iOS/Android writes a
/// temp file and opens the share sheet (Save to Files, AirDrop, Mail, …).
///
/// [sharePositionOrigin] is required for a reliable share popover on iPad.
///
/// Returns null if the user cancels.
Future<SavedExport?> saveExportBytes({
  required Uint8List bytes,
  required String suggestedName,
  required String extension,
  required String mimeType,
  String typeLabel = 'Document',
  Rect? sharePositionOrigin,
}) async {
  final base = suggestedName.toLowerCase().endsWith('.$extension')
      ? suggestedName
      : '$suggestedName.$extension';
  final fileName = p.basename(base);

  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: fileName)],
        subject: fileName,
        sharePositionOrigin:
            sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 1, 1),
      ),
    );
    if (result.status == ShareResultStatus.dismissed) {
      return null;
    }
    return SavedExport(path: fileName, shared: true);
  }

  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: [
      XTypeGroup(label: typeLabel, extensions: [extension]),
    ],
  );
  if (location == null) return null;
  final targetPath =
      p.extension(location.path).toLowerCase() == '.$extension'
      ? location.path
      : '${location.path}.$extension';
  await XFile.fromData(
    bytes,
    name: p.basename(targetPath),
    mimeType: mimeType,
  ).saveTo(targetPath);
  return SavedExport(path: targetPath, shared: false);
}
