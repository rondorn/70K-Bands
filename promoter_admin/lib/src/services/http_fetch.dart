import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/platform_http.dart';

/// Fetch URL text with Dropbox share-link normalization (dl=0 → raw=1).
Future<String> fetchUrlText(String url, {Duration timeout = const Duration(seconds: 45)}) async {
  final normalized = normalizeDropboxUrl(url);
  if (normalized.isEmpty) {
    throw ArgumentError('URL is required');
  }
  final response = await http
      .get(
        Uri.parse(normalized),
        headers: {'User-Agent': kSafariUserAgent},
      )
      .timeout(timeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} for $normalized');
  }
  // Strip UTF-8 BOM if present.
  var body = response.body;
  if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
    body = body.substring(1);
  }
  return body;
}

String normalizeDropboxUrl(String url) {
  var value = url.trim();
  if (value.contains('dl=0')) {
    value = value.replaceAll('dl=0', 'raw=1');
  }
  return value;
}
