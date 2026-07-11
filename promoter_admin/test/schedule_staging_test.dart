import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/dropbox_auth.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_staging.dart';

void main() {
  late Directory tempDir;
  late List<String> uploads;
  late ScheduleStagingCoordinator staging;
  late FestivalWorkspace workspace;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('schedule_staging_test_');
    uploads = <String>[];
    workspace = const FestivalWorkspace(
      id: 'fest-70k',
      festivalName: '70K',
      scheduleUrl: 'https://example.com/schedule_test.csv?raw=1',
    );
    staging = ScheduleStagingCoordinator(
      pointerService: PointerService(),
      dropboxApi: DropboxApi(DropboxAuth()),
      debounce: const Duration(milliseconds: 40),
      stagingRoot: tempDir,
      uploadOverride: (url, text) async {
        uploads.add(text);
      },
    );

    // Seed a synced staging file so ensureStaging does not hit the network.
    final header = ScheduleService.toCsv(const []);
    final csv = File('${tempDir.path}/fest-70k_schedule.csv');
    await csv.writeAsString(header);
    final snapshot = File('${tempDir.path}/fest-70k_schedule.synced.csv');
    await snapshot.writeAsString(header);
    final meta = File('${tempDir.path}/fest-70k_schedule.meta.json');
    await meta.writeAsString(
      '{"state":"synced","publishedUrl":"${workspace.scheduleUrl}",'
      '"lastError":""}\n',
    );
  });

  tearDown(() async {
    staging.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ScheduleEvent event(String band, String start) => ScheduleEvent(
        band: band,
        location: 'Rail',
        date: '07/11/2026',
        day: 'Friday',
        startTime: start,
        endTime: '13:00',
        type: 'Show',
      );

  test('saveLocalAndQueue returns before Dropbox upload', () async {
    final events = [event('Band A', '12:00')];
    final sw = Stopwatch()..start();
    await staging.saveLocalAndQueue(
      workspace,
      ScheduleService.toCsv(events),
    );
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(200));
    expect(staging.status.state, ScheduleSyncState.pending);
    expect(uploads, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(uploads.length, 1);
    expect(staging.status.state, ScheduleSyncState.synced);
    expect(uploads.single, contains('Band A'));
  });

  test('rapid saves coalesce into one Dropbox upload of latest CSV', () async {
    await staging.saveLocalAndQueue(
      workspace,
      ScheduleService.toCsv([event('One', '12:00')]),
    );
    await staging.saveLocalAndQueue(
      workspace,
      ScheduleService.toCsv([
        event('One', '12:00'),
        event('Two', '12:30'),
      ]),
    );
    await staging.saveLocalAndQueue(
      workspace,
      ScheduleService.toCsv([
        event('One', '12:00'),
        event('Two', '12:30'),
        event('Three', '13:00'),
      ]),
    );

    expect(uploads, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(uploads.length, 1);
    expect(uploads.single, contains('Three'));
    expect(ScheduleService.parseEvents(uploads.single).length, 3);
  });

  test('flushSync uploads immediately without waiting for debounce', () async {
    await staging.saveLocalAndQueue(
      workspace,
      ScheduleService.toCsv([event('Flush', '14:00')]),
    );
    expect(uploads, isEmpty);

    await staging.flushSync(workspace);
    expect(uploads.length, 1);
    expect(uploads.single, contains('Flush'));
    expect(staging.status.state, ScheduleSyncState.synced);
  });

  test('outstandingEventKeys marks new rows until sync snapshot updates', () async {
    final csv = ScheduleService.toCsv([
      event('One', '12:00'),
      event('Two', '12:30'),
    ]);
    await staging.saveLocalAndQueue(workspace, csv);

    final pending = await staging.outstandingEventKeys(workspace);
    expect(pending.length, 2);
    expect(staging.status.pendingCount, 2);

    await staging.flushSync(workspace);
    final after = await staging.outstandingEventKeys(workspace);
    expect(after, isEmpty);
    expect(staging.status.pendingCount, 0);
    expect(staging.status.state, ScheduleSyncState.synced);
  });

  test('pendingKeysFromCsv detects edits and deletions', () {
    final synced = ScheduleService.toCsv([
      event('A', '12:00'),
      event('B', '13:00'),
    ]);
    final stagingCsv = ScheduleService.toCsv([
      event('A', '12:00'), // unchanged
      ScheduleEvent(
        band: 'B',
        location: 'Rail',
        date: '07/11/2026',
        day: 'Friday',
        startTime: '13:00',
        endTime: '14:00', // edited end
        type: 'Show',
      ),
      event('C', '15:00'), // added
    ]);
    // Remove nothing from staging but B fingerprint changed; also if we omit A...
    final pending = ScheduleStagingCoordinator.pendingKeysFromCsv(
      stagingCsv: stagingCsv,
      syncedCsv: synced,
    );
    expect(pending.contains('B|Rail|07/11/2026|13:00'), isTrue);
    expect(pending.contains('C|Rail|07/11/2026|15:00'), isTrue);
    expect(pending.contains('A|Rail|07/11/2026|12:00'), isFalse);

    final withDelete = ScheduleService.toCsv([event('A', '12:00')]);
    final deleted = ScheduleStagingCoordinator.pendingKeysFromCsv(
      stagingCsv: withDelete,
      syncedCsv: synced,
    );
    expect(deleted.contains('B|Rail|07/11/2026|13:00'), isTrue);
  });
}
