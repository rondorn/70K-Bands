import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Fetches Metal Archives HTML/JSON through a real browser engine so Cloudflare
/// JS challenges can complete.
///
/// - iOS: hidden WKWebView (MethodChannel), reused for the app session
/// - Windows: WebView2 via [desktop_webview_window], reused for the app session
///
/// Mac keeps using URLSession (`createMetalArchivesHttpClient`); curl alone is
/// not enough when Cloudflare returns HTTP 403.
class MaWebHtmlFetch {
  static const _channel = MethodChannel(
    'com.rdorn.open_metal_fest_admin/ma_web_fetch',
  );

  /// One WebView fetch at a time (single shared Edge/WebKit instance).
  static Future<void> _windowsGate = Future.value();

  /// Reused WebView2 handle — create once, navigate many times (iPad pattern).
  static Webview? _windowsWebview;
  static Completer<Webview>? _windowsCreating;

  /// After one successful MA body, CF cookies exist → shorter waits.
  static bool _windowsWarm = false;

  /// Prefer JSON text when present; otherwise full HTML (matches iPad WKWebView).
  static const _extractBodyJs = r'''
(function () {
  var text = (document.body && (document.body.innerText || document.body.textContent)) || '';
  var trimmed = text.trim();
  if (trimmed.charAt(0) === '{' || trimmed.charAt(0) === '[') {
    return trimmed;
  }
  return document.documentElement.outerHTML;
})()
''';

  static bool get isSupported => Platform.isIOS || Platform.isWindows;

  /// True after at least one successful Windows WebView2 MA fetch this session.
  static bool get windowsSessionWarm => _windowsWarm;

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
    if (html.length < 20) {
      throw StateError('WKWebView returned empty or blocked HTML.');
    }
    _assertNotChallenge(html);
    return html;
  }

  static Future<String> _fetchWindows(
    String url, {
    required bool expectJson,
  }) {
    // Chain callers so only one navigation runs at a time on the shared window.
    final previous = _windowsGate;
    final done = Completer<void>();
    _windowsGate = done.future;
    final gateTimeout =
        _windowsWarm ? const Duration(seconds: 18) : const Duration(seconds: 45);
    return previous.then((_) async {
      try {
        return await _fetchWindowsUnlocked(url, expectJson: expectJson)
            .timeout(gateTimeout);
      } finally {
        done.complete();
      }
    });
  }

  static Future<Webview> _ensureWindowsWebview() async {
    final existing = _windowsWebview;
    if (existing != null) return existing;

    final inFlight = _windowsCreating;
    if (inFlight != null) return inFlight.future;

    final creating = Completer<Webview>();
    _windowsCreating = creating;
    try {
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
      await webview.setWebviewWindowVisibility(false);
      _windowsWebview = webview;
      // If the OS/plugin closes the window, drop the handle and recreate next time.
      // Cookies stay in [userData], so [_windowsWarm] can remain true.
      unawaited(webview.onClose.then((_) {
        if (identical(_windowsWebview, webview)) {
          _windowsWebview = null;
        }
      }));
      creating.complete(webview);
      return webview;
    } catch (e, st) {
      creating.completeError(e, st);
      rethrow;
    } finally {
      _windowsCreating = null;
    }
  }

  static Future<String> _fetchWindowsUnlocked(
    String url, {
    required bool expectJson,
  }) async {
    Future<String> poll(Webview view) async {
      try {
        await view.stop();
      } catch (_) {}
      try {
        await view.setWebviewWindowVisibility(false);
      } catch (_) {}

      // Edge/WebView2 UA already looks like a browser; Cloudflare's JS challenge
      // needs that engine — not the short "70000tons" allowlist UA used by curl.
      view.launch(url);

      // First hit needs CF time; warm hits after cookies exist are much faster.
      final deadline = DateTime.now().add(
        _windowsWarm
            ? const Duration(seconds: 12)
            : const Duration(seconds: 40),
      );
      Object? lastError;
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        try {
          final raw = await view.evaluateJavaScript(_extractBodyJs);
          final text = unwrapJsStringResult(raw);
          if (isAcceptableMaBody(text, expectJson: expectJson)) {
            _windowsWarm = true;
            return text;
          }
          if (looksLikeCloudflareChallenge(text)) {
            lastError = 'still on Cloudflare challenge (${text.length} bytes)';
            continue;
          }
          lastError = 'short or unexpected body (${text.length} bytes)';
        } catch (e) {
          lastError = e;
          // Window closed (onClose cleared the handle) — stop and recreate.
          if (_windowsWebview == null || !identical(_windowsWebview, view)) {
            break;
          }
          // Transient evaluate errors while the page/CF script loads — keep polling.
        }
      }
      throw StateError(
        'WebView2 timed out waiting for Metal Archives ($lastError).',
      );
    }

    var webview = await _ensureWindowsWebview();
    try {
      return await poll(webview);
    } catch (_) {
      // Recreate only when the shared window disappeared — never on a normal
      // CF/timeout failure (that would wipe a warm cookie session).
      if (_windowsWebview != null) rethrow;
      webview = await _ensureWindowsWebview();
      return await poll(webview);
    }
  }

  /// WebView2 / Chrome DevTools often return a JSON-encoded string
  /// (`"…\u003Ca href=…"`). Decode until we have real HTML.
  static String unwrapJsStringResult(String? value) {
    var v = (value ?? '').trim();
    if (v.isEmpty) return v;

    for (var i = 0; i < 3; i++) {
      if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) {
        try {
          final decoded = jsonDecode(v);
          if (decoded is String) {
            v = decoded;
            continue;
          }
        } catch (_) {}
      }
      if (v.contains(r'\u00') || v.contains(r'\/') || v.contains(r'\"')) {
        final next = decodeJsonStringEscapes(v);
        if (next == v) break;
        v = next;
        continue;
      }
      break;
    }
    return v.trim();
  }

  /// Decode `\uXXXX`, `\"`, `\\`, etc. without requiring surrounding quotes.
  static String decodeJsonStringEscapes(String value) {
    final buf = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final ch = value[i];
      if (ch != r'\' || i + 1 >= value.length) {
        buf.write(ch);
        continue;
      }
      final next = value[i + 1];
      switch (next) {
        case 'u':
          if (i + 5 < value.length) {
            final hex = value.substring(i + 2, i + 6);
            final code = int.tryParse(hex, radix: 16);
            if (code != null) {
              buf.writeCharCode(code);
              i += 5;
              continue;
            }
          }
          buf.write(ch);
          break;
        case 'n':
          buf.write('\n');
          i++;
          break;
        case 'r':
          buf.write('\r');
          i++;
          break;
        case 't':
          buf.write('\t');
          i++;
          break;
        case '"':
        case r'\':
        case '/':
          buf.write(next);
          i++;
          break;
        default:
          buf.write(ch);
          break;
      }
    }
    return buf.toString();
  }

  static bool isAcceptableMaBody(String body, {required bool expectJson}) {
    if (body.length < 2) return false;
    if (looksLikeCloudflareChallenge(body)) return false;
    if (expectJson) {
      final trimmed = body.trimLeft();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return trimmed.length >= 2;
      }
      // WebView often paints ajax-advanced as HTML; band links are enough.
      final lower = body.toLowerCase();
      return lower.contains('metal-archives.com/bands/') && body.length >= 40;
    }
    if (body.length < 20) return false;
    final lower = body.toLowerCase();
    if (lower.contains('class="band_name"') ||
        lower.contains('var bandname =') ||
        lower.contains('id="band_stats"') ||
        lower.contains('class="display discog"') ||
        lower.contains('id="band_disco"') ||
        lower.contains('header_official') ||
        lower.contains('id="logo"')) {
      return true;
    }
    // ajax-list / fragments: shorter HTML tables without band_name markers.
    if (lower.contains('<table') || lower.contains('<tr')) {
      return body.length >= 200;
    }
    return body.length >= 500;
  }

  static bool looksLikeCloudflareChallenge(String body) {
    final lower = body.toLowerCase();
    // Real MA pages embed Cloudflare's jsd script (`/cdn-cgi/challenge-platform/...`).
    // That is not a block page — only treat interstitials as blocked.
    if (lower.contains('class="band_name"') ||
        lower.contains('var bandname =') ||
        lower.contains('id="band_stats"') ||
        lower.contains('class="display discog"') ||
        lower.contains('header_official') ||
        lower.contains('id="band_disco"')) {
      return false;
    }
    return lower.contains('just a moment...') ||
        lower.contains('<title>just a moment') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('checking your browser') ||
        lower.contains('cdn-cgi/challenge-platform/h/') ||
        (lower.contains('access denied') && lower.contains('cloudflare'));
  }

  static void _assertNotChallenge(String html) {
    final lower = html.toLowerCase();
    final looksLikeMa = lower.contains('class="band_name"') ||
        lower.contains('var bandname =') ||
        lower.contains('id="band_stats"') ||
        lower.contains('class="display discog"') ||
        html.trimLeft().startsWith('{') ||
        html.trimLeft().startsWith('[');
    if (looksLikeMa) return;
    if (looksLikeCloudflareChallenge(html)) {
      throw StateError(
        'WKWebView still on Cloudflare challenge page after timeout.',
      );
    }
  }
}
