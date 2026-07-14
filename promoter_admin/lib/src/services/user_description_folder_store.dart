import 'package:shared_preferences/shared_preferences.dart';

/// Local-only Dropbox folder where this user saves description .txt files when
/// they do not have description-map write access.
class UserDescriptionFolderStore {
  static const _key = 'userDescriptionFolderApiPathV1';

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = (prefs.getString(_key) ?? '').trim();
    return path.isEmpty ? null : path;
  }

  Future<void> save(String apiPath) async {
    var path = apiPath.trim().replaceAll('\\', '/');
    if (path.isEmpty) {
      throw ArgumentError('Folder path is required');
    }
    if (!path.startsWith('/')) path = '/$path';
    path = path.replaceAll(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
