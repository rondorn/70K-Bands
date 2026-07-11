import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;

/// Approved Metal Archives User-Agent only — do not send to other hosts.
const kMetalArchivesUserAgent = '70000tons';

/// Generic Safari UA for all non–Metal Archives requests.
const kSafariUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15';

/// HTTP client that uses Apple URLSession on iOS/macOS for Metal Archives.
///
/// Cloudflare blocks Dart's socket [HttpClient]; URLSession is accepted.
/// Always pairs with [kMetalArchivesUserAgent] — never reuse this client
/// for other sites.
http.Client createMetalArchivesHttpClient() {
  final headers = {
    'User-Agent': kMetalArchivesUserAgent,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };
  if (Platform.isIOS || Platform.isMacOS) {
    final config = URLSessionConfiguration.ephemeralSessionConfiguration()
      ..httpAdditionalHeaders = headers;
    return CupertinoClient.fromSessionConfiguration(config);
  }
  return http.Client();
}
