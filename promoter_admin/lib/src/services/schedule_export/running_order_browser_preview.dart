import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// On Windows, [webview_flutter] has no embedded WebView — preview uses a temp
/// HTML file opened in the default browser instead.
class RunningOrderBrowserPreview {
  const RunningOrderBrowserPreview._();

  static const _fileName = 'omf-schedule-running-order-preview.html';

  static bool get useExternalBrowser => !kIsWeb && Platform.isWindows;

  /// Writes [htmlBytes] to a stable temp path so browser refresh picks up edits.
  static Future<File> writePreviewFile(Uint8List htmlBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, _fileName));
    await file.writeAsBytes(htmlBytes, flush: true);
    return file;
  }

  static Future<void> openInDefaultBrowser(File file) async {
    if (!await file.exists()) {
      throw StateError('Preview file is missing.');
    }
    final uri = Uri.file(file.path);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError(
        'Could not open the schedule preview in your default browser.',
      );
    }
  }
}
