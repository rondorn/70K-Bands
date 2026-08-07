import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_staging.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/dropbox_auth.dart';

void main() {
  late Directory tempDir;
  late CsvStagingCoordinator staging;
  late FestivalWorkspace workspace;
  late File publishedFile;
  const publishedBody = 'bandName\nAlpha\n';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('csv_staging_ttl_');
    publishedFile = File('${tempDir.path}/published_artists.csv');
    await publishedFile.writeAsString(publishedBody);
    workspace = const FestivalWorkspace(
      id: 'fest-70k',
      festivalName: '70K',
      bandListUrl: 'local://artists.csv',
    );
    staging = CsvStagingCoordinator(
      dropboxApi: DropboxApi(DropboxAuth()),
      channelSuffix: 'artists',
      displayName: 'Artists',
      stagingRoot: tempDir,
      resolveUrl: (_) async => publishedFile.path,
      uploadOverride: (_, __) async {},
    );
  });

  tearDown(() async {
    staging.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> writeLocal({
    required String csv,
    String? lastFetchedAt,
    String state = 'synced',
  }) async {
    final base = '${tempDir.path}/fest-70k_artists';
    await File('$base.csv').writeAsString(csv);
    await File('$base.synced.csv').writeAsString(csv);
    final meta = <String, dynamic>{
      'state': state,
      'publishedUrl': publishedFile.path,
      'lastError': '',
    };
    if (lastFetchedAt != null) {
      meta['lastFetchedAt'] = lastFetchedAt;
    }
    await File('$base.meta.json').writeAsString(
      '${const JsonEncoder().convert(meta)}\n',
    );
  }

  test('missing local CSV is expired and soft-load requests background refresh',
      () async {
    expect(await staging.isPublishedCacheExpired(workspace), isTrue);
    final soft = await staging.loadWorkingCsvSoft(workspace);
    expect(soft.csvText, isEmpty);
    expect(soft.shouldRefreshInBackground, isTrue);
  });

  test('fresh lastFetchedAt is not expired', () async {
    final now = DateTime.now().toUtc().toIso8601String();
    await writeLocal(csv: publishedBody, lastFetchedAt: now);
    expect(await staging.isPublishedCacheExpired(workspace), isFalse);
    final soft = await staging.loadWorkingCsvSoft(workspace);
    expect(soft.csvText, contains('Alpha'));
    expect(soft.shouldRefreshInBackground, isFalse);
  });

  test('expired cache is kept but marked for background refresh', () async {
    final old = DateTime.now()
        .toUtc()
        .subtract(
          CsvStagingCoordinator.publishedCacheTtl + const Duration(minutes: 1),
        )
        .toIso8601String();
    await writeLocal(csv: publishedBody, lastFetchedAt: old);
    expect(await staging.isPublishedCacheExpired(workspace), isTrue);
    final soft = await staging.loadWorkingCsvSoft(workspace);
    expect(soft.csvText, contains('Alpha'));
    expect(soft.shouldRefreshInBackground, isTrue);
  });

  test('legacy cache without lastFetchedAt is treated as expired', () async {
    await writeLocal(csv: publishedBody);
    expect(await staging.isPublishedCacheExpired(workspace), isTrue);
    final soft = await staging.loadWorkingCsvSoft(workspace);
    expect(soft.shouldRefreshInBackground, isTrue);
  });

  test('unsynced edits block background refresh flag and refresh call',
      () async {
    final old = DateTime.now()
        .toUtc()
        .subtract(
          CsvStagingCoordinator.publishedCacheTtl + const Duration(minutes: 1),
        )
        .toIso8601String();
    await writeLocal(csv: publishedBody, lastFetchedAt: old);
    await staging.saveLocalAndQueue(workspace, 'bandName\nBeta\n');

    final soft = await staging.loadWorkingCsvSoft(workspace);
    expect(soft.csvText, contains('Beta'));
    expect(soft.shouldRefreshInBackground, isFalse);

    final refreshed = await staging.refreshPublishedInBackground(workspace);
    expect(refreshed, isNull);
    expect(
      await File('${tempDir.path}/fest-70k_artists.csv').readAsString(),
      contains('Beta'),
    );
  });

  test('reloadFromPublished stamps lastFetchedAt and clears expiry', () async {
    final old = DateTime.now()
        .toUtc()
        .subtract(
          CsvStagingCoordinator.publishedCacheTtl + const Duration(minutes: 1),
        )
        .toIso8601String();
    await writeLocal(csv: 'bandName\nStale\n', lastFetchedAt: old);
    expect(await staging.isPublishedCacheExpired(workspace), isTrue);

    final text = await staging.reloadFromPublished(workspace);
    expect(text, contains('Alpha'));
    expect(await staging.isPublishedCacheExpired(workspace), isFalse);
    expect(await staging.lastFetchedAt(workspace), isNotNull);

    final soft = await staging.loadWorkingCsvSoft(workspace);
    expect(soft.shouldRefreshInBackground, isFalse);
  });

  test('background refresh reloads published body when safe', () async {
    final old = DateTime.now()
        .toUtc()
        .subtract(
          CsvStagingCoordinator.publishedCacheTtl + const Duration(minutes: 1),
        )
        .toIso8601String();
    await writeLocal(csv: 'bandName\nStale\n', lastFetchedAt: old);

    final refreshed = await staging.refreshPublishedInBackground(workspace);
    expect(refreshed, contains('Alpha'));
    expect(
      await File('${tempDir.path}/fest-70k_artists.csv').readAsString(),
      contains('Alpha'),
    );
  });
}
