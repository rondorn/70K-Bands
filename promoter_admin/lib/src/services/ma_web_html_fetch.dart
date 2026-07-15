import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Fetches Metal Archives HTML/JSON through a real browser engine so Cloudflare
/// JS challenges can complete.
///
/// - iOS: hidden WKWebView (MethodChannel)
/// - Windows: WebView2 via [desktop_webview_window] (tiny hidden window)
///
/// Mac keeps using URLSession (`createMetalArchivesHttpClient`); curl alone is
/// not enough when Cloudflare returns HTTP 403.
class MaWebHtmlFetch {
  static const _channel = MethodChannel(
    'com.rdorn.open_metal_fest_admin/ma_web_fetch',
  );

  /// One WebView fetch at a time (single shared Edge/WebKit instance).
  static Future<void> _windowsGate = Future.value();

  static bool get isSupported => Platform.isIOS || Platform.isWindows;

  static Future<String> fetchHtml(
    String url, {
    bool expectJson = false,
  }) async {
    if (Platform.isIOS) {
      return _fetchIos(url);
    }
    if (Platform.isWindows) {
      return _fetchWindows(url, expectJson: expectJson);
    }
    throw UnsupportedError(
      'Browser Metal Archives fetch is only supported on iOS and Windows.',
    );
  }

  static Future<String> _fetchIos(String url) async {
    final result = await _channel.invokeMethod<String>('fetchHtml', {
      'url': url,
    });
    final html = (result ?? '').trim();
    if (html.length < 500) {
      throw StateError('WKWebView returned empty or blocked HTML.');
    }
    _assertNotChallenge(html, expectJson: false);
    return html;
  }

  static Future<String> _fetchWindows(
    String url, {
    required bool expectJson,
  }) {
    // Chain callers so only one WebView2 window runs at a time.
    final previous = _windowsGate;
    final done = Completer<void>();
    _windowsGate = done.future;
    return previous.then((_) async {
      try {
        return await _fetchWindowsUnlocked(url, expectJson: expectJson)
            .timeout(const Duration(seconds: 45));
      } finally {
        done.complete();
      }
    });
  }

  static Future<String> _fetchWindowsUnlocked(
    String url, {
    required bool expectJson,
  }) async {
    final available = await WebviewWindow.isWebviewAvailable();
    if (!available) {
      throw StateError(
        'WebView2 Runtime is not available. Install the Microsoft Edge '
        'WebView2 Runtime, then try Discover again.',
      );
    }

    final support = await getApplicationSupportDirectory();
    final userData = '${support.path}${Platform.pathSeparator}ma_webview2';

    final webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowWidth: 8,
        windowHeight: 8,
        title: 'Metal Archives',
        titleBarHeight: 0,
        userDataFolderWindows: userData,
        useWindowPositionAndSize: true,
        windowPosX: -32000,
        windowPosY: -32000,
      ),
    );

    try {
      await webview.setWebviewWindowVisibility(false);
      // Edge/WebView2 UA already looks like a browser; Cloudflare's JS challenge
      // needs that engine — not the short "70000tons" allowlist UA used by curl.
      webview.launch(url);

      final deadline = DateTime.now().add(const Duration(seconds: 40));
      Object? lastError;
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 750));
        try {
          final raw = await webview.evaluateJavaScript(
            expectJson
                ? r'''
(function () {
  var t = (document.body && (document.body.innerText || document.body.textContent)) || '';
  return t;
})()
'''
                : 'document.documentElement.outerHTML',
          );
          final body = (raw ?? '').trim();
          // evaluateJavaScript may return a JSON-encoded string with quotes.
          final text = _unwrapJsString(body);
          if (_isAcceptable(text, expectJson: expectJson)) {
            return text;
          }
          if (_looksLikeChallenge(text)) {
            lastError = 'still on Cloudflare challenge (${text.length} bytes)';
            continue;
          }
          lastError = 'short or unexpected body (${text.length} bytes)';
        } catch (e) {
          lastError = e;
        }
      }
      throw StateError(
        'WebView2 timed out waiting for Metal Archives ($lastError).',
      );
    } finally {
      try {
        webview.close();
      } catch (_) {}
    }
  }

  static String _unwrapJsString(String value) {
    var v = value.trim();
    if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) {
      try {
        // Cheap unescape for typical WebView2 JSON string results.
        v = v
            .substring(1, v.length - 1)
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '\r')
            .replaceAll(r'\t', '\t')
            .replaceAll(r'\\', r'\');
      } catch (_) {}
    }
    return v.trim();
  }

  static bool _isAcceptable(String body, {required bool expectJson}) {
    if (body.length < 20) return false;
    if (_looksLikeChallenge(body)) return false;
    if (expectJson) {
      final trimmed = body.trimLeft();
      return trimmed.startsWith('{') || trimmed.startsWith('[');
    }
    final lower = body.toLowerCase();
    final looksLikeMa = lower.contains('class="band_name"') ||
        lower.contains('var bandname =') ||
        lower.contains('id="band_stats"') ||
        lower.contains('class="display discog"');
    if (looksLikeMa) return true;
    return body.length >= 5000;
  }

  static bool _looksLikeChallenge(String body) {
    final lower = body.toLowerCase();
    return lower.contains('just a moment...') ||
        lower.contains('<title>just a moment') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('checking your browser') ||
        lower.contains('cdn-cgi/challenge-platform/h/') ||
        (lower.contains('access denied') && lower.contains('cloudflare'));
  }

  static void _assertNotChallenge(String html, {required bool expectJson}) {
    final lower = html.toLowerCase();
    final looksLikeMa = lower.contains('class="band_name"') ||
        lower.contains('var bandname =') ||
        lower.contains('id="band_stats"') ||
        lower.contains('class="display discog"');
    if (looksLikeMa) return;
    if (_looksLikeChallenge(html)) {
      throw StateError(
        'WKWebView still on Cloudflare challenge page after timeout.',
      );
    }
  }
}
