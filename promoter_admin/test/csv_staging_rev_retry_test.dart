import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_staging.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/dropbox_auth.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_staging.dart';

void main() {
  late Directory tempDir;
  late CsvStagingCoordinator staging;
  late FestivalWorkspace workspace;
  late String publishedCsv;
  late List<String> uploads;
  late int uploadAttempts;

  const header =
      'Band,Location,Date,Day,Start Time,End Time,Type,Description URL,Notes,ImageURL';

  ScheduleEvent event(String band, String day, String start) => ScheduleEvent(
        band: band,
        location: 'Pool Deck',
        date: day == 'Day 1' ? '1/15/2026' : '1/16/2026',
        day: day,
        startTime: start,
        endTime: '14:30',
        type: 'Show',
      );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('csv_staging_rev_');
    uploads = <String>[];
    uploadAttempts = 0;
    publishedCsv = '$header\n';
    workspace = const FestivalWorkspace(
      id: 'fest-70k',
      festivalName: '70K',
      scheduleUrl: 'https://example.com/schedule.csv?raw=1',
    );
    staging = CsvStagingCoordinator(
      dropboxApi: DropboxApi(DropboxAuth()),
      channelSuffix: 'schedule',
      displayName: 'Schedule',
      debounce: const Duration(milliseconds: 20),
      stagingRoot: tempDir,
      mergeRowKey: ScheduleStagingCoordinator.mergeEventKeyFromRow,
      mergeSkipKeyLower: 'band',
      resolveUrl: (_) async => workspace.scheduleUrl,
      fetchPublishedOverride: (_) async => publishedCsv,
      uploadOverride: (_, text) async {
        uploadAttempts++;
        if (uploadAttempts == 1) {
          publishedCsv = ScheduleService.toCsv([
            event('Event Z', 'Day 2', '14:00'),
          ]);
          throw DropboxRevisionConflict();
        }
        uploads.add(text);
      },
    );

    final empty = ScheduleService.toCsv(const []);
    await File('${tempDir.path}/fest-70k_schedule.csv').writeAsString(empty);
    await File('${tempDir.path}/fest-70k_schedule.synced.csv')
        .writeAsString(empty);
    await File('${tempDir.path}/fest-70k_schedule.meta.json').writeAsString(
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

  test('rev conflict retries merge so a different-day event is kept', () async {
    await staging.saveLocalAndQueue(
      workspace,
      ScheduleService.toCsv([event('Event B', 'Day 1', '14:00')]),
    );
    await staging.flushSync(workspace);

    expect(uploadAttempts, 2);
    expect(uploads, hasLength(1));
    expect(uploads.single, contains('Event B'));
    expect(uploads.single, contains('Event Z'));
    expect(uploads.single, contains('Day 1'));
    expect(uploads.single, contains('Day 2'));
    expect(staging.status.state, CsvSyncState.synced);
  });
}
