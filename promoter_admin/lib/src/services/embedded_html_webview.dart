import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_plugin.dart';

/// Creates an in-app HTML preview controller for macOS, iOS, and Windows.
///
/// On Windows this uses WebView2 via [webview_win_floating] (registered as the
/// federated [webview_flutter] implementation). Other desktop/mobile platforms
/// use their default [webview_flutter] backends.
Future<WebViewController> createEmbeddedHtmlWebViewController(
  String html, {
  JavaScriptMode javaScriptMode = JavaScriptMode.unrestricted,
}) async {
  final controller = await _newPlatformController();
  await controller.setJavaScriptMode(javaScriptMode);
  await controller.loadHtmlString(html);
  return controller;
}

Future<WebViewController> _newPlatformController() async {
  if (!kIsWeb && Platform.isWindows) {
    final support = await getApplicationSupportDirectory();
    final userDataFolder = p.join(support.path, 'omf_html_preview_webview2');
    return WebViewController.fromPlatformCreationParams(
      WindowsWebViewControllerCreationParams(
        userDataFolder: userDataFolder,
        profileName: 'html_preview',
      ),
    );
  }
  return WebViewController();
}

/// Whether embedded in-app HTML preview is available on this platform.
bool get embeddedHtmlWebViewSupported {
  if (kIsWeb) return false;
  return Platform.isMacOS ||
      Platform.isIOS ||
      Platform.isWindows ||
      Platform.isAndroid;
}
