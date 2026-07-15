import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/location_parse.dart';
import 'package:promoter_admin/src/services/ma_web_html_fetch.dart';
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
    final inputName = bandName.trim();

    if (maUrl.isNotEmpty &&
        _mbArtistUrl.hasMatch(maUrl) &&
        mbUrl.isEmpty) {
      mbUrl = maUrl;
      maUrl = '';
    }

    // Name-only: MA exact → unique use / multi reject; else MB exact same rules.
    if (maUrl.isEmpty && mbUrl.isEmpty) {
      if (inputName.isEmpty) {
        return DiscoverResult.fail(
          'Enter a Metal Archives URL, MusicBrainz URL, or band name.',
          warnings,
        );
      }
      return _discoverByExactName(inputName);
    }

    if (maUrl.isNotEmpty && !_maAnyBand.hasMatch(maUrl)) {
      return DiscoverResult.fail(
        'Metal Archives URL must be a band page on metal-archives.com.',
        warnings,
      );
    }

    if (maUrl.isNotEmpty) {
      try {
        final ma = await _fromMetalArchives(maUrl, inputName);
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

    // MusicBrainz only when the user pasted an MB URL (never as silent fill-in
    // after Metal Archives already resolved the band).
    if (mbUrl.isNotEmpty) {
      try {
        final mb = await _fromMusicBrainzUrl(
          mbUrl,
          fallbackName: inputName.isNotEmpty
              ? inputName
              : (data['bandName'] ?? ''),
        );
        _mergeMissing(data, mb.data);
        warnings.addAll(mb.warnings);
        sources.add('musicbrainz');
      } catch (e) {
        warnings.add(e.toString());
      }
    }

    if ((data['bandName'] ?? '').isEmpty && inputName.isNotEmpty) {
      data['bandName'] = inputName;
    }

    return _finalizeDiscover(data, warnings, sources);
  }

  Future<DiscoverResult> _discoverByExactName(String name) async {
    final warnings = <String>[];
    final data = <String, String>{};
    final sources = <String>[];

    List<MaBandSearchHit> maHits;
    try {
      maHits = await _searchMetalArchivesExact(name);
    } catch (e) {
      return DiscoverResult.fail(
        'Metal Archives search failed ($e). Try again, or paste a band URL.',
        warnings,
      );
    }

    if (maHits.length > 1) {
      return DiscoverResult.fail(
        _ambiguousMaMessage(name, maHits.length),
        warnings,
        pickListUrl: metalArchivesSearchUrl(name),
        pickListLabel: 'Open Metal Archives results',
      );
    }

    if (maHits.length == 1) {
      try {
        final ma = await _fromMetalArchives(maHits.first.url, name);
        data.addAll({
          for (final e in ma.data.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value,
        });
        warnings.addAll(ma.warnings);
        sources.add('metal_archives');
      } catch (e) {
        return DiscoverResult.fail(
          'Found "$name" on Metal Archives but could not load the page ($e).',
          warnings,
        );
      }
      // Unique MA hit → stop here. Do not call MusicBrainz.
      return _finalizeDiscover(data, warnings, sources);
    }

    // Zero MA hits → MusicBrainz exact name.
    final mb = await _lookupMusicBrainzExactName(name);
    warnings.addAll(mb.warnings);
    if (mb.status == ExactNameStatus.unique) {
      data.addAll({
        for (final e in mb.data.entries)
          if (e.value.trim().isNotEmpty) e.key: e.value,
      });
      sources.add('musicbrainz');
      return _finalizeDiscover(data, warnings, sources);
    }
    if (mb.status == ExactNameStatus.ambiguous) {
      return DiscoverResult.fail(
        'No Metal Archives match, but MusicBrainz has '
        '${mb.matchCount} artists matching "$name". '
        'Open the results, pick the correct artist, paste that URL into '
        'MusicBrainz below, then Discover again.',
        warnings,
        pickListUrl: musicBrainzSearchUrl(name),
        pickListLabel: 'Open MusicBrainz results',
      );
    }
    if (mb.status == ExactNameStatus.error) {
      return DiscoverResult.fail(
        'No exact match on Metal Archives, and MusicBrainz lookup failed'
        '${mb.error.isEmpty ? '' : ' (${mb.error})'}. '
        'Paste a band URL, or try again.',
        warnings,
      );
    }

    return DiscoverResult.fail(
      '"$name" does not appear to exist on Metal Archives or MusicBrainz '
      '(tight name match: case and accents like ü/u may differ). '
      'Check the spelling, or paste a Metal Archives / MusicBrainz URL.',
      warnings,
    );
  }

  DiscoverResult _finalizeDiscover(
    Map<String, String> data,
    List<String> warnings,
    List<String> sources,
  ) {
    final name = (data['bandName'] ?? '').trim();
    final latestAlbum = (data['latestAlbum'] ?? '').trim();
    if (name.isNotEmpty) {
      if ((data['wikipedia'] ?? '').isEmpty) {
        data['wikipedia'] = _wikipediaSearch(name);
      }
      data['youtube'] = _youtubeSearch(name, latestAlbum);
    }

    if (name.isEmpty) {
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
      source: _formatDiscoverSource(sources),
    );
  }

  String _formatDiscoverSource(List<String> sources) {
    if (sources.isEmpty) return 'unknown';
    return sources
        .map((s) => switch (s) {
              'metal_archives' => 'Metal Archives',
              'musicbrainz' => 'MusicBrainz',
              _ => s,
            })
        .join(' + ');
  }

  String _ambiguousMaMessage(String name, int count) {
    return 'Metal Archives has $count bands matching "$name". '
        'Open the results, pick the correct band, paste that URL into '
        'Metal Archives below, then Discover again.';
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

  /// Open Metal Archives name search, then keep only tight Discover matches
  /// (case + accent fold; e.g. ü≈u, ñ≈n). Never uses MA "exact" search — that
  /// misses ASCII vs accented spellings.
  Future<List<MaBandSearchHit>> _searchMetalArchivesExact(String name) async {
    final queries = <String>{name};
    final folded = foldBandNameForMatch(name);
    if (folded.isNotEmpty) queries.add(folded);

    final byUrl = <String, MaBandSearchHit>{};
    for (final query in queries) {
      for (final hit in await _fetchMetalArchivesSearchRows(query)) {
        if (!bandNamesEqualForDiscover(hit.name, name)) continue;
        byUrl.putIfAbsent(hit.url, () => hit);
      }
    }
    return byUrl.values.toList();
  }

  Future<List<MaBandSearchHit>> _fetchMetalArchivesSearchRows(
    String query,
  ) async {
    final uri = Uri.https(
      'www.metal-archives.com',
      '/search/ajax-advanced/searching/bands/',
      {
        'exactBandMatch': '0',
        'bandName': query,
        'sEcho': '1',
        'iColumns': '6',
        'iDisplayStart': '0',
        'iDisplayLength': '200',
      },
    );
    final body = await _fetchMaBody(uri.toString(), expectJson: true);
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final rows = (payload['aaData'] as List<dynamic>?) ?? const [];
    final hits = <MaBandSearchHit>[];
    for (final row in rows) {
      if (row is! List) continue;
      final hit = parseMetalArchivesSearchHit(row);
      if (hit != null) hits.add(hit);
    }
    return hits;
  }

  /// MusicBrainz open search, then keep only tight Discover matches on
  /// name / sort-name (case + accent fold). Never auto-picks among duplicates.
  Future<ExactNameLookup> _lookupMusicBrainzExactName(String name) async {
    final warnings = <String>[];
    try {
      final queries = <String>{name};
      final folded = foldBandNameForMatch(name);
      if (folded.isNotEmpty) queries.add(folded);

      final exactById = <String, Map>{};
      for (final q in queries) {
        final encoded = Uri.encodeQueryComponent(q);
        final search =
            await _mbGet('/artist/?query=$encoded&fmt=json&limit=25');
        final artists = (search['artists'] as List<dynamic>?) ?? const [];
        for (final raw in artists) {
          if (raw is! Map) continue;
          if (!musicBrainzArtistMatchesExactName(raw, name)) continue;
          final id = (raw['id'] ?? '').toString();
          if (id.isEmpty) continue;
          exactById[id] = raw;
        }
      }
      final exact = exactById.values.toList();
      if (exact.isEmpty) {
        return ExactNameLookup.notFound(warnings);
      }
      if (exact.length > 1) {
        return ExactNameLookup.ambiguous(exact.length, warnings);
      }
      final mbid = exact.first['id']?.toString() ?? '';
      if (mbid.isEmpty) {
        return ExactNameLookup.error(
          'MusicBrainz search returned no artist ID.',
          warnings,
        );
      }
      final detail = await _fromMusicBrainzArtist(mbid, name);
      warnings.addAll(detail.warnings);
      return ExactNameLookup.unique(detail.data, warnings);
    } catch (e) {
      return ExactNameLookup.error(e.toString(), warnings);
    }
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

    final image = await _resolveMbImage(detail);

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

  Future<String> _resolveMbImage(Map<String, dynamic> detail) async {
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
            return url;
          }
        }
      }
    } catch (_) {}
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
    // Real MA pages embed Cloudflare's jsd script (`/cdn-cgi/challenge-platform/...`).
    // That is not a block page — only treat interstitials as blocked.
    if (lower.contains('class="band_name"') ||
        lower.contains('var bandname =') ||
        lower.contains('id="band_stats"') ||
        lower.contains('class="display discog"')) {
      return false;
    }
    return lower.contains('just a moment...') ||
        lower.contains('<title>just a moment') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('checking your browser') ||
        lower.contains('cdn-cgi/challenge-platform/h/');
  }

  Future<String> _fetchHtml(String url) =>
      _fetchMaBody(url, expectJson: false);

  bool _isAcceptableMaBody(String body, {required bool expectJson}) {
    if (_looksLikeCloudflareChallenge(body)) return false;
    if (expectJson) {
      final trimmed = body.trimLeft();
      return trimmed.startsWith('{') || trimmed.startsWith('[');
    }
    return body.length >= 500;
  }

  Future<String> _fetchMaBody(
    String url, {
    required bool expectJson,
  }) async {
    Object? lastError;

    // iOS WKWebView / Windows WebView2: run Cloudflare's JS challenge.
    // Plain HttpClient/curl get HTTP 403 from Cloudflare on Windows.
    if (MaWebHtmlFetch.isSupported) {
      try {
        final html = await MaWebHtmlFetch.fetchHtml(
          url,
          expectJson: expectJson,
        ).timeout(const Duration(seconds: 50));
        if (_isAcceptableMaBody(html, expectJson: expectJson)) {
          return html;
        }
        lastError = expectJson
            ? 'Browser fetch returned non-JSON or blocked body'
            : 'Browser fetch returned blocked or short HTML';
      } catch (e) {
        lastError = e;
      }
    }

    try {
      final resp = await _maHtmlClient()
          .get(
            Uri.parse(url),
            headers: {'User-Agent': kMetalArchivesUserAgent},
          )
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode >= 200 &&
          resp.statusCode < 300 &&
          _isAcceptableMaBody(resp.body, expectJson: expectJson)) {
        return resp.body;
      }
      lastError =
          'HTTP ${resp.statusCode} (${resp.body.length} bytes)';
    } catch (e) {
      lastError = e;
    }

    // Desktop curl fallback (macOS/Linux). Helps with TLS quirks; Cloudflare
    // blocks it on Windows, so Windows relies on WebView2 above instead.
    if (Platform.isMacOS || Platform.isLinux) {
      final fromCurl = await _fetchMaBodyViaCurl(url, expectJson: expectJson);
      if (fromCurl.body != null) return fromCurl.body!;
      lastError = fromCurl.error ?? lastError;
    }

    throw StateError(
      'Metal Archives returned a blocked or empty response ($lastError).',
    );
  }

  Future<({String? body, Object? error})> _fetchMaBodyViaCurl(
    String url, {
    required bool expectJson,
  }) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'curl.exe' : 'curl',
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
          _isAcceptableMaBody(out, expectJson: expectJson)) {
        return (body: out, error: null);
      }
      return (
        body: null,
        error: result.exitCode != 0
            ? 'curl exit ${result.exitCode}'
            : 'curl returned blocked or short body (${out.length} bytes)',
      );
    } catch (e) {
      return (body: null, error: e);
    }
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
    this.pickListUrl = '',
    this.pickListLabel = '',
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

  factory DiscoverResult.fail(
    String error,
    List<String> warnings, {
    String pickListUrl = '',
    String pickListLabel = '',
  }) =>
      DiscoverResult._(
        ok: false,
        error: error,
        warnings: warnings,
        pickListUrl: pickListUrl,
        pickListLabel: pickListLabel,
      );

  final bool ok;
  final Map<String, String> data;
  final List<String> warnings;
  final String source;
  final String error;

  /// Browser link to the open search results when Discover refuses to choose.
  final String pickListUrl;
  final String pickListLabel;
}

enum ExactNameStatus { unique, ambiguous, notFound, error }

class ExactNameLookup {
  ExactNameLookup._({
    required this.status,
    this.data = const {},
    this.warnings = const [],
    this.matchCount = 0,
    this.error = '',
  });

  factory ExactNameLookup.unique(
    Map<String, String> data,
    List<String> warnings,
  ) =>
      ExactNameLookup._(
        status: ExactNameStatus.unique,
        data: data,
        warnings: warnings,
        matchCount: 1,
      );

  factory ExactNameLookup.ambiguous(int count, List<String> warnings) =>
      ExactNameLookup._(
        status: ExactNameStatus.ambiguous,
        warnings: warnings,
        matchCount: count,
      );

  factory ExactNameLookup.notFound(List<String> warnings) =>
      ExactNameLookup._(
        status: ExactNameStatus.notFound,
        warnings: warnings,
      );

  factory ExactNameLookup.error(String error, List<String> warnings) =>
      ExactNameLookup._(
        status: ExactNameStatus.error,
        warnings: warnings,
        error: error,
      );

  final ExactNameStatus status;
  final Map<String, String> data;
  final List<String> warnings;
  final int matchCount;
  final String error;
}

class MaBandSearchHit {
  const MaBandSearchHit({
    required this.name,
    required this.url,
    this.genre = '',
    this.country = '',
    this.formedYear = '',
  });

  final String name;
  final String url;
  final String genre;
  final String country;
  final String formedYear;
}

/// Metal Archives band-name search results page for ambiguous Discover picks.
String metalArchivesSearchUrl(String name) => Uri.https(
      'www.metal-archives.com',
      '/search',
      {'searchString': name, 'type': 'band_name'},
    ).toString();

/// MusicBrainz artist search results page for ambiguous Discover picks.
String musicBrainzSearchUrl(String name) => Uri.https(
      'musicbrainz.org',
      '/search',
      {
        'query': name,
        'type': 'artist',
        'method': 'indexed',
      },
    ).toString();

/// Fold band names for Discover matching: trim, lowercase, strip diacritics
/// (ü→u, ñ→n / Spanish tilde, ÿ→y, …) and expand a few Latin ligatures (ß→ss).
/// Keeps other spelling, spacing, and word differences unchanged.
String foldBandNameForMatch(String input) {
  final lower = input.trim().toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    // Combining marks (including tilde U+0303 used to form ñ in NFD).
    if (rune >= 0x0300 && rune <= 0x036F) {
      continue;
    }
    final ch = String.fromCharCode(rune);
    final mapped = _diacriticAscii[ch];
    if (mapped != null) {
      buf.write(mapped);
      continue;
    }
    buf.write(ch);
  }
  return buf.toString();
}

/// Tight Discover name match: case-insensitive and diacritic-insensitive only.
bool bandNamesEqualForDiscover(String a, String b) =>
    foldBandNameForMatch(a) == foldBandNameForMatch(b);

/// @nodoc Kept for older call sites / tests; same as [bandNamesEqualForDiscover].
bool bandNamesEqualIgnoreCase(String a, String b) =>
    bandNamesEqualForDiscover(a, b);

/// MusicBrainz exact match: [name] or [sort-name] equals [query]
/// (case + diacritic fold).
///
/// Enables typed "Green Jelly" / "Gurschach" against "Green Jellÿ" / "Gürschach".
bool musicBrainzArtistMatchesExactName(Map artist, String query) {
  final artistName = (artist['name'] ?? '').toString();
  final sortName = (artist['sort-name'] ?? '').toString();
  return bandNamesEqualForDiscover(artistName, query) ||
      bandNamesEqualForDiscover(sortName, query);
}

/// Common Latin letters with diacritics → ASCII base (or ligature expansion).
const _diacriticAscii = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
  'ď': 'd', 'đ': 'd', 'ð': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e',
  'ę': 'e', 'ě': 'e',
  'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g',
  'ĥ': 'h', 'ħ': 'h',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i',
  'į': 'i', 'ı': 'i',
  'ĵ': 'j',
  'ķ': 'k',
  'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ŀ': 'l', 'ł': 'l',
  'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n', 'ŉ': 'n', 'ŋ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ŏ': 'o', 'ő': 'o',
  'œ': 'oe',
  'ŕ': 'r', 'ŗ': 'r', 'ř': 'r',
  'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ș': 's', 'ß': 'ss',
  'ţ': 't', 'ť': 't', 'ŧ': 't', 'ț': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u',
  'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ŵ': 'w',
  'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
  'æ': 'ae',
  'þ': 'th',
};

final _maSearchLink = RegExp(
  r'''href=["'](https?://(?:www\.)?metal-archives\.com/bands/[^"']+)["'][^>]*>([^<]+)''',
  caseSensitive: false,
);

/// Parse one Metal Archives ajax-advanced band search row.
MaBandSearchHit? parseMetalArchivesSearchHit(List<dynamic> row) {
  if (row.isEmpty) return null;
  final cell = row[0]?.toString() ?? '';
  final match = _maSearchLink.firstMatch(cell);
  if (match == null) return null;
  final url = match.group(1)!.trim();
  final name = _decodeHtmlEntities(match.group(2)!.trim());
  if (name.isEmpty || url.isEmpty) return null;
  return MaBandSearchHit(
    name: name,
    url: url,
    genre: row.length > 1 ? _decodeHtmlEntities(row[1].toString().trim()) : '',
    country:
        row.length > 2 ? _decodeHtmlEntities(row[2].toString().trim()) : '',
    formedYear:
        row.length > 3 ? _decodeHtmlEntities(row[3].toString().trim()) : '',
  );
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
