import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/location_parse.dart';
import 'package:promoter_admin/src/services/platform_http.dart';

/// Band discovery from Metal Archives and/or MusicBrainz (parity with web portal).
class BandDiscoverService {
  /// Shared Apple URLSession client for MA HTML only (approved UA).
  http.Client? _htmlClient;

  static final _maBandUrl = RegExp(
    r'https?://(?:www\.)?metal-archives\.com/bands/[^/]+/(\d+)',
    caseSensitive: false,
  );
  static final _maAnyBand = RegExp(
    r'https?://(?:www\.)?metal-archives\.com/bands/',
    caseSensitive: false,
  );
  static final _mbArtistUrl = RegExp(
    r'https?://(?:www\.)?musicbrainz\.org/artist/'
    r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})',
    caseSensitive: false,
  );

  DateTime? _lastMbRequest;

  Future<DiscoverResult> discover({
    String metalArchivesUrl = '',
    String musicBrainzUrl = '',
    String bandName = '',
  }) async {
    final warnings = <String>[];
    final data = <String, String>{};
    final sources = <String>[];

    var maUrl = metalArchivesUrl.trim();
    var mbUrl = musicBrainzUrl.trim();

    if (maUrl.isNotEmpty &&
        _mbArtistUrl.hasMatch(maUrl) &&
        mbUrl.isEmpty) {
      mbUrl = maUrl;
      maUrl = '';
    }

    if (maUrl.isNotEmpty && !_maAnyBand.hasMatch(maUrl)) {
      return DiscoverResult.fail(
        'Metal Archives URL must be a band page on metal-archives.com.',
        warnings,
      );
    }

    if (maUrl.isNotEmpty) {
      try {
        final ma = await _fromMetalArchives(maUrl, bandName);
        data.addAll({
          for (final e in ma.data.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value,
        });
        warnings.addAll(ma.warnings);
        sources.add('metal_archives');
      } catch (e) {
        warnings.add(e.toString());
      }
    }

    if (mbUrl.isNotEmpty) {
      try {
        final mb = await _fromMusicBrainzUrl(
          mbUrl,
          fallbackName: bandName.isNotEmpty
              ? bandName
              : (data['bandName'] ?? ''),
        );
        _mergeMissing(data, mb.data);
        warnings.addAll(mb.warnings);
        sources.add('musicbrainz');
      } catch (e) {
        warnings.add(e.toString());
      }
    } else {
      final resolved =
          (data['bandName'] ?? bandName).trim();
      final needsMb = data['bandName'] == null ||
          ((data['country'] ?? '').isEmpty &&
              (data['genre'] ?? '').isEmpty &&
              (data['officalSite'] ?? '').isEmpty);
      if (needsMb && resolved.isNotEmpty) {
        final mb = await _fromMusicBrainzName(resolved);
        _mergeMissing(data, mb.data);
        warnings.addAll(mb.warnings);
        if ((mb.data['bandName'] ?? '').isNotEmpty) {
          sources.add('musicbrainz');
        }
      }
    }

    if ((data['bandName'] ?? '').isEmpty && bandName.trim().isNotEmpty) {
      data['bandName'] = bandName.trim();
    }

    final name = (data['bandName'] ?? '').trim();
    final latestAlbum = (data['latestAlbum'] ?? '').trim();
    if (name.isNotEmpty) {
      if ((data['wikipedia'] ?? '').isEmpty) {
        data['wikipedia'] = _wikipediaSearch(name);
      }
      data['youtube'] = _youtubeSearch(name, latestAlbum);
    }

    if ((data['bandName'] ?? '').isEmpty) {
      return DiscoverResult.fail(
        'No band data found. Provide a Metal Archives URL, MusicBrainz URL, or band name.',
        warnings,
      );
    }

    data.remove('noteworthy');
    if ((data['genre'] ?? '').isNotEmpty) {
      data['genre'] = data['genre']!.replaceAll(RegExp(r',\s*'), '/');
    }

    return DiscoverResult.ok(
      data: data,
      warnings: warnings,
      source: sources.isEmpty ? 'unknown' : sources.join('+'),
    );
  }

  void _mergeMissing(Map<String, String> target, Map<String, String> incoming) {
    for (final e in incoming.entries) {
      if (e.value.trim().isNotEmpty && (target[e.key] ?? '').isEmpty) {
        target[e.key] = e.value;
      }
    }
  }

  // --- Metal Archives -------------------------------------------------------

  Future<({Map<String, String> data, List<String> warnings})> _fromMetalArchives(
    String url,
    String fallbackName,
  ) async {
    final warnings = <String>[];
    final match = _maBandUrl.firstMatch(url);
    if (match == null) {
      throw StateError(
        'Metal Archives URL must be a band page '
        '(e.g. https://www.metal-archives.com/bands/Vreid/27072)',
      );
    }
    final bandId = match.group(1)!;
    var bandUrl = url.trim();
    if (!bandUrl.toLowerCase().startsWith('http')) {
      bandUrl = 'https://www.metal-archives.com/bands/_/$bandId';
    }

    final data = <String, String>{
      'bandName': '',
      'metalArchives': bandUrl,
      'latestAlbum': '',
      'officalSite': '',
      'imageUrl': '',
      'youtube': '',
      'wikipedia': '',
      'country': '',
      'genre': '',
    };

    final bandHtml = await _fetchHtml(bandUrl);
    final page = _parseMaBandPage(bandHtml, bandUrl);
    data.addAll({
      for (final e in page.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value,
    });

    if ((data['bandName'] ?? '').isEmpty && fallbackName.trim().isNotEmpty) {
      data['bandName'] = fallbackName.trim();
      warnings.add('Band name taken from form input (not found on MA page).');
    } else if ((data['bandName'] ?? '').isEmpty) {
      warnings.add('Could not determine band name from Metal Archives.');
    }

    try {
      final discoUrl =
          'https://www.metal-archives.com/band/discography/id/$bandId/tab/main';
      final latest = _parseLatestFullLength(await _fetchHtml(discoUrl));
      if (latest.isNotEmpty) {
        data['latestAlbum'] = latest;
      } else {
        warnings.add('No full-length releases found in discography.');
      }
    } catch (e) {
      warnings.add('Discography fetch failed: $e');
    }

    try {
      final linksUrl =
          'https://www.metal-archives.com/link/ajax-list/type/band/id/$bandId';
      final official = _parseFirstOfficialLink(await _fetchHtml(linksUrl));
      if (official.isNotEmpty) {
        data['officalSite'] = _stripScheme(official);
      } else {
        warnings.add('No official links found on Metal Archives.');
      }
    } catch (e) {
      warnings.add('Official links fetch failed: $e');
    }

    if ((data['imageUrl'] ?? '').isNotEmpty) {
      data['imageUrl'] = _stripScheme(
        data['imageUrl']!.replaceFirst(RegExp(r'\?\d+$'), ''),
      );
    }

    return (data: data, warnings: warnings);
  }

  Map<String, String> _parseMaBandPage(String html, String bandUrl) {
    var bandName = '';
    final h1 = RegExp(
      r'class="band_name"[^>]*>\s*(?:<a[^>]*>)?([^<]+)',
      caseSensitive: false,
    ).firstMatch(html);
    if (h1 != null) {
      bandName = _decodeHtml(h1.group(1)!.trim());
    }
    if (bandName.isEmpty) {
      final script = RegExp(r'var bandName = "([^"]+)"').firstMatch(html);
      if (script != null) bandName = _decodeHtml(script.group(1)!);
    }

    String dd(String label) {
      final re = RegExp(
        r'<dt[^>]*>\s*' +
            RegExp.escape(label) +
            r'[^<]*</dt>\s*<dd[^>]*>([\s\S]*?)</dd>',
        caseSensitive: false,
      );
      final m = re.firstMatch(html);
      if (m == null) return '';
      return _decodeHtml(
        m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
    }

    var imageUrl = '';
    final logo = RegExp(
      r'id="logo"[^>]*href="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);
    if (logo != null) {
      imageUrl = logo.group(1)!.split('?').first;
    } else {
      final img = RegExp(
        r'id="logo"[\s\S]{0,400}?src="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(html);
      if (img != null) imageUrl = img.group(1)!.split('?').first;
    }

    final country = dd('Country of origin');
    final location = parseMaLocation(dd('Location'), country: country);
    return {
      'bandName': bandName,
      'country': country,
      'genre': dd('Genre'),
      'imageUrl': imageUrl,
      'metalArchives': bandUrl.trim(),
      if (location.city.isNotEmpty) 'city': location.city,
      if (location.state.isNotEmpty) 'state': location.state,
    };
  }

  String _parseLatestFullLength(String html) {
    var latest = '';
    final rows = RegExp(r'<tr[\s\S]*?</tr>', caseSensitive: false).allMatches(html);
    for (final row in rows) {
      final cells = RegExp(r'<td[\s\S]*?</td>', caseSensitive: false)
          .allMatches(row.group(0)!)
          .map((c) => c.group(0)!)
          .toList();
      if (cells.length < 2) continue;
      final typeText = cells[1]
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .trim();
      if (typeText != 'Full-length') continue;
      final link = RegExp(r'<a[^>]*>([^<]+)</a>', caseSensitive: false)
          .firstMatch(cells[0]);
      if (link != null) {
        latest = _decodeHtml(link.group(1)!.trim());
      }
    }
    return latest;
  }

  String _parseFirstOfficialLink(String html) {
    var inOfficial = false;
    final rows = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false)
        .allMatches(html);
    for (final row in rows) {
      final full = row.group(0)!;
      final idMatch = RegExp(r'id="([^"]+)"', caseSensitive: false).firstMatch(full);
      final rowId = idMatch?.group(1) ?? '';
      if (rowId.startsWith('header_Official') &&
          !rowId.toLowerCase().contains('merchandise')) {
        inOfficial = true;
        continue;
      }
      if (rowId.startsWith('header_') && inOfficial) break;
      if (!inOfficial) continue;
      final href = RegExp(r'href="([^"]+)"', caseSensitive: false).firstMatch(full);
      if (href != null) return href.group(1)!.trim();
    }
    return '';
  }

  // --- MusicBrainz ----------------------------------------------------------

  Future<({Map<String, String> data, List<String> warnings})> _fromMusicBrainzUrl(
    String url, {
    required String fallbackName,
  }) async {
    final m = _mbArtistUrl.firstMatch(url.trim());
    if (m == null) {
      throw StateError(
        'MusicBrainz URL must be an artist page '
        '(e.g. https://musicbrainz.org/artist/f291ffa8-891c-46ae-ba5e-fd3c53db56f0)',
      );
    }
    return _fromMusicBrainzArtist(m.group(1)!.toLowerCase(), fallbackName);
  }

  Future<({Map<String, String> data, List<String> warnings})> _fromMusicBrainzName(
    String name,
  ) async {
    final warnings = <String>[];
    final query = Uri.encodeQueryComponent('artist:"$name"');
    final search = await _mbGet('/artist/?query=$query&fmt=json&limit=5');
    final artists = (search['artists'] as List<dynamic>?) ?? const [];
    if (artists.isEmpty) {
      return (data: <String, String>{}, warnings: ["No MusicBrainz artist found for '$name'."]);
    }
    final mbid = (artists.first as Map)['id']?.toString() ?? '';
    if (mbid.isEmpty) {
      return (
        data: <String, String>{},
        warnings: ['MusicBrainz search returned no artist ID.']
      );
    }
    final detail = await _fromMusicBrainzArtist(mbid, name);
    warnings.addAll(detail.warnings);
    if (artists.length > 1) {
      warnings.add(
        "MusicBrainz returned ${artists.length} matches; "
        "using '${detail.data['bandName'] ?? name}'.",
      );
    }
    return (data: detail.data, warnings: warnings);
  }

  Future<({Map<String, String> data, List<String> warnings})> _fromMusicBrainzArtist(
    String mbid,
    String fallbackName,
  ) async {
    final warnings = <String>[];
    final detail = await _mbGet(
      '/artist/$mbid?inc=url-rels+tags+genres+release-groups&fmt=json',
    );

    final bandName =
        (detail['name']?.toString() ?? '').trim().isNotEmpty
            ? detail['name'].toString().trim()
            : fallbackName.trim();
    if (bandName.isEmpty) {
      throw StateError('Could not determine band name from MusicBrainz.');
    }

    final latestAlbum = _latestStudioAlbum(detail);
    if (latestAlbum.$1.isEmpty && latestAlbum.$2.isNotEmpty) {
      warnings.addAll(latestAlbum.$2);
    }

    var wikipedia = _urlForTypes(detail, const ['wikipedia']);
    if (wikipedia.isNotEmpty &&
        !wikipedia.toLowerCase().contains('wikipedia.org')) {
      wikipedia = '';
    }

    var metalArchives = _urlForTypes(detail, const ['metal archives']);
    if (metalArchives.isEmpty) {
      metalArchives = _urlContaining(detail, 'metal-archives.com');
    }

    var official = _urlForTypes(detail, const ['official homepage', 'official site']);
    if (official.isEmpty) {
      official = _urlForTypes(detail, const ['bandcamp']);
    }

    final image = await _resolveMbImage(detail, warnings);

    var location = parseMusicBrainzLocation(detail);
    var state = location.state;
    if (state.isEmpty &&
        (detail['country']?.toString() ?? '').trim().toUpperCase() == 'US') {
      final beginArea = detail['begin-area'];
      final beginId = beginArea is Map ? beginArea['id']?.toString() : null;
      if (beginId != null && beginId.isNotEmpty) {
        state = await _stateFromAreaHierarchy(beginId);
      }
    }

    final data = <String, String>{
      'bandName': bandName,
      'musicBrainz': 'https://musicbrainz.org/artist/$mbid',
      'country': _expandCountry(detail['country']?.toString() ?? ''),
      'genre': _formatGenre(detail),
      'officalSite': _stripScheme(official),
      'wikipedia': wikipedia,
      'youtube': '',
      'metalArchives': metalArchives,
      'imageUrl': _stripScheme(image),
      'latestAlbum': latestAlbum.$1,
      if (location.city.isNotEmpty) 'city': location.city,
      if (state.isNotEmpty) 'state': state,
    };

    if (data['country']!.isEmpty) {
      warnings.add('Country not listed on MusicBrainz.');
    }
    if (data['genre']!.isEmpty) {
      warnings.add('Genre/tags not found on MusicBrainz.');
    }
    if (data['officalSite']!.isEmpty) {
      warnings.add('No official homepage or Bandcamp link on MusicBrainz.');
    }
    if (data['wikipedia']!.isEmpty) {
      warnings.add('No English Wikipedia link on MusicBrainz (Wikidata-only).');
    }
    if (data['metalArchives']!.isEmpty) {
      warnings.add('No Metal Archives link on MusicBrainz.');
    }

    return (data: data, warnings: warnings);
  }

  /// Walk MusicBrainz area parents to find a US state subdivision.
  Future<String> _stateFromAreaHierarchy(
    String areaId, {
    int maxDepth = 6,
  }) async {
    final queue = <String>[areaId];
    final seen = <String>{};

    while (queue.isNotEmpty && seen.length < maxDepth) {
      final currentId = queue.removeAt(0);
      if (currentId.isEmpty || seen.contains(currentId)) continue;
      seen.add(currentId);

      Map<String, dynamic> area;
      try {
        area = await _mbGet('/area/$currentId?inc=area-rels&fmt=json');
      } catch (_) {
        continue;
      }

      final areaType = (area['type']?.toString() ?? '').trim().toLowerCase();
      final areaName = (area['name']?.toString() ?? '').trim();

      if (areaType == 'subdivision') {
        final code = stateNameToCode(areaName);
        if (code.isNotEmpty) return code;
      }

      for (final isoCode in (area['iso-3166-2-codes'] as List<dynamic>?) ?? const []) {
        if (isoCode is! String) continue;
        if (!isoCode.toUpperCase().startsWith('US-')) continue;
        final suffix = isoCode.split('-').last.trim().toUpperCase();
        if (suffix.length == 2) return suffix;
      }

      for (final rel in (area['relations'] as List<dynamic>?) ?? const []) {
        if (rel is! Map) continue;
        if (rel['type'] != 'part of') continue;
        final parent = rel['area'];
        if (parent is! Map) continue;
        final parentId = parent['id']?.toString() ?? '';
        if (parentId.isEmpty) continue;

        final parentType =
            (parent['type']?.toString() ?? '').trim().toLowerCase();
        final parentName = (parent['name']?.toString() ?? '').trim();
        if (parentType == 'subdivision') {
          final code = stateNameToCode(parentName);
          if (code.isNotEmpty) return code;
        }
        for (final isoCode
            in (parent['iso-3166-2-codes'] as List<dynamic>?) ?? const []) {
          if (isoCode is! String) continue;
          if (!isoCode.toUpperCase().startsWith('US-')) continue;
          final suffix = isoCode.split('-').last.trim().toUpperCase();
          if (suffix.length == 2) return suffix;
        }
        queue.add(parentId);
      }
    }
    return '';
  }

  Future<Map<String, dynamic>> _mbGet(String path) async {
    await _rateLimitMb();
    final url = 'https://musicbrainz.org/ws/2$path';
    final resp = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': kSafariUserAgent,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError('MusicBrainz HTTP ${resp.statusCode}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<void> _rateLimitMb() async {
    final last = _lastMbRequest;
    if (last != null) {
      final wait = const Duration(milliseconds: 1100) -
          DateTime.now().difference(last);
      if (!wait.isNegative) await Future<void>.delayed(wait);
    }
    _lastMbRequest = DateTime.now();
  }

  (String, List<String>) _latestStudioAlbum(Map<String, dynamic> detail) {
    final groups = (detail['release-groups'] as List<dynamic>?) ?? const [];
    var albums = groups.whereType<Map>().where((rg) {
      if (rg['primary-type'] != 'Album') return false;
      final secondary = (rg['secondary-types'] as List<dynamic>?) ?? const [];
      return !secondary.contains('Compilation') && !secondary.contains('Live');
    }).toList();
    if (albums.isEmpty) {
      albums = groups
          .whereType<Map>()
          .where((rg) => rg['primary-type'] == 'Album')
          .toList();
    }
    if (albums.isEmpty) {
      return ('', ['No album release groups found on MusicBrainz.']);
    }
    albums.sort((a, b) {
      final da = (a['first-release-date'] ?? '').toString();
      final db = (b['first-release-date'] ?? '').toString();
      return db.compareTo(da);
    });
    final title = (albums.first['title'] ?? '').toString().trim();
    if (title.isEmpty) {
      return ('', ['Latest album title missing on MusicBrainz.']);
    }
    return (title, const []);
  }

  Future<String> _resolveMbImage(
    Map<String, dynamic> detail,
    List<String> warnings,
  ) async {
    // Prefer Cover Art Archive for latest album (Bandcamp scrape is heavier).
    final groups = (detail['release-groups'] as List<dynamic>?) ?? const [];
    final albums = groups
        .whereType<Map>()
        .where((rg) => rg['primary-type'] == 'Album')
        .toList()
      ..sort((a, b) {
        final da = (a['first-release-date'] ?? '').toString();
        final db = (b['first-release-date'] ?? '').toString();
        return db.compareTo(da);
      });
    if (albums.isEmpty) {
      warnings.add('No Bandcamp or album cover image found.');
      return '';
    }
    final rgId = albums.first['id']?.toString() ?? '';
    if (rgId.isEmpty) return '';
    try {
      await _rateLimitMb();
      final resp = await http.get(
        Uri.parse('https://coverartarchive.org/release-group/$rgId'),
        headers: {
          'User-Agent': kSafariUserAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));
      if (resp.statusCode < 200 || resp.statusCode >= 300) return '';
      final payload = jsonDecode(resp.body) as Map<String, dynamic>;
      for (final image in (payload['images'] as List<dynamic>? ?? const [])) {
        if (image is! Map) continue;
        if (image['front'] == true) {
          final url = (image['image'] ??
                  (image['thumbnails'] is Map
                      ? image['thumbnails']['large']
                      : ''))
              .toString();
          if (url.isNotEmpty) {
            warnings.add('Using latest album cover from Cover Art Archive.');
            return url;
          }
        }
      }
    } catch (_) {}
    warnings.add('No Bandcamp or album cover image found.');
    return '';
  }

  String _urlForTypes(Map<String, dynamic> detail, List<String> types) {
    final lowered = types.map((t) => t.toLowerCase()).toSet();
    for (final rel in (detail['relations'] as List<dynamic>? ?? const [])) {
      if (rel is! Map) continue;
      final relType = (rel['type'] ?? '').toString().toLowerCase();
      final resource = ((rel['url'] is Map) ? rel['url']['resource'] : null)
              ?.toString()
              .trim() ??
          '';
      if (lowered.contains(relType) && resource.isNotEmpty) return resource;
    }
    return '';
  }

  String _urlContaining(Map<String, dynamic> detail, String needle) {
    final n = needle.toLowerCase();
    for (final rel in (detail['relations'] as List<dynamic>? ?? const [])) {
      if (rel is! Map) continue;
      final resource = ((rel['url'] is Map) ? rel['url']['resource'] : null)
              ?.toString()
              .trim() ??
          '';
      if (resource.toLowerCase().contains(n)) return resource;
    }
    return '';
  }

  String _formatGenre(Map<String, dynamic> detail) {
    String cap(String value) {
      final parts = value.split('/').map((seg) {
        return seg
            .trim()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
            .join(' ');
      });
      return parts.join('/');
    }

    final genres = (detail['genres'] as List<dynamic>?) ?? const [];
    if (genres.isNotEmpty) {
      final ranked = [...genres.whereType<Map>()]
        ..sort((a, b) =>
            ((b['count'] as num?) ?? 0).compareTo((a['count'] as num?) ?? 0));
      return ranked
          .take(3)
          .map((g) => cap((g['name'] ?? '').toString()))
          .where((s) => s.isNotEmpty)
          .join(' / ');
    }
    final tags = (detail['tags'] as List<dynamic>?) ?? const [];
    if (tags.isNotEmpty) {
      final ranked = [...tags.whereType<Map>()]
        ..sort((a, b) =>
            ((b['count'] as num?) ?? 0).compareTo((a['count'] as num?) ?? 0));
      return ranked
          .take(3)
          .map((t) => cap((t['name'] ?? '').toString()))
          .where((s) => s.isNotEmpty)
          .join(' / ');
    }
    return '';
  }

  // --- HTTP / helpers -------------------------------------------------------

  http.Client _maHtmlClient() =>
      _htmlClient ??= createMetalArchivesHttpClient();

  bool _looksLikeCloudflareChallenge(String body) {
    final lower = body.toLowerCase();
    return lower.contains('just a moment...') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('cdn-cgi/challenge');
  }

  Future<String> _fetchHtml(String url) async {
    Object? lastError;

    try {
      final resp = await _maHtmlClient()
          .get(
            Uri.parse(url),
            headers: {'User-Agent': kMetalArchivesUserAgent},
          )
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode >= 200 &&
          resp.statusCode < 300 &&
          resp.body.length >= 500 &&
          !_looksLikeCloudflareChallenge(resp.body)) {
        return resp.body;
      }
      lastError =
          'HTTP ${resp.statusCode} (${resp.body.length} bytes)';
    } catch (e) {
      lastError = e;
    }

    // Desktop fallback: curl with the approved UA. iOS has no curl —
    // URLSession + 70000tons is the primary path there.
    if (Platform.isMacOS || Platform.isLinux) {
      try {
        final result = await Process.run(
          'curl',
          [
            '-sL',
            '--max-time',
            '25',
            '-A',
            kMetalArchivesUserAgent,
            url,
          ],
        );
        final out = (result.stdout as String?) ?? '';
        if (result.exitCode == 0 &&
            out.length >= 500 &&
            !_looksLikeCloudflareChallenge(out)) {
          return out;
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw StateError(
      'Metal Archives returned a blocked or empty response'
      '${lastError == null ? '' : ' ($lastError)'}.',
    );
  }

  String _stripScheme(String url) {
    var v = url.trim();
    if (v.toLowerCase().startsWith('https://')) return v.substring(8);
    if (v.toLowerCase().startsWith('http://')) return v.substring(7);
    return v;
  }

  String _wikipediaSearch(String name) =>
      'https://en.wikipedia.org/wiki/Special:Search/${Uri.encodeComponent(name)}';

  String _youtubeSearch(String name, String album) {
    final band = Uri.encodeComponent(name);
    final suffix = album.trim().isEmpty
        ? band
        : '$band+${Uri.encodeComponent(album.trim())}';
    return 'https://www.youtube.com/results?search_query=official+music+video+$suffix';
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }

  String _expandCountry(String code) {
    final raw = code.trim();
    if (raw.isEmpty) return '';
    if (raw.length > 3 || raw.contains(' ')) return raw;
    const map = {
      'US': 'United States',
      'GB': 'United Kingdom',
      'CA': 'Canada',
      'DE': 'Germany',
      'NO': 'Norway',
      'SE': 'Sweden',
      'FI': 'Finland',
      'DK': 'Denmark',
      'FR': 'France',
      'NL': 'Netherlands',
      'BE': 'Belgium',
      'AT': 'Austria',
      'CH': 'Switzerland',
      'IT': 'Italy',
      'ES': 'Spain',
      'PT': 'Portugal',
      'PL': 'Poland',
      'CZ': 'Czechia',
      'AU': 'Australia',
      'NZ': 'New Zealand',
      'JP': 'Japan',
      'BR': 'Brazil',
      'MX': 'Mexico',
      'IE': 'Ireland',
      'IS': 'Iceland',
      'RU': 'Russia',
      'UA': 'Ukraine',
      'GR': 'Greece',
      'TR': 'Turkey',
      'CL': 'Chile',
      'AR': 'Argentina',
      'XW': 'Worldwide',
    };
    return map[raw.toUpperCase()] ?? raw;
  }
}

class DiscoverResult {
  DiscoverResult._({
    required this.ok,
    this.data = const {},
    this.warnings = const [],
    this.source = '',
    this.error = '',
  });

  factory DiscoverResult.ok({
    required Map<String, String> data,
    required List<String> warnings,
    required String source,
  }) =>
      DiscoverResult._(
        ok: true,
        data: data,
        warnings: warnings,
        source: source,
      );

  factory DiscoverResult.fail(String error, List<String> warnings) =>
      DiscoverResult._(ok: false, error: error, warnings: warnings);

  final bool ok;
  final Map<String, String> data;
  final List<String> warnings;
  final String source;
  final String error;
}
