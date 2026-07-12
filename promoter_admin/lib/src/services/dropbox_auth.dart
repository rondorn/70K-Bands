import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/durable_json_store.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dropbox OAuth (PKCE) for Open Metal Fest Admin.
///
/// Redirect URIs (both must be listed on the Dropbox app):
///   - Desktop: http://127.0.0.1:53682/oauth/dropbox/callback
///   - iOS/Android: omfadmin://oauth/dropbox/callback
///
/// Mobile uses ASWebAuthenticationSession / Chrome Custom Tabs so the auth
/// sheet dismisses and returns to the app. Opening external Safari + localhost
/// hangs on iPad because iOS suspends the app (and its callback server) while
/// Safari is foreground.
///
/// macOS sandbox must include `com.apple.security.network.server` so the
/// desktop callback listener can bind to 127.0.0.1.
class DropboxAuth {
  static const appKey = 'ug24jfmymp185wi';

  /// Desktop loopback callback (HttpServer).
  static const loopbackRedirectUri =
      'http://127.0.0.1:53682/oauth/dropbox/callback';

  /// Native app callback (ASWebAuthenticationSession / Chrome Custom Tabs).
  static const appRedirectScheme = 'omfadmin';
  static const appRedirectUri = 'omfadmin://oauth/dropbox/callback';

  static const _callbackPort = 53682;
  static const scopes = [
    'account_info.read',
    'files.content.write',
    'files.metadata.read',
    'sharing.read',
    'sharing.write',
  ];

  static const _kAccess = 'dbx_access_token';
  static const _kRefresh = 'dbx_refresh_token';
  static const _kEmail = 'dbx_account_email';
  static const _kName = 'dbx_account_name';

  final DurableJsonStore _store = dropboxAuthStore();

  /// iOS/Android cannot reliably host a localhost callback while Safari is up.
  static bool get usesAppRedirect => Platform.isIOS || Platform.isAndroid;

  static String get redirectUri =>
      usesAppRedirect ? appRedirectUri : loopbackRedirectUri;

  Future<bool> get isConnected async {
    final refresh = await _store.getString(_kRefresh) ?? '';
    final access = await _store.getString(_kAccess) ?? '';
    return refresh.isNotEmpty || access.isNotEmpty;
  }

  Future<String> accountLabel() async {
    final email = (await _store.getString(_kEmail) ?? '').trim();
    if (email.isNotEmpty) return email;
    return (await _store.getString(_kName) ?? '').trim();
  }

  Future<void> disconnect() async {
    await _store.remove(_kAccess);
    await _store.remove(_kRefresh);
    await _store.remove(_kEmail);
    await _store.remove(_kName);
  }

  Future<String> accessToken() async {
    final existing = await _store.getString(_kAccess) ?? '';
    final refresh = await _store.getString(_kRefresh) ?? '';
    if (refresh.isEmpty) {
      if (existing.isNotEmpty) return existing;
      throw StateError('Connect Dropbox first.');
    }
    final refreshed = await _refresh(refresh);
    await _store.setString(_kAccess, refreshed);
    return refreshed;
  }

  Future<String> connectInteractive() async {
    final verifier = _randomVerifier();
    final challenge = _challenge(verifier);
    final state = _randomVerifier().substring(0, 16);
    final redirect = redirectUri;

    final authUrl = Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': appKey,
      'response_type': 'code',
      'token_access_type': 'offline',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'redirect_uri': redirect,
      'state': state,
      'scope': scopes.join(' '),
    });

    final code = usesAppRedirect
        ? await _waitForCodeViaWebAuth(authUrl, state)
        : await _waitForCodeLoopback(authUrl, state);
    final tokens = await _exchangeCode(code, verifier, redirect);
    await _store.setString(_kAccess, tokens['access_token'] ?? '');
    if ((tokens['refresh_token'] ?? '').isNotEmpty) {
      await _store.setString(_kRefresh, tokens['refresh_token']!);
    }
    await _fetchAndStoreAccount(tokens['access_token']!);
    return accountLabel();
  }

  Future<void> _fetchAndStoreAccount(String accessToken) async {
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/users/get_current_account'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: 'null',
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final email = (data['email'] ?? '').toString();
      final name = (data['name'] is Map)
          ? ((data['name'] as Map)['display_name'] ?? '').toString()
          : '';
      if (email.isNotEmpty) await _store.setString(_kEmail, email);
      if (name.isNotEmpty) await _store.setString(_kName, name);
    }
  }

  /// iOS/Android: system auth session dismisses when Dropbox redirects to our scheme.
  Future<String> _waitForCodeViaWebAuth(Uri authUrl, String expectedState) async {
    late final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: appRedirectScheme,
      );
    } catch (e) {
      throw StateError('Dropbox sign-in was cancelled or failed ($e).');
    }

    final uri = Uri.parse(result);
    final params = uri.queryParameters;
    if (params['error'] != null) {
      throw StateError(params['error_description'] ?? params['error']!);
    }
    if (params['state'] != expectedState) {
      throw StateError('OAuth state mismatch.');
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw StateError('Dropbox did not return an authorization code.');
    }
    return code;
  }

  /// Desktop: local HTTP listener + external browser.
  Future<String> _waitForCodeLoopback(Uri authUrl, String expectedState) async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, _callbackPort);
    } on SocketException catch (e) {
      throw StateError(
        'Could not start local Dropbox callback on port $_callbackPort ($e). '
        'Quit other copies of this app, then try Connect again.',
      );
    }
    try {
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open Dropbox sign-in in the browser.');
      }
      await for (final request in server) {
        final params = request.uri.queryParameters;
        if (request.uri.path != '/oauth/dropbox/callback') {
          await _writePlain(request.response, 404, 'Not found');
          continue;
        }
        if (params['error'] != null) {
          await _writeHtml(
            request.response,
            400,
            _callbackPage(
              title: 'Dropbox sign-in cancelled',
              body: 'You can close this window and return to the app.',
            ),
          );
          throw StateError(params['error_description'] ?? params['error']!);
        }
        if (params['state'] != expectedState) {
          await _writePlain(request.response, 400, 'Invalid state');
          throw StateError('OAuth state mismatch.');
        }
        final code = params['code'];
        if (code == null || code.isEmpty) {
          await _writePlain(request.response, 400, 'Missing code');
          throw StateError('Dropbox did not return an authorization code.');
        }
        await _writeHtml(
          request.response,
          200,
          _callbackPage(
            title: 'Connected to Dropbox',
            body:
                'You can close this window and return to Open Metal Fest Admin.',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        return code;
      }
      throw StateError('OAuth server closed unexpectedly.');
    } finally {
      await server.close(force: false);
    }
  }

  static String _callbackPage({required String title, required String body}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #1a1a1a;
      color: #e8e8e8;
      display: flex;
      min-height: 100vh;
      margin: 0;
      align-items: center;
      justify-content: center;
      text-align: center;
      padding: 24px;
    }
    .card {
      max-width: 420px;
      background: #2a2a2a;
      border: 1px solid #404040;
      border-radius: 12px;
      padding: 28px 24px;
    }
    h1 { font-size: 1.35rem; margin: 0 0 12px; color: #fff; }
    p { margin: 0; color: #b0b0b0; line-height: 1.45; }
  </style>
</head>
<body>
  <div class="card">
    <h1>$title</h1>
    <p>$body</p>
  </div>
</body>
</html>
''';
  }

  static Future<void> _writeHtml(
    HttpResponse response,
    int statusCode,
    String html,
  ) async {
    final bytes = utf8.encode(html);
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.html
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set(HttpHeaders.connectionHeader, 'close')
      ..contentLength = bytes.length
      ..add(bytes);
    await response.close();
  }

  static Future<void> _writePlain(
    HttpResponse response,
    int statusCode,
    String text,
  ) async {
    final bytes = utf8.encode(text);
    response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.text
      ..headers.set(HttpHeaders.connectionHeader, 'close')
      ..contentLength = bytes.length
      ..add(bytes);
    await response.close();
  }

  Future<Map<String, String>> _exchangeCode(
    String code,
    String verifier,
    String redirect,
  ) async {
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': appKey,
        'code_verifier': verifier,
        'redirect_uri': redirect,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Token exchange failed: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return {
      'access_token': (data['access_token'] ?? '').toString(),
      'refresh_token': (data['refresh_token'] ?? '').toString(),
    };
  }

  Future<String> _refresh(String refreshToken) async {
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': appKey,
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('Token refresh failed: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['access_token'] ?? '').toString();
  }

  static String _randomVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    return List.generate(64, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _challenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
