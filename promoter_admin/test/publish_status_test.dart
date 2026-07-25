import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/publish_status.dart';
import 'package:promoter_admin/src/services/promote_service.dart';

FestivalWorkspace _workspace({
  bool canEditBands = true,
  bool canEditSchedule = true,
  bool canEditDescriptions = true,
}) {
  return FestivalWorkspace(
    id: 'fest',
    festivalName: 'Test Fest',
    testingPointerUrl: 'https://dropbox.com/s/test/testing.txt?dl=0',
    productionPointerUrl: 'https://dropbox.com/s/prod/production.txt?dl=0',
    canEditBands: canEditBands,
    canEditSchedule: canEditSchedule,
    canEditDescriptions: canEditDescriptions,
  );
}

void main() {
  test('readyToPublish when CSV content differs', () {
    final diff = PromoteDiff(bandsContentDiffer: true);
    final status = PublishStatusSnapshot.fromCheckResult(
      workspace: _workspace(),
      dropboxConnected: true,
      diff: diff,
      csvSyncPendingLabels: const [],
      errorMessage: null,
    );
    expect(status.kind, PublishStatusKind.readyToPublish);
    expect(status.canPublish, isTrue);
    expect(status.headline, contains('Ready to publish'));
    expect(status.detail, contains('artists'));
  });

  test('upToDate when nothing differs', () {
    final status = PublishStatusSnapshot.fromCheckResult(
      workspace: _workspace(),
      dropboxConnected: true,
      diff: PromoteDiff(),
      csvSyncPendingLabels: const [],
      errorMessage: null,
    );
    expect(status.kind, PublishStatusKind.upToDate);
    expect(status.canPublish, isFalse);
  });

  test('csv sync pending blocks publish even when other data differs', () {
    final diff = PromoteDiff(bandsContentDiffer: true);
    final status = PublishStatusSnapshot.fromCheckResult(
      workspace: _workspace(),
      dropboxConnected: true,
      diff: diff,
      csvSyncPendingLabels: const ['Schedule'],
      errorMessage: null,
    );
    expect(status.kind, PublishStatusKind.scheduleSaving);
    expect(status.canPublish, isFalse);
    expect(status.headline, contains('Schedule still saving'));
  });

  test('year roll is ready to publish', () {
    final status = PublishStatusSnapshot.fromCheckResult(
      workspace: _workspace(),
      dropboxConnected: true,
      diff: PromoteDiff(testingYear: '2027', productionYear: '2026'),
      csvSyncPendingLabels: const [],
      errorMessage: null,
    );
    expect(status.kind, PublishStatusKind.yearRollReady);
    expect(status.canPublish, isTrue);
    expect(status.headline, contains('2027'));
  });

  test('demo year override blocks publish', () {
    final ws = _workspace().copyWith(dataSourceYearOverride: '2025');
    final status = PublishStatusSnapshot.fromCheckResult(
      workspace: ws,
      dropboxConnected: true,
      diff: PromoteDiff(bandsContentDiffer: true),
      csvSyncPendingLabels: const [],
      errorMessage: null,
    );
    expect(status.kind, PublishStatusKind.blocked);
    expect(status.canPublish, isFalse);
  });

  test('shared schedule file is blocked', () {
    final status = PublishStatusSnapshot.fromCheckResult(
      workspace: _workspace(),
      dropboxConnected: true,
      diff: PromoteDiff(scheduleShared: true),
      csvSyncPendingLabels: const [],
      errorMessage: null,
    );
    expect(status.kind, PublishStatusKind.blocked);
    expect(status.headline, contains('separate Testing file'));
  });
}
