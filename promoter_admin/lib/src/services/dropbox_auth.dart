import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/durable_json_store.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dropbox OAuth (PKCE) for the promoter macOS app.
///
/// Redirect URI (must be listed on the Dropbox app):
///   http://127.0.0.1:53682/oauth/dropbox/callback
///
/// macOS sandbox must include `com.apple.security.network.server` so the
/// local callback listener can bind to 127.0.0.1.
///
/// Tokens are stored under `~/Library/Application Support/OpenMetalFestAdmin/`
/// so they survive bundle-id changes and reinstalls (with the home-relative
/// sandbox entitlement).
class DropboxAuth {
  static const appKey = 'ug24jfmymp185wi';
  static const redirectUri = 'http://127.0.0.1:53682/oauth/dropbox/callback';
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

    final authUrl = Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': appKey,
      'response_type': 'code',
      'token_access_type': 'offline',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'redirect_uri': redirectUri,
      'state': state,
      'scope': scopes.join(' '),
    });

    final code = await _waitForCode(authUrl, state);
    final tokens = await _exchangeCode(code, verifier);
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

  Future<String> _waitForCode(Uri authUrl, String expectedState) async {
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
          request.response
            ..statusCode = 404
            ..write('Not found')
            ..close();
          continue;
        }
        if (params['error'] != null) {
          request.response
            ..statusCode = 400
            ..headers.contentType = ContentType.html
            ..write(
              '<html><body><h2>Dropbox sign-in cancelled.</h2>'
              '<p>You can close this window.</p></body></html>',
            );
          await request.response.close();
          throw StateError(params['error_description'] ?? params['error']!);
        }
        if (params['state'] != expectedState) {
          request.response
            ..statusCode = 400
            ..write('Invalid state')
            ..close();
          throw StateError('OAuth state mismatch.');
        }
        final code = params['code'];
        if (code == null || code.isEmpty) {
          request.response
            ..statusCode = 400
            ..write('Missing code')
            ..close();
          throw StateError('Dropbox did not return an authorization code.');
        }
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(
            '<html><body><h2>Connected to Dropbox.</h2>'
            '<p>Return to Open Metal Fest Admin.</p></body></html>',
          );
        await request.response.close();
        return code;
      }
      throw StateError('OAuth server closed unexpectedly.');
    } finally {
      await server.close(force: true);
    }
  }

  Future<Map<String, String>> _exchangeCode(String code, String verifier) async {
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/oauth2/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': appKey,
        'code_verifier': verifier,
        'redirect_uri': redirectUri,
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
