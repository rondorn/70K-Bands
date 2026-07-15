import 'dart:convert';
import 'dart:io';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Approved Metal Archives User-Agent only — do not send to other hosts.
const kMetalArchivesUserAgent = '70000tons';

/// Generic Safari UA for all non–Metal Archives requests.
const kSafariUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15';

/// Google Trust Services Root R4 — used by Cloudflare / metal-archives.com.
///
/// Dart's BoringSSL on Windows does not always include (or lazy-load) this
/// root, which causes `CERTIFICATE_VERIFY_FAILED` while MusicBrainz and
/// browsers still work. Trusting it explicitly fixes Discover on Windows.
const _kGtsRootR4Pem = '''
-----BEGIN CERTIFICATE-----
MIICCTCCAY6gAwIBAgINAgPlwGjvYxqccpBQUjAKBggqhkjOPQQDAzBHMQswCQYD
VQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2VzIExMQzEUMBIG
A1UEAxMLR1RTIFJvb3QgUjQwHhcNMTYwNjIyMDAwMDAwWhcNMzYwNjIyMDAwMDAw
WjBHMQswCQYDVQQGEwJVUzEiMCAGA1UEChMZR29vZ2xlIFRydXN0IFNlcnZpY2Vz
IExMQzEUMBIGA1UEAxMLR1RTIFJvb3QgUjQwdjAQBgcqhkjOPQIBBgUrgQQAIgNi
AATzdHOnaItgrkO4NcWBMHtLSZ37wWHO5t5GvWvVYRg1rkDdc/eJkTBa6zzuhXyi
QHY7qca4R9gq55KRanPpsXI5nymfopjTX15YhmUPoYRlBtHci8nHc8iMai/lxKvR
HYqjQjBAMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQW
BBSATNbrdP9JNqPV2Py1PsVq8JQdjDAKBggqhkjOPQQDAwNpADBmAjEA6ED/g94D
9J+uHXqnLrmvT/aDHQ4thQEd0dlq7A/Cr8deVl5c1RxYIigL9zC2L7F8AjEA8GE8
p/SgguMh1YQdc4acLa/KNJvxn7kjNuK8YAOdgLOaVsjh4rsUecrNIdSUtUlD
-----END CERTIFICATE-----
''';

/// HTTP client that uses Apple URLSession on iOS/macOS for Metal Archives.
///
/// Cloudflare blocks Dart's socket [HttpClient]; URLSession is accepted.
/// On Windows, Dart/BoringSSL often lacks GTS Root R4 (metal-archives.com),
/// so we add that root explicitly. Always pairs with
/// [kMetalArchivesUserAgent] — never reuse this client for other sites.
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
  if (Platform.isWindows) {
    final context = SecurityContext(withTrustedRoots: true);
    context.setTrustedCertificatesBytes(utf8.encode(_kGtsRootR4Pem.trim()));
    final io = HttpClient(context: context)
      ..userAgent = kMetalArchivesUserAgent;
    return IOClient(io);
  }
  return http.Client();
}
