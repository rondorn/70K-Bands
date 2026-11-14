import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/desktop_update.dart';

void main() {
  test('newer name or build sorts after the installed version', () {
    final current = DesktopAppVersion.parse('1.0.24', '1');
    expect(DesktopAppVersion.parse('1.0.25', '1') > current, isTrue);
    expect(DesktopAppVersion.parse('1.0.24', '2') > current, isTrue);
    expect(
      DesktopAppVersion.parse('1.0.10', '1') >
          DesktopAppVersion.parse('1.0.9', '1'),
      isTrue,
    );
    expect(DesktopAppVersion.parse('1.0.24', '1') > current, isFalse);
    expect(DesktopAppVersion.parse('1.0.23', '9') > current, isFalse);
    final iteration = DesktopAppVersion.parse('1.0.28a', '1');
    expect(DesktopAppVersion.parse('1.0.28', '1') > iteration, isFalse);
    expect(DesktopAppVersion.parse('1.0.28-a', '1').compareTo(iteration), 0);
    expect(DesktopAppVersion.parse('1.0.28b', '1') > iteration, isTrue);
    expect(DesktopAppVersion.parse('1.0.28f', '1') > iteration, isTrue);
    expect(
      DesktopAppVersion.parse('1.0.29', '1') >
          DesktopAppVersion.parse('1.0.28f', '1'),
      isTrue,
    );
  });

  test('release json offers only a strictly newer zip for this platform', () {
    const body = '''
{
  "assets": [
    {
      "name": "omf-admin-macos-1.0.23_4.zip",
      "browser_download_url": "https://example.com/old-mac.zip"
    },
    {
      "name": "omf-admin-macos-1.0.25_2.zip",
      "browser_download_url": "https://example.com/new-mac.zip"
    },
    {
      "name": "omf-admin-macos-1.0.25_1.zip",
      "browser_download_url": "https://example.com/older-build.zip"
    },
    {
      "name": "omf-admin-windows-9.0.0_1.zip",
      "browser_download_url": "https://example.com/windows.zip"
    },
    {
      "name": "notes.txt",
      "browser_download_url": "https://example.com/notes.txt"
    }
  ]
}
''';
    final current = DesktopAppVersion.parse('1.0.24', '1');
    final mac = desktopUpdateOfferFromReleaseJson(
      body,
      windows: false,
      current: current,
    );
    expect(mac, isNotNull);
    expect(mac!.assetName, 'omf-admin-macos-1.0.25_2.zip');
    final lettered = desktopUpdateOfferFromReleaseJson(
      '''
{
  "assets": [
    {
      "name": "omf-admin-macos-1.0.28a_1.zip",
      "browser_download_url": "https://example.com/a.zip"
    },
    {
      "name": "omf-admin-macos-1.0.28b_1.zip",
      "browser_download_url": "https://example.com/b.zip"
    }
  ]
}
''',
      windows: false,
      current: DesktopAppVersion.parse('1.0.28a', '1'),
    );
    expect(lettered?.assetName, 'omf-admin-macos-1.0.28b_1.zip');
    expect(mac.downloadUrl, 'https://example.com/new-mac.zip');

    final windows = desktopUpdateOfferFromReleaseJson(
      body,
      windows: true,
      current: DesktopAppVersion.parse('9.0.0', '1'),
    );
    expect(windows, isNull);

    expect(
      desktopUpdateOfferFromReleaseJson(
        body,
        windows: false,
        current: DesktopAppVersion.parse('1.0.25', '2'),
      ),
      isNull,
    );
    expect(
      desktopUpdateOfferFromReleaseJson('{', windows: false, current: current),
      isNull,
    );
    expect(
      desktopUpdateOfferFromReleaseJson('{}', windows: false, current: current),
      isNull,
    );
  });

  test('a missing or older published release stays quiet', () async {
    final current = DesktopAppVersion.parse('1.0.24', '1');
    expect(
      await lookupDesktopUpdate(client: _FakeClient(404, ''), current: current),
      isNull,
    );
    expect(
      await lookupDesktopUpdate(
        client: _FakeClient(200, jsonEncode({'assets': []})),
        current: current,
      ),
      isNull,
    );
  });

  test('lookup returns the newer asset for this operating system', () async {
    final offer = await lookupDesktopUpdate(
      client: _FakeClient(
        200,
        jsonEncode({
          'assets': [
            {
              'name': 'omf-admin-macos-1.0.25_1.zip',
              'browser_download_url': 'https://example.com/mac.zip',
            },
            {
              'name': 'omf-admin-windows-1.0.25_1.zip',
              'browser_download_url': 'https://example.com/win.zip',
            },
          ],
        }),
      ),
      current: DesktopAppVersion.parse('1.0.24', '1'),
    );
    expect(offer, isNotNull);
    expect(
      offer!.downloadUrl,
      Platform.isWindows
          ? 'https://example.com/win.zip'
          : 'https://example.com/mac.zip',
    );
  });

  test('mac install target follows the running bundle unless translocated', () {
    expect(
      macUpdateDestination(
        '/Applications/Open Metal Fest Admin.app/Contents/MacOS/promoter_admin',
      ),
      '/Applications/Open Metal Fest Admin.app',
    );
    expect(
      macUpdateDestination(
        '/Users/me/Downloads/Open Metal Fest Admin.app/Contents/MacOS/promoter_admin',
      ),
      '/Users/me/Downloads/Open Metal Fest Admin.app',
    );
    expect(
      macUpdateDestination(
        '/private/var/folders/ab/AppTranslocation/xyz/d/Open Metal Fest Admin.app/Contents/MacOS/promoter_admin',
      ),
      macApplicationsDestination,
    );
    expect(
      macBundlePathFromExecutable('/tmp/flutter_tools/promoter_admin'),
      isNull,
    );
  });

  test('mac helper copies the new app before moving the old one aside', () {
    final script = macUpdateHelperScript(
      sourceApp: "/tmp/it's.app",
      destApp: '/Applications/Open Metal Fest Admin.app',
    );
    final dittoAt = script.indexOf('ditto ');
    final moveAside = script.indexOf(
      "mv '/Applications/Open Metal Fest Admin.app' "
      "'/Applications/Open Metal Fest Admin.app.previous'",
    );
    final moveIn = script.indexOf(
      "mv '/Applications/Open Metal Fest Admin.app.updating' "
      "'/Applications/Open Metal Fest Admin.app'",
    );
    expect(script, contains('ditto --norsrc --noextattr '));
    expect(script, contains('set -euo pipefail'));
    expect(script, isNot(contains('kill -0')));
    expect(script, contains("'/tmp/it'\\''s.app'"));
    expect(script, contains('Contents/MacOS'));
    expect(dittoAt, greaterThan(0));
    expect(moveAside, greaterThan(dittoAt));
    expect(moveIn, greaterThan(moveAside));
    expect(shellQuote("it's"), "'it'\\''s'");
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(request.url.path, contains('/releases/tags/omf-admin-'));
    expect(request.url.path, isNot(contains('/releases/latest')));
    expect(request.headers['User-Agent'], 'OpenMetalFestAdmin');
    return http.StreamedResponse(Stream.value(utf8.encode(body)), statusCode);
  }
}
