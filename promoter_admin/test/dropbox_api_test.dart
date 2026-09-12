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

    test('encodes update mode with a parent rev', () {
      final header = dropboxApiArg({
        'path': '/schedule.csv',
        'mode': {'.tag': 'update', 'update': 'abc123'},
        'strict_conflict': true,
      });
      expect(header, contains('".tag":"update"'));
      expect(header, contains('"update":"abc123"'));
      expect(header, contains('"strict_conflict":true'));
    });
  });

  group('Dropbox revision helpers', () {
    test('parseDropboxApiResultRev reads rev from download header JSON', () {
      expect(
        parseDropboxApiResultRev(
          '{"name":"schedule.csv","rev":"a1c10ce0dd31"}',
        ),
        'a1c10ce0dd31',
      );
      expect(parseDropboxApiResultRev(null), isNull);
      expect(parseDropboxApiResultRev('not-json'), isNull);
    });

    test('isDropboxRevisionConflictStatus detects update conflicts', () {
      expect(
        isDropboxRevisionConflictStatus(
          409,
          '{"error_summary":"path/conflict/file/","error":{".tag":"path"}}',
        ),
        isTrue,
      );
      expect(isDropboxRevisionConflictStatus(409, 'invalid_revision'), isTrue);
      expect(isDropboxRevisionConflictStatus(400, 'conflict'), isFalse);
      expect(isDropboxRevisionConflictStatus(409, 'too_many_write_operations'), isFalse);
    });
  });

  group('parseVoidSharingResponseBody', () {
    test('accepts JSON null success body from add_folder_member', () {
      expect(parseVoidSharingResponseBody('null'), isNull);
      expect(parseVoidSharingResponseBody(''), isNull);
    });

    test('returns async job id when Dropbox defers the action', () {
      expect(
        parseVoidSharingResponseBody(
          '{".tag":"async_job_id","async_job_id":"abc123"}',
        ),
        'abc123',
      );
    });
  });

  group('parseShareFolderSharedFolderId', () {
    test('reads top-level shared_folder_id from Stone complete payload', () {
      expect(
        parseShareFolderSharedFolderId({
          '.tag': 'complete',
          'name': 'Artists',
          'path_lower': '/festival/artists',
          'shared_folder_id': '84528192421',
        }),
        '84528192421',
      );
    });

    test('falls back to nested complete map', () {
      expect(
        parseShareFolderSharedFolderId({
          '.tag': 'complete',
          'complete': {'shared_folder_id': 'nested-id'},
        }),
        'nested-id',
      );
    });

    test('returns null when id is missing', () {
      expect(
        parseShareFolderSharedFolderId({'.tag': 'complete'}),
        isNull,
      );
    });
  });

  group('parseSharedFolderMembersResponse', () {
    test('parses Dropbox UserMembershipInfo (user fields are not nested)', () {
      final members = parseSharedFolderMembersResponse({
        'users': [
          {
            'access_type': {'.tag': 'owner'},
            'user': {
              'account_id': 'dbid:owner123',
              'email': 'ron_dorn_1@yahoo.com',
              'display_name': 'Ron Dorn',
              'same_team': false,
            },
          },
          {
            'access_type': {'.tag': 'editor'},
            'user': {
              'account_id': 'dbid:aaron456',
              'email': 'aacopeland@gmail.com',
              'display_name': 'Aaron Copeland',
              'same_team': false,
            },
          },
        ],
        'groups': [],
        'invitees': [],
      });

      expect(members, hasLength(2));
      expect(members[0].displayName, 'Ron Dorn');
      expect(members[0].isOwner, isTrue);
      expect(members[0].isPendingInvite, isFalse);
      expect(members[0].accessStatusLabel, 'Owner');
      expect(members[1].email, 'aacopeland@gmail.com');
      expect(members[1].accessLevel, 'editor');
      expect(members[1].isPendingInvite, isFalse);
      expect(members[1].accessStatusLabel, 'Editor');
    });

    test('parses pending invitees and groups', () {
      final members = parseSharedFolderMembersResponse({
        'users': [],
        'groups': [
          {
            'access_type': {'.tag': 'editor'},
            'group': {
              'group_name': 'Promoter team',
              'group_id': 'g:abc123',
            },
          },
        ],
        'invitees': [
          {
            'access_type': {'.tag': 'editor'},
            'invitee': {'.tag': 'email', 'email': 'pending@example.com'},
          },
        ],
      });

      expect(members, hasLength(2));
      expect(members[0].displayName, 'Promoter team');
      expect(members[0].isPendingInvite, isFalse);
      expect(members[0].accessStatusLabel, 'Editor');
      expect(members[1].email, 'pending@example.com');
      expect(members[1].isPendingInvite, isTrue);
      expect(members[1].accessStatusLabel, 'Invite pending');
    });
  });
}
