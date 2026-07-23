import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/models/dropbox_folder_access.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_auth.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';

/// Dropbox [Dropbox-API-Arg] must be ASCII-only JSON (HTTP header rules).
///
/// [jsonEncode] emits Unicode literally (e.g. æ in paths), which Dart's HTTP
/// client rejects. Re-escape non-ASCII code points as `\uXXXX`.
String dropboxApiArg(Object value) {
  final json = jsonEncode(value);
  final buffer = StringBuffer();
  for (final rune in json.runes) {
    if (rune <= 0x7f) {
      buffer.writeCharCode(rune);
    } else if (rune <= 0xffff) {
      buffer.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
    } else {
      final adjusted = rune - 0x10000;
      final high = 0xd800 + (adjusted >> 10);
      final low = 0xdc00 + (adjusted & 0x3ff);
      buffer
        ..write('\\u${high.toRadixString(16).padLeft(4, '0')}')
        ..write('\\u${low.toRadixString(16).padLeft(4, '0')}');
    }
  }
  return buffer.toString();
}

class DropboxFolderEntry {
  const DropboxFolderEntry({required this.name, required this.path});

  final String name;
  final String path;
}

class DropboxListedFile {
  const DropboxListedFile({
    required this.name,
    required this.path,
    this.serverModified,
  });

  final String name;
  final String path;
  final DateTime? serverModified;
}

String sharedFolderMemberAccessTag(Map<String, dynamic> raw) {
  final access = raw['access_type'];
  if (access is Map<String, dynamic>) {
    return (access['.tag'] ?? '').toString();
  }
  return '';
}

DropboxFolderMember? memberFromUserInfo(
  Map<String, dynamic> user,
  String accessTag,
) {
  final email = (user['email'] ?? '').toString();
  final displayName = (user['display_name'] ?? email).toString();
  final dropboxId = (user['account_id'] ?? '').toString();
  if (email.isEmpty && dropboxId.isEmpty && displayName.isEmpty) {
    return null;
  }
  return DropboxFolderMember(
    email: email,
    displayName: displayName.isNotEmpty ? displayName : email,
    dropboxId: dropboxId,
    accessLevel: accessTag.isEmpty ? 'editor' : accessTag,
    isOwner: accessTag == 'owner',
  );
}

DropboxFolderMember? parseUserMembershipInfo(Map<String, dynamic> raw) {
  final user = raw['user'];
  if (user is! Map<String, dynamic>) return null;
  return memberFromUserInfo(user, sharedFolderMemberAccessTag(raw));
}

DropboxFolderMember? parseInviteeMembershipInfo(Map<String, dynamic> raw) {
  final accessTag = sharedFolderMemberAccessTag(raw);
  final user = raw['user'];
  if (user is Map<String, dynamic>) {
    return memberFromUserInfo(user, accessTag);
  }
  final invitee = raw['invitee'];
  if (invitee is Map<String, dynamic>) {
    final tag = (invitee['.tag'] ?? '').toString();
    if (tag == 'email') {
      final email = (invitee['email'] ?? '').toString();
      if (email.isEmpty) return null;
      return DropboxFolderMember(
        email: email,
        displayName: email,
        dropboxId: '',
        accessLevel: accessTag.isEmpty ? 'editor' : accessTag,
      );
    }
  }
  return null;
}

DropboxFolderMember? parseGroupMembershipInfo(Map<String, dynamic> raw) {
  final group = raw['group'];
  if (group is! Map<String, dynamic>) return null;
  final name = (group['group_name'] ?? 'Group').toString();
  final id = (group['group_id'] ?? '').toString();
  if (name.isEmpty && id.isEmpty) return null;
  final accessTag = sharedFolderMemberAccessTag(raw);
  return DropboxFolderMember(
    email: '',
    displayName: name.isNotEmpty ? name : id,
    dropboxId: id,
    accessLevel: accessTag.isEmpty ? 'editor' : accessTag,
  );
}

List<DropboxFolderMember> parseSharedFolderMembersResponse(
  Map<String, dynamic> data,
) {
  final members = <DropboxFolderMember>[];
  for (final raw in data['users'] as List<dynamic>? ?? const []) {
    if (raw is! Map<String, dynamic>) continue;
    final member = parseUserMembershipInfo(raw);
    if (member != null) members.add(member);
  }
  for (final raw in data['groups'] as List<dynamic>? ?? const []) {
    if (raw is! Map<String, dynamic>) continue;
    final member = parseGroupMembershipInfo(raw);
    if (member != null) members.add(member);
  }
  for (final raw in data['invitees'] as List<dynamic>? ?? const []) {
    if (raw is! Map<String, dynamic>) continue;
    final member = parseInviteeMembershipInfo(raw);
    if (member != null) members.add(member);
  }
  return members;
}

/// Dropbox void sharing RPCs (`add_folder_member`, `remove_folder_member`) often
/// return HTTP 200 with a JSON `null` body when the action completes immediately.
/// Returns an async job id when polling is required, otherwise null.
String? parseVoidSharingResponseBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty || trimmed == 'null') return null;
  final decoded = jsonDecode(trimmed);
  if (decoded == null) return null;
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Unexpected Dropbox sharing response: $body');
  }
  final tag = (decoded['.tag'] ?? '').toString();
  if (tag == 'async_job_id') {
    final jobId = (decoded['async_job_id'] ?? '').toString();
    if (jobId.isEmpty) {
      throw StateError('Dropbox returned an empty sharing async job id.');
    }
    return jobId;
  }
  return null;
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

  /// Whether the signed-in account can create files in the folder behind [shareUrl].
  ///
  /// Probes by uploading then deleting a tiny marker file (folders do not use
  /// the same edit_contents metadata path as shared files).
  Future<bool> canWriteFolderShareUrl(String shareUrl) async {
    final url = normalizeDropboxUrl(shareUrl).trim();
    if (url.isEmpty) return false;

    late final String folderPath;
    try {
      folderPath = await resolveApiPath(url);
    } catch (_) {
      return false;
    }

    final probeName =
        '.omf_write_probe_${DateTime.now().millisecondsSinceEpoch}';
    final probePath = '$folderPath/$probeName'.replaceAll('//', '/');
    try {
      await uploadTextAtPath(probePath, 'ok');
      await deletePath(probePath);
      return true;
    } catch (_) {
      try {
        await deletePath(probePath);
      } catch (_) {}
      return false;
    }
  }

  /// Delete a Dropbox path. Missing path is treated as success.
  Future<void> deletePath(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path.isEmpty) return;
    if (!path.startsWith('/')) path = '/$path';
    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/files/delete_v2'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path}),
    );
    if (resp.statusCode >= 200 && resp.statusCode < 300) return;
    final body = resp.body.toLowerCase();
    if (body.contains('not_found') || body.contains('path_lookup/not_found')) {
      return;
    }
    throw StateError(
      'Dropbox delete failed for $path (${resp.statusCode}): ${resp.body}',
    );
  }

  /// Download UTF-8 text at a Dropbox API path.
  Future<String> downloadTextAtPath(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path.isEmpty) throw ArgumentError('Path is required');
    if (!path.startsWith('/')) path = '/$path';
    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://content.dropboxapi.com/2/files/download'),
      headers: {
        'Authorization': 'Bearer $token',
        'Dropbox-API-Arg': dropboxApiArg({'path': path}),
      },
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final body = resp.body;
      if (body.contains('files.content.read') || body.contains('missing_scope')) {
        throw StateError(
          'Dropbox app is missing files.content.read. '
          'Enable it in the Dropbox developer console, then Disconnect and '
          'Connect Dropbox again in Settings.',
        );
      }
      throw StateError(
        'Dropbox download failed for $path (${resp.statusCode}): $body',
      );
    }
    var body = resp.body;
    if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
      body = body.substring(1);
    }
    return body;
  }

  /// Upload [text] as [fileName] inside the folder behind [folderShareUrl].
  Future<void> uploadTextInFolder({
    required String folderShareUrl,
    required String fileName,
    required String text,
  }) async {
    final name = fileName.trim();
    if (name.isEmpty || name.contains('/') || name.contains('\\')) {
      throw ArgumentError('fileName must be a simple file name, got: $fileName');
    }
    final folderPath = await resolveApiPath(folderShareUrl);
    final path = '$folderPath/$name'.replaceAll('//', '/');
    await uploadTextAtPath(path, text);
  }

  /// Probe write access for testing lineup / schedule / description-map / pointer
  /// / optional alert folder.
  Future<FestivalWorkspace> probeWorkspaceWriteAccess(
    FestivalWorkspace workspace,
  ) async {
    final bandUrl = workspace.bandListUrl.trim();
    final scheduleUrl = workspace.scheduleUrl.trim();
    final mapUrl = workspace.descriptionMapUrl.trim();
    final testingPointer = workspace.testingPointerUrl.trim();
    final alertFolder = workspace.alertFolderUrl.trim();

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
      alertFolder.isEmpty
          ? Future<bool>.value(false)
          : canWriteFolderShareUrl(alertFolder),
    ]);

    return workspace.copyWith(
      canEditBands: results[0],
      canEditSchedule: results[1],
      canEditDescriptions: results[2],
      // Year-roll only edits the testing pointer; production stays via Promote.
      canEditPointers: results[3],
      canEditAlerts: results[4],
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
        'Dropbox-API-Arg': dropboxApiArg({
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
    // Keep share-URL reads in sync with what we just wrote.
    await putCachedUrlText(shareUrl, text);
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
        'Dropbox-API-Arg': dropboxApiArg({
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

  /// Immediate file children of the folder behind [folderShareUrl].
  Future<List<DropboxListedFile>> listFilesInShareFolder(
    String folderShareUrl,
  ) async {
    final folderPath = await resolveApiPath(folderShareUrl);
    return listFilesInFolder(folderPath);
  }

  /// Immediate file children of [apiPath] (empty string = Dropbox root).
  Future<List<DropboxListedFile>> listFilesInFolder(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path == '/') path = '';
    if (path.isNotEmpty && !path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '');

    final token = await auth.accessToken();
    final entries = <DropboxListedFile>[];
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
        if (tag != 'file') continue;
        final name = (raw['name'] ?? '').toString();
        var entryPath =
            (raw['path_display'] ?? raw['path_lower'] ?? '').toString();
        if (entryPath.isEmpty || name.isEmpty) continue;
        if (!entryPath.startsWith('/')) entryPath = '/$entryPath';
        DateTime? modified;
        final serverModified = raw['server_modified']?.toString();
        if (serverModified != null && serverModified.isNotEmpty) {
          modified = DateTime.tryParse(serverModified)?.toLocal();
        }
        entries.add(
          DropboxListedFile(
            name: name,
            path: entryPath,
            serverModified: modified,
          ),
        );
      }
      hasMore = data['has_more'] == true;
      cursor = (data['cursor'] ?? '').toString();
      if (!hasMore || cursor.isEmpty) break;
    }

    entries.sort((a, b) {
      final am = a.serverModified;
      final bm = b.serverModified;
      if (am != null && bm != null) return bm.compareTo(am);
      if (am != null) return -1;
      if (bm != null) return 1;
      return b.name.toLowerCase().compareTo(a.name.toLowerCase());
    });
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

  /// Whether the signed-in account owns [apiPath] (can invite collaborators).
  Future<bool> isFolderOwner(String apiPath) async {
    final info = await getFolderAccessInfo(apiPath);
    return info?.isOwner ?? false;
  }

  /// Resolve sharing metadata for [apiPath], or null when the path is missing.
  Future<DropboxFolderAccessInfo?> getFolderAccessInfo(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path.isEmpty) return null;
    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/';

    final token = await auth.accessToken();
    final metaResp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/files/get_metadata'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path, 'include_media_info': false}),
    );
    if (metaResp.statusCode < 200 || metaResp.statusCode >= 300) {
      return null;
    }
    final meta = jsonDecode(metaResp.body) as Map<String, dynamic>;
    if ((meta['.tag'] ?? '').toString() != 'folder') return null;

    final sharingInfo = meta['sharing_info'];
    String? sharedFolderId;
    var parentShared = false;
    if (sharingInfo is Map<String, dynamic>) {
      sharedFolderId = (sharingInfo['shared_folder_id'] ?? '').toString().trim();
      final parentId =
          (sharingInfo['parent_shared_folder_id'] ?? '').toString().trim();
      parentShared = parentId.isNotEmpty;
    }

    if (sharedFolderId != null && sharedFolderId.isNotEmpty) {
      final accessType = await _folderAccessType(sharedFolderId);
      return DropboxFolderAccessInfo(
        apiPath: path,
        sharedFolderId: sharedFolderId,
        isOwner: accessType == 'owner',
      );
    }

    final listedId = await _sharedFolderIdFromListFolders(path);
    if (listedId != null && listedId.isNotEmpty) {
      final accessType = await _folderAccessType(listedId);
      return DropboxFolderAccessInfo(
        apiPath: path,
        sharedFolderId: listedId,
        isOwner: accessType == 'owner',
      );
    }

    // Folder exists in the account namespace but is not shared yet — treat as
    // owner unless it lives inside someone else's shared tree.
    return DropboxFolderAccessInfo(
      apiPath: path,
      sharedFolderId: '',
      isOwner: !parentShared,
    );
  }

  Future<String?> _folderAccessType(String sharedFolderId) async {
    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/sharing/get_folder_metadata'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'shared_folder_id': sharedFolderId}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final access = data['access_type'];
    if (access is Map<String, dynamic>) {
      return (access['.tag'] ?? '').toString();
    }
    return null;
  }

  /// Match a mounted folder path to a shared-folder id via sharing/list_folders.
  Future<String?> _sharedFolderIdFromListFolders(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '').toLowerCase();
    if (path.isEmpty) return null;

    final token = await auth.accessToken();
    String? cursor;
    var hasMore = true;

    while (hasMore) {
      final http.Response resp;
      if (cursor == null) {
        resp = await http.post(
          Uri.parse('https://api.dropboxapi.com/2/sharing/list_folders'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'limit': 1000, 'actions': []}),
        );
      } else {
        resp = await http.post(
          Uri.parse('https://api.dropboxapi.com/2/sharing/list_folders/continue'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'cursor': cursor}),
        );
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      for (final raw in data['entries'] as List<dynamic>? ?? const []) {
        if (raw is! Map<String, dynamic>) continue;
        final entryPath =
            (raw['path_lower'] ?? raw['path_display'] ?? '').toString().trim();
        if (entryPath.isEmpty) continue;
        final normalized = entryPath.startsWith('/')
            ? entryPath.toLowerCase()
            : '/${entryPath.toLowerCase()}';
        if (normalized == path) {
          final id = (raw['shared_folder_id'] ?? '').toString();
          if (id.isNotEmpty) return id;
        }
      }

      cursor = (data['cursor'] ?? '').toString();
      hasMore = data['has_more'] == true && cursor.isNotEmpty;
    }
    return null;
  }

  /// Ensure [apiPath] is a shared folder and return its shared_folder_id.
  Future<String> ensureSharedFolder(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path.isEmpty) throw ArgumentError('Folder path is required');
    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '');

    final existing = await getFolderAccessInfo(path);
    if (existing != null &&
        existing.sharedFolderId.isNotEmpty &&
        existing.isOwner) {
      return existing.sharedFolderId;
    }

    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/sharing/share_folder'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': path, 'force_async': false}),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Could not share Dropbox folder $path (${resp.statusCode}): ${resp.body}',
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (data['.tag'] ?? '').toString();
    if (tag == 'complete') {
      final complete = data['complete'] as Map<String, dynamic>? ?? const {};
      final id = (complete['shared_folder_id'] ?? '').toString();
      if (id.isEmpty) {
        throw StateError('Dropbox did not return a shared folder id for $path');
      }
      return id;
    }
    if (tag == 'async_job_id') {
      final jobId = (data['async_job_id'] ?? '').toString();
      if (jobId.isEmpty) {
        throw StateError('Dropbox share_folder returned an empty job id.');
      }
      return _awaitShareFolderJob(jobId);
    }
    throw StateError('Unexpected share_folder response for $path: ${resp.body}');
  }

  Future<String> _awaitShareFolderJob(String jobId) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      final token = await auth.accessToken();
      final resp = await http.post(
        Uri.parse('https://api.dropboxapi.com/2/sharing/check_job_status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'async_job_id': jobId}),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError(
          'Dropbox share job check failed (${resp.statusCode}): ${resp.body}',
        );
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['.tag'] ?? '').toString();
      if (tag == 'complete') {
        final complete = data['complete'] as Map<String, dynamic>? ?? const {};
        final id = (complete['shared_folder_id'] ?? '').toString();
        if (id.isEmpty) {
          throw StateError('Dropbox share job completed without a folder id.');
        }
        return id;
      }
      if (tag == 'failed') {
        throw StateError('Dropbox share job failed: ${resp.body}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw StateError('Timed out waiting for Dropbox to share the folder.');
  }

  /// Invite [email] as an editor on [sharedFolderId]. Dropbox sends the invite.
  Future<void> addFolderMemberByEmail({
    required String sharedFolderId,
    required String email,
    String accessLevel = 'editor',
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) throw ArgumentError('Email is required.');
    if (sharedFolderId.trim().isEmpty) {
      throw ArgumentError('Shared folder id is required.');
    }

    final token = await auth.accessToken();
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/sharing/add_folder_member'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'shared_folder_id': sharedFolderId,
        'members': [
          {
            'member': {'.tag': 'email', 'email': trimmed},
            'access_level': {'.tag': accessLevel},
          },
        ],
        'quiet': false,
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Could not grant folder access (${resp.statusCode}): ${resp.body}',
      );
    }
    final jobId = parseVoidSharingResponseBody(resp.body);
    if (jobId != null) {
      await _awaitVoidSharingJob(jobId);
    }
  }

  Future<void> _awaitVoidSharingJob(String jobId) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      final token = await auth.accessToken();
      final resp = await http.post(
        Uri.parse('https://api.dropboxapi.com/2/sharing/check_job_status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'async_job_id': jobId}),
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError(
          'Dropbox job check failed (${resp.statusCode}): ${resp.body}',
        );
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (data['.tag'] ?? '').toString();
      if (tag == 'complete') return;
      if (tag == 'failed') {
        throw StateError('Dropbox sharing job failed: ${resp.body}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw StateError('Timed out waiting for Dropbox sharing job.');
  }

  /// List collaborators on [sharedFolderId] (owner included).
  Future<List<DropboxFolderMember>> listFolderMembers(
    String sharedFolderId,
  ) async {
    if (sharedFolderId.trim().isEmpty) return const [];

    final token = await auth.accessToken();
    final members = <DropboxFolderMember>[];
    String? cursor;
    var hasMore = true;

    while (hasMore) {
      final http.Response resp;
      if (cursor == null) {
        resp = await http.post(
          Uri.parse('https://api.dropboxapi.com/2/sharing/list_folder_members'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'shared_folder_id': sharedFolderId,
            'actions': [],
          }),
        );
      } else {
        resp = await http.post(
          Uri.parse(
            'https://api.dropboxapi.com/2/sharing/list_folder_members/continue',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'cursor': cursor}),
        );
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw StateError(
          'Could not list folder members (${resp.statusCode}): ${resp.body}',
        );
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      members.addAll(parseSharedFolderMembersResponse(data));
      cursor = (data['cursor'] ?? '').toString();
      hasMore = data['has_more'] == true && cursor.isNotEmpty;
    }

    return members;
  }

  /// Revoke [member]'s access to [sharedFolderId].
  Future<void> removeFolderMember({
    required String sharedFolderId,
    required DropboxFolderMember member,
  }) async {
    if (member.isOwner) {
      throw StateError('Cannot revoke access for the folder owner.');
    }
    final token = await auth.accessToken();
    final memberTag = member.dropboxId.isNotEmpty
        ? {'.tag': 'dropbox_id', 'dropbox_id': member.dropboxId}
        : {'.tag': 'email', 'email': member.email};
    final resp = await http.post(
      Uri.parse('https://api.dropboxapi.com/2/sharing/remove_folder_member'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'shared_folder_id': sharedFolderId,
        'member': memberTag,
        'leave_a_copy': false,
      }),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw StateError(
        'Could not revoke folder access (${resp.statusCode}): ${resp.body}',
      );
    }
    final jobId = parseVoidSharingResponseBody(resp.body);
    if (jobId != null) {
      await _awaitVoidSharingJob(jobId);
    }
  }

  /// Probe folder ownership flags using cached folder paths (after cache refresh).
  Future<FestivalWorkspace> probeWorkspaceFolderOwnership(
    FestivalWorkspace workspace,
  ) async {
    final paths = [
      workspace.masterFilesFolderPath.trim(),
      workspace.artistFilesFolderPath.trim(),
      workspace.scheduleFilesFolderPath.trim(),
      workspace.descriptionFilesFolderPath.trim(),
      workspace.alertFilesFolderPath.trim(),
    ];

    final results = await Future.wait([
      paths[0].isEmpty
          ? Future<bool>.value(false)
          : isFolderOwner(paths[0]),
      paths[1].isEmpty
          ? Future<bool>.value(false)
          : isFolderOwner(paths[1]),
      paths[2].isEmpty
          ? Future<bool>.value(false)
          : isFolderOwner(paths[2]),
      paths[3].isEmpty
          ? Future<bool>.value(false)
          : isFolderOwner(paths[3]),
      paths[4].isEmpty
          ? Future<bool>.value(false)
          : isFolderOwner(paths[4]),
    ]);

    return workspace.copyWith(
      ownsMasterFilesFolder: results[0],
      ownsArtistFilesFolder: results[1],
      ownsScheduleFilesFolder: results[2],
      ownsDescriptionFilesFolder: results[3],
      ownsAlertFilesFolder: results[4],
    );
  }
}
