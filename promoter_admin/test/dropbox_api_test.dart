import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';

void main() {
  group('dropboxApiArg', () {
    test('escapes non-ASCII path characters for HTTP headers', () {
      const path = '/70k public data files/descriptions/æther_realm.txt';
      final header = dropboxApiArg({
        'path': path,
        'mode': 'overwrite',
        'autorename': false,
        'mute': false,
        'strict_conflict': false,
      });

      expect(header, isNot(contains('æ')));
      expect(header, contains(r'\u00e6'));
      expect(header, contains('"path":"/70k public data files/descriptions/'));
      expect(header, contains('"mode":"overwrite"'));
    });

    test('leaves ASCII-only JSON unchanged', () {
      final header = dropboxApiArg({'path': '/descriptions/ether_realm.txt'});
      expect(header, '{"path":"/descriptions/ether_realm.txt"}');
    });
  });
}
