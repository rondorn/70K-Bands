import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/artists_export/artist_export_entry.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/platform_http.dart';

class LogoFetcher {
  const LogoFetcher._();

  static Future<Uint8List?> fetchBytes(String url) async {
    final normalized = normalizeDropboxUrl(url.trim());
    if (normalized.isEmpty) return null;
    try {
      final response = await http
          .get(
            Uri.parse(normalized),
            headers: {'User-Agent': kSafariUserAgent},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (response.bodyBytes.isEmpty) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  /// Downloads band logos with limited concurrency. Failures leave [imageBytes] null.
  static Future<List<ArtistExportEntry>> attachBandLogos(
    List<ArtistExportEntry> entries, {
    int concurrency = 8,
  }) async {
    if (entries.isEmpty) return entries;
    final results = List<ArtistExportEntry>.from(entries);
    var next = 0;

    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= results.length) return;
        final entry = results[index];
        if (entry.imageUrl.isEmpty) continue;
        final bytes = await fetchBytes(entry.imageUrl);
        if (bytes != null) {
          results[index] = entry.copyWith(imageBytes: bytes);
        }
      }
    }

    final workers = List.generate(
      concurrency.clamp(1, entries.length),
      (_) => worker(),
    );
    await Future.wait(workers);
    return results;
  }
}

String logoMimeType(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('.jpg') || lower.contains('.jpeg')) return 'image/jpeg';
  if (lower.contains('.gif')) return 'image/gif';
  if (lower.contains('.webp')) return 'image/webp';
  return 'image/png';
}
