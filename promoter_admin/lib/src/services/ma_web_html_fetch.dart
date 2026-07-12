import 'dart:io';

import 'package:flutter/services.dart';

/// Fetches HTML through an on-device WKWebView (iOS) so Cloudflare JS challenges
/// can complete. Mac/desktop keep using curl / URLSession instead.
class MaWebHtmlFetch {
  static const _channel = MethodChannel(
    'com.rdorn.open_metal_fest_admin/ma_web_fetch',
  );

  static bool get isSupported => Platform.isIOS;

  static Future<String> fetchHtml(String url) async {
    if (!isSupported) {
      throw UnsupportedError('WKWebView Metal Archives fetch is iOS-only.');
    }
    final result = await _channel.invokeMethod<String>('fetchHtml', {
      'url': url,
    });
    final html = (result ?? '').trim();
    if (html.length < 500) {
      throw StateError('WKWebView returned empty or blocked HTML.');
    }
    final lower = html.toLowerCase();
    // Successful MA pages include Cloudflare jsd scripts; only reject interstitials.
    final looksLikeMa = lower.contains('class="band_name"') ||
        lower.contains('var bandname =') ||
        lower.contains('id="band_stats"') ||
        lower.contains('class="display discog"');
    if (looksLikeMa) return html;
    if (lower.contains('just a moment...') ||
        lower.contains('<title>just a moment') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('checking your browser') ||
        lower.contains('cdn-cgi/challenge-platform/h/')) {
      throw StateError(
        'WKWebView still on Cloudflare challenge page after timeout.',
      );
    }
    return html;
  }
}
