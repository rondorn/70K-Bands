import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_auth.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';

class DropboxFolderEntry {
  const DropboxFolderEntry({required this.name, required this.path});

  final String name;
  final String path;
}

/// Dropbox file operations that edit existing files in place (stable share links).
class DropboxApi {
  DropboxApi(this.auth);

  final DropboxAuth auth;
  final Map<String, String> _pathCache = {};

  Future<String> resolveApiPath(String shareUrl) async {
    final url = normalizeDropboxUrl(shareUrl).trim();
    if (url.isEmpty) throw ArgumentError('Share URL is required');
    final cached = _pathCache[url];
    if (cached != null) return cached;

    final token = await auth.accessToken();
    final metaUrl = _metadataShareUrl(url);
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/sharing/get_shared_link_metadata'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'url': metaUrl}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Could not resolve Dropbox path for share link '
        '(${resp.statusCode}): ${resp.body}',
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    var path = (data['path_lower'] ?? data['path_display'] ?? '').toString().trim();
    if (path.isEmpty) {
      throw StateError(
        'Dropbox did not return a file path for this link. '
        'Sign in with an account that can access the file.',
      );
    }
    if (!path.startsWith('/')) path = '/$path';
    _pathCache[url] = path;
    return path;
  }

  /// Whether the signed-in account can edit the file behind [shareUrl].
  ///
  /// Uses Dropbox path resolution + sharing metadata (`edit_contents`). Files that
  /// are only visible via a link (no mounted path) are treated as read-only.
  Future<bool> canWriteShareUrl(String shareUrl) async {
    final url = normalizeDropboxUrl(shareUrl).trim();
    if (url.isEmpty) return false;

    late final String path;
    try {
      path = await resolveApiPath(url);
    } catch (_) {
      return false;
    }

    final token = await auth.accessToken();
    final sharing = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/sharing/get_file_metadata'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file': path,
        'actions': [
          {'.tag': 'edit_contents'},
        ],
      }),
    );

    if (sharing.statusCode >= 200 && sharing.statusCode < 300) {
      final data = jsonDecode(sharing.body) as Map<String, dynamic>;
      final perms = data['permissions'] as List<dynamic>? ?? const [];
      for (final raw in perms) {
        if (raw is! Map<String, dynamic>) continue;
        final action = raw['action'];
        final tag = action is Map<String, dynamic>
            ? (action['.tag'] ?? '').toString()
            : '';
        if (tag != 'edit_contents') continue;
        final allow = raw['allow'];
        if (allow is bool) return allow;
      }

      final access = data['access_type'];
      if (access is Map<String, dynamic>) {
        final tag = (access['.tag'] ?? '').toString();
        if (tag == 'owner' || tag == 'editor') return true;
        if (tag == 'viewer' ||
            tag == 'viewer_no_comment' ||
            tag == 'traverse' ||
            tag == 'no_access') {
          return false;
        }
      }
      // Shared file but no clear edit grant.
      return false;
    }

    // Not exposed via Sharing API (e.g. personal file with a share link).
    // If Files API can see it under a mounted path, treat as writable.
    final meta = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/files/get_metadata'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path}),
    );
    return meta.statusCode >= 200 && meta.statusCode < 300;
  }

  /// Probe write access for testing lineup / schedule / description-map / pointer.
  Future<FestivalWorkspace> probeWorkspaceWriteAccess(
    FestivalWorkspace workspace,
  ) async {
    final bandUrl = workspace.bandListUrl.trim();
    final scheduleUrl = workspace.scheduleUrl.trim();
    final mapUrl = workspace.descriptionMapUrl.trim();
    final testingPointer = workspace.testingPointerUrl.trim();

    final results = await Future.wait([
      bandUrl.isEmpty
          ? Future<bool>.value(false)
          : canWriteShareUrl(bandUrl),
      scheduleUrl.isEmpty
          ? Future<bool>.value(false)
          : canWriteShareUrl(scheduleUrl),
      mapUrl.isEmpty
          ? Future<bool>.value(false)
          : canWriteShareUrl(mapUrl),
      testingPointer.isEmpty
          ? Future<bool>.value(false)
          : canWriteShareUrl(testingPointer),
    ]);

    return workspace.copyWith(
      canEditBands: results[0],
      canEditSchedule: results[1],
      canEditDescriptions: results[2],
      // Year-roll only edits the testing pointer; production stays via Promote.
      canEditPointers: results[3],
    );
  }

  /// Edit file content in place at the path behind [shareUrl]. Does not delete/replace.
  Future<void> uploadTextInPlace(String shareUrl, String text) async {
    final path = await resolveApiPath(shareUrl);
    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({
          'path': path,
          'mode': 'overwrite',
          'autorename': false,
          'mute': false,
          'strict_conflict': false,
        }),
      },
      body: utf8.encode(text),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = resp.body;
      if (body.contains('files.content.write')) {
        throw StateError(
          'Dropbox app is missing files.content.write. '
          'Enable it in the Dropbox developer console, then reconnect.',
        );
      }
      throw StateError('Dropbox upload failed (${resp.statusCode}): $body');
    }
  }

  /// Create folder if missing. Ignores conflict when it already exists.
  Future<void> ensureFolder(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path.isEmpty) throw ArgumentError('Folder path is required');
    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/';

    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/files/create_folder_v2'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path, 'autorename': false}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    final body = resp.body.toLowerCase();
    if (body.contains('conflict') || body.contains('path/conflict')) return;
    throw StateError(
      'Could not create Dropbox folder $path (${resp.statusCode}): ${resp.body}',
    );
  }

  Future<bool> fileExists(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path.isEmpty) return false;
    if (!path.startsWith('/')) path = '/$path';
    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/files/get_metadata'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path}),
    );
    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  /// Create [apiPath] with [text] only when the file is missing.
  Future<void> ensureTextFile(String apiPath, String text) async {
    if (await fileExists(apiPath)) return;
    await uploadTextAtPath(apiPath, text);
  }

  /// Upload/overwrite text at an API path (not a share URL).
  Future<void> uploadTextAtPath(String apiPath, String text) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/upload'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({
          'path': path,
          'mode': 'overwrite',
          'autorename': false,
          'mute': false,
          'strict_conflict': false,
        }),
      },
      body: utf8.encode(text),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Dropbox upload failed for $path (${resp.statusCode}): ${resp.body}',
      );
    }
  }

  /// Existing or new share link for [apiPath], normalized to raw=1.
  Future<String> shareUrlForPath(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    final token = await auth.accessToken();

    final listResp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/sharing/list_shared_links'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path, 'direct_only': true}),
    );
    if (listResp.statusCode >= 200 && listResp.statusCode < 300) {
      final data = jsonDecode(listResp.body) as Map<String, dynamic>;
      final links = data['links'] as List<dynamic>? ?? const [];
      if (links.isNotEmpty) {
        final url =
            (links.first as Map<String, dynamic>)['url']?.toString() ?? '';
        if (url.isNotEmpty) return normalizeDropboxUrl(url);
      }
    }

    final create = await http.post(
      Uri.parse(
        'https://api.dropboxapi.com/2/sharing/create_shared_link_with_settings',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path}),
    );
    if (create.statusCode < 200 || create.statusCode >= 300) {
      final body = create.body;
      final match = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(body);
      if (match != null) {
        return normalizeDropboxUrl(
          match.group(1)!.replaceAll(r'\u003a', ':'),
        );
      }
      throw StateError(
        'Could not create Dropbox share link for $path '
        '(${create.statusCode}): $body',
      );
    }
    final created = jsonDecode(create.body) as Map<String, dynamic>;
    final url = (created['url'] ?? '').toString();
    if (url.isEmpty) {
      throw StateError('Dropbox did not return a share URL for $path');
    }
    return normalizeDropboxUrl(url);
  }

  /// Upload a new text file (or overwrite that path) and return a share URL with raw=1.
  Future<String> uploadNewTextFileAndShare(String apiPath, String text) async {
    await uploadTextAtPath(apiPath, text);
    return shareUrlForPath(apiPath);
  }

  /// Immediate children of [apiPath] (empty string = Dropbox root).
  Future<List<DropboxFolderEntry>> listFolder(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path == '/') path = '';
    if (path.isNotEmpty && !path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '');

    final token = await auth.accessToken();
    final entries = <DropboxFolderEntry>[];
    String? cursor;
    var hasMore = true;

    while (hasMore) {
      final http.Response resp;
      if (cursor == null) {
        resp = await http.post(
          Uri.parse('https://api.dropboxapi.com/2/files/list_folder'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'path': path,
            'recursive': false,
            'include_deleted': false,
            'include_non_downloadable_files': false,
          }),
        );
      } else {
        resp = await http.post(
          Uri.parse('https://api.dropboxapi.com/2/files/list_folder/continue'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'cursor': cursor}),
        );
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError(
          'Dropbox list_folder failed (${resp.statusCode}): ${resp.body}',
        );
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final batch = data['entries'] as List<dynamic>? ?? const [];
      for (final raw in batch) {
        if (raw is! Map<String, dynamic>) continue;
        final tag = (raw['.tag'] ?? '').toString();
        if (tag != 'folder') continue;
        final name = (raw['name'] ?? '').toString();
        var entryPath =
            (raw['path_display'] ?? raw['path_lower'] ?? '').toString();
        if (entryPath.isEmpty || name.isEmpty) continue;
        if (!entryPath.startsWith('/')) entryPath = '/$entryPath';
        entries.add(DropboxFolderEntry(name: name, path: entryPath));
      }
      hasMore = data['has_more'] == true;
      cursor = (data['cursor'] ?? '').toString();
      if (!hasMore || cursor.isEmpty) break;
    }

    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  String _metadataShareUrl(String url) {
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters)
      ..remove('raw')
      ..remove('dl');
    params.putIfAbsent('dl', () => '0');
    return uri.replace(queryParameters: params).toString();
  }
}
