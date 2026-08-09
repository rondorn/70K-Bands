import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/artists_export/artist_export_entry.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/platform_http.dart';

class LogoFetcher {
  const LogoFetcher._();

  /// Default parallel downloads. Metal Archives rate-limits higher concurrency
  /// (HTTP 429), which previously left later logos as name fallbacks.
  static const int defaultConcurrency = 2;

  static const int defaultMaxAttempts = 5;

  /// Inclusive random pause before each logo request (helps avoid MA 429s).
  static const int defaultInterRequestDelayMinMs = 150;
  static const int defaultInterRequestDelayMaxMs = 400;

  static final Random _random = Random();

  static bool isMetalArchivesHost(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host == 'metal-archives.com' ||
        host.endsWith('.metal-archives.com');
  }

  /// Absolute URL for fetching: scheme if missing, then Dropbox share normalize.
  static String normalizeFetchUrl(String url) {
    var value = url.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      value = 'https://$value';
    }
    return normalizeDropboxUrl(value);
  }

  static Future<Uint8List?> fetchBytes(
    String url, {
    http.Client? client,
    int maxAttempts = defaultMaxAttempts,
    Duration Function(int attempt)? backoff,
  }) async {
    final normalized = normalizeFetchUrl(url);
    if (normalized.isEmpty) return null;

    final ownsClient = client == null;
    final resolvedClient = client ??
        (isMetalArchivesHost(normalized)
            ? createMetalArchivesHttpClient()
            : http.Client());
    try {
      return await _fetchWithRetries(
        normalized,
        client: resolvedClient,
        maxAttempts: maxAttempts,
        backoff: backoff,
      );
    } finally {
      if (ownsClient) resolvedClient.close();
    }
  }

  /// Downloads band logos with limited concurrency. Failures leave [imageBytes]
  /// null. Retries transient Metal Archives rate limits (429) with backoff.
  ///
  /// Inserts a random pause before each request ([interRequestDelay], default
  /// 150–400 ms) so large lineups stay under Metal Archives rate limits.
  static Future<List<ArtistExportEntry>> attachBandLogos(
    List<ArtistExportEntry> entries, {
    int concurrency = defaultConcurrency,
    http.Client? client,
    http.Client? metalArchivesClient,
    int maxAttempts = defaultMaxAttempts,
    Duration Function(int attempt)? backoff,
    Duration Function()? interRequestDelay,
  }) async {
    if (entries.isEmpty) return entries;
    final results = List<ArtistExportEntry>.from(entries);
    var next = 0;
    final pauseBetween = interRequestDelay ?? _randomInterRequestDelay;

    final ownsGeneric = client == null;
    final genericClient = client ?? http.Client();

    final needsMa = entries.any(
      (e) => isMetalArchivesHost(normalizeFetchUrl(e.imageUrl)),
    );
    final ownsMa = metalArchivesClient == null && needsMa;
    final maClient = metalArchivesClient ??
        (needsMa ? createMetalArchivesHttpClient() : null);

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= results.length) return;
        final entry = results[index];
        if (entry.imageUrl.isEmpty) continue;
        final url = normalizeFetchUrl(entry.imageUrl);
        if (url.isEmpty) continue;
        final pause = pauseBetween();
        if (pause > Duration.zero) {
          await Future<void>.delayed(pause);
        }
        final useMa = isMetalArchivesHost(url);
        final bytes = await _fetchWithRetries(
          url,
          client: useMa ? (maClient ?? genericClient) : genericClient,
          maxAttempts: maxAttempts,
          backoff: backoff,
        );
        if (bytes != null) {
          results[index] = entry.copyWith(imageBytes: bytes);
        }
      }
    }

    try {
      final workers = List.generate(
        concurrency.clamp(1, entries.length),
        (_) => worker(),
      );
      await Future.wait(workers);
    } finally {
      if (ownsGeneric) genericClient.close();
      if (ownsMa) maClient?.close();
    }
    return results;
  }

  static Future<Uint8List?> _fetchWithRetries(
    String url, {
    required http.Client client,
    required int maxAttempts,
    Duration Function(int attempt)? backoff,
  }) async {
    var delay = const Duration(milliseconds: 500);
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await client
            .get(Uri.parse(url), headers: _headersFor(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.bodyBytes.isEmpty) return null;
          return response.bodyBytes;
        }
        if (!_shouldRetryStatus(response.statusCode) ||
            attempt == maxAttempts) {
          return null;
        }
        final wait = backoff?.call(attempt) ??
            _retryAfterDelay(response) ??
            delay;
        await Future<void>.delayed(wait);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(500, 8000),
        );
      } catch (_) {
        if (attempt == maxAttempts) return null;
        await Future<void>.delayed(backoff?.call(attempt) ?? delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * 2).clamp(500, 8000),
        );
      }
    }
    return null;
  }

  static Map<String, String> _headersFor(String url) {
    if (isMetalArchivesHost(url)) {
      return {
        'User-Agent': kMetalArchivesUserAgent,
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        'Referer': 'https://www.metal-archives.com/',
      };
    }
    return {'User-Agent': kSafariUserAgent};
  }

  static bool _shouldRetryStatus(int code) =>
      code == 429 || code == 502 || code == 503 || code == 504;

  static Duration? _retryAfterDelay(http.Response response) {
    final raw = response.headers['retry-after'];
    if (raw == null) return null;
    final seconds = int.tryParse(raw.trim());
    if (seconds == null) return null;
    return Duration(seconds: seconds.clamp(1, 60));
  }

  static Duration _randomInterRequestDelay() {
    final span =
        defaultInterRequestDelayMaxMs - defaultInterRequestDelayMinMs + 1;
    final ms = defaultInterRequestDelayMinMs + _random.nextInt(span);
    return Duration(milliseconds: ms);
  }
}

String logoMimeType(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('.jpg') || lower.contains('.jpeg')) return 'image/jpeg';
  if (lower.contains('.gif')) return 'image/gif';
  if (lower.contains('.webp')) return 'image/webp';
  return 'image/png';
}
