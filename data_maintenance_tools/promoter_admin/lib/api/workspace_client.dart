import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for the Flask Workspace JSON API (prototype bridge).
class WorkspaceClient {
  WorkspaceClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE',
              defaultValue: 'http://127.0.0.1:8080',
            );

  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> getWorkspace() async {
    final resp = await http.get(_uri('/api/workspace'));
    return _decode(resp);
  }

  Future<List<Map<String, dynamic>>> listBands() async {
    final resp = await http.get(_uri('/api/bands'));
    final body = _decode(resp);
    final bands = body['bands'];
    if (bands is List) {
      return bands.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> upsertBand({
    required Map<String, String> band,
    String? description,
    int? replaceIndex,
  }) async {
    final resp = await http.post(
      _uri('/api/bands'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'band': band,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (replaceIndex != null) 'replace_index': replaceIndex,
      }),
    );
    return _decode(resp);
  }

  Future<List<Map<String, dynamic>>> listSchedule() async {
    final resp = await http.get(_uri('/api/schedule'));
    final body = _decode(resp);
    final events = body['events'];
    if (events is List) {
      return events.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> promote() async {
    final resp = await http.post(_uri('/api/promote'));
    return _decode(resp);
  }

  Future<Map<String, dynamic>> createFestival({
    required String festivalName,
    required String eventYear,
    required String dropboxFolder,
  }) async {
    final resp = await http.post(
      _uri('/api/festivals/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'festival_name': festivalName,
        'event_year': eventYear,
        'dropbox_festival_folder': dropboxFolder,
      }),
    );
    return _decode(resp);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final body = jsonDecode(resp.body);
    if (body is! Map<String, dynamic>) {
      throw Exception('Unexpected response');
    }
    if (resp.statusCode >= 400 || body['ok'] == false) {
      throw Exception(body['error']?.toString() ?? 'Request failed (${resp.statusCode})');
    }
    return body;
  }
}
