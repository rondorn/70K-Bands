import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/widgets/recent_alerts_list.dart';

void main() {
  test('AlertQueueItem parses pending and completed filenames', () {
    final pending = AlertQueueItem.tryParse(
      const DropboxListedFile(
        name: 'customAlert-2026-07-14-09-01-02.pending',
        path: '/alerts/customAlert-2026-07-14-09-01-02.pending',
      ),
    );
    expect(pending, isNotNull);
    expect(pending!.status, AlertQueueStatus.pending);
    expect(pending.kind, AlertQueueKind.custom);
    expect(pending.canDelete, isTrue);
    expect(pending.path, '/alerts/customAlert-2026-07-14-09-01-02.pending');

    final completed = AlertQueueItem.tryParse(
      const DropboxListedFile(
        name: 'bandAnnouncements-2026-07-14-08-45-03.completed',
        path: '/alerts/bandAnnouncements-2026-07-14-08-45-03.completed',
      ),
    );
    expect(completed, isNotNull);
    expect(completed!.status, AlertQueueStatus.completed);
    expect(completed.kind, AlertQueueKind.bandAnnouncement);
    expect(completed.canDelete, isFalse);
  });

  test('fromListedFiles caps at 20 newest', () {
    final files = <DropboxListedFile>[
      for (var i = 0; i < 25; i++)
        DropboxListedFile(
          name:
              'customAlert-2026-07-14-09-00-${i.toString().padLeft(2, '0')}.pending',
          path: '/a/$i',
          serverModified: DateTime(2026, 7, 14, 9, 0, i),
        ),
    ];
    final items = AlertQueueItem.fromListedFiles(files);
    expect(items.length, 20);
    expect(items.first.fileName, contains('09-00-24'));
    expect(items.last.fileName, contains('09-00-05'));
  });

  test('ignores unrelated files', () {
    expect(
      AlertQueueItem.tryParse(
        const DropboxListedFile(name: 'notes.txt', path: '/alerts/notes.txt'),
      ),
      isNull,
    );
  });
}
