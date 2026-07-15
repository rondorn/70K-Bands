import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/app_data_paths.dart';
import 'package:promoter_admin/src/services/platform_http.dart';

/// In-memory + on-disk cache for Dropbox share-link / HTTP text bodies.
///
/// Writes should call [putCachedUrlText] so subsequent reads are instant.
class UrlTextCache {
  static final Map<String, String> _memory = {};

  static String cacheKey(String url) => normalizeDropboxUrl(url).trim();

  static String? peek(String url) {
    final key = cacheKey(url);
    if (key.isEmpty) return null;
    return _memory[key];
  }

  static Future<Directory> _dir() async {
    final root = await AppDataPaths.localRoot();
    final dir = Directory('${root.path}/url_text_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _fileFor(String key) async {
    final digest = sha256.convert(utf8.encode(key)).toString();
    final dir = await _dir();
    return File('${dir.path}/$digest.txt');
  }

  static Future<String?> readDisk(String url) async {
    final key = cacheKey(url);
    if (key.isEmpty) return null;
    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> put(String url, String text) async {
    final key = cacheKey(url);
    if (key.isEmpty) return;
    _memory[key] = text;
    try {
      final file = await _fileFor(key);
      await file.writeAsString(text);
    } catch (_) {
      // Disk cache is best-effort.
    }
  }

  static Future<void> invalidate(String url) async {
    final key = cacheKey(url);
    if (key.isEmpty) return;
    _memory.remove(key);
    try {
      final file = await _fileFor(key);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Test / diagnostics helper.
  static void clearMemory() => _memory.clear();
}

/// Fetch URL text with Dropbox share-link normalization (dl=0 → raw=1).
///
/// Uses memory then disk cache unless [forceRefresh] is true. On network
/// success (or [putCachedUrlText]), updates both layers.
///
/// When [forceRefresh] is true, skips local cache, asks intermediaries not to
/// reuse a cached response, and appends a one-time query param so Dropbox
/// CDNs cannot serve a stale share-link body. The cache key remains the
/// normalized URL without that param.
Future<String> fetchUrlText(
  String url, {
  Duration timeout = const Duration(seconds: 45),
  bool forceRefresh = false,
}) async {
  final normalized = normalizeDropboxUrl(url);
  if (normalized.isEmpty) {
    throw ArgumentError('URL is required');
  }

  if (!forceRefresh) {
    final memory = UrlTextCache.peek(normalized);
    if (memory != null) return memory;
    final disk = await UrlTextCache.readDisk(normalized);
    if (disk != null) {
      await UrlTextCache.put(normalized, disk);
      return disk;
    }
  } else {
    await UrlTextCache.invalidate(normalized);
  }

  final requestUrl =
      forceRefresh ? cacheBustedUrl(normalized) : normalized;
  final headers = <String, String>{
    'User-Agent': kSafariUserAgent,
    if (forceRefresh) ...{
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    },
  };

  final response = await http
      .get(Uri.parse(requestUrl), headers: headers)
      .timeout(timeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for $normalized');
  }
  // Strip UTF-8 BOM if present.
  var body = response.body;
  if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
    body = body.substring(1);
  }
  await UrlTextCache.put(normalized, body);
  return body;
}

/// Append a unique query param so CDNs treat the request as uncached.
String cacheBustedUrl(String normalizedUrl) {
  final uri = Uri.parse(normalizedUrl);
  final params = Map<String, String>.from(uri.queryParameters);
  params['_'] = DateTime.now().millisecondsSinceEpoch.toString();
  return uri.replace(queryParameters: params).toString();
}

/// Seed / overwrite the cache after a successful Dropbox upload.
Future<void> putCachedUrlText(String url, String text) {
  return UrlTextCache.put(url, text);
}

Future<void> invalidateCachedUrlText(String url) {
  return UrlTextCache.invalidate(url);
}

String normalizeDropboxUrl(String url) {
  var value = url.trim();
  if (value.contains('dl=0')) {
    value = value.replaceAll('dl=0', 'raw=1');
  }
  return value;
}
