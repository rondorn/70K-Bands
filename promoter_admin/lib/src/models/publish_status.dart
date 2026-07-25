import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/promote_service.dart';

enum PublishStatusKind {
  unknown,
  checking,
  scheduleSaving,
  readyToPublish,
  yearRollReady,
  upToDate,
  blocked,
  error,
  notConfigured,
}

/// App-wide Testing vs Production publish readiness (user-facing copy).
class PublishStatusSnapshot {
  const PublishStatusSnapshot({
    required this.kind,
    required this.headline,
    this.detail,
    this.diff,
    this.canOpenPublish = false,
    this.canPublish = false,
  });

  final PublishStatusKind kind;
  final String headline;
  final String? detail;
  final PromoteDiff? diff;
  final bool canOpenPublish;
  final bool canPublish;

  static const initial = PublishStatusSnapshot(
    kind: PublishStatusKind.unknown,
    headline: '',
  );

  factory PublishStatusSnapshot.checking() {
    return const PublishStatusSnapshot(
      kind: PublishStatusKind.checking,
      headline: 'Checking whether Production is up to date…',
      canOpenPublish: true,
    );
  }

  static PublishStatusSnapshot fromCheckResult({
    required FestivalWorkspace workspace,
    required bool dropboxConnected,
    required PromoteDiff? diff,
    required List<String> csvSyncPendingLabels,
    required String? errorMessage,
  }) {
    final canOpen = workspace.hasAnyEditAccess;
    final testing = workspace.testingPointerUrl.trim();
    final production = workspace.productionPointerUrl.trim();

    if (!canOpen) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.notConfigured,
        headline: '',
        canOpenPublish: false,
        diff: diff,
      );
    }

    if (testing.isEmpty || production.isEmpty) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.notConfigured,
        headline: 'Add Testing and Production links in Settings to publish',
        canOpenPublish: false,
        diff: diff,
      );
    }

    if (testing == production) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.blocked,
        headline: 'Testing and Production links must be different',
        canOpenPublish: true,
        diff: diff,
      );
    }

    if (workspace.hasDataSourceYearOverride) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.blocked,
        headline: 'Publish blocked — switch back to Current in Settings',
        detail: 'Demo year ${workspace.dataSourceYearOverride} is selected',
        canOpenPublish: true,
        diff: diff,
      );
    }

    if (!dropboxConnected) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.blocked,
        headline: 'Connect Dropbox to check publish status',
        canOpenPublish: true,
        diff: diff,
      );
    }

    if (errorMessage != null && errorMessage.trim().isNotEmpty) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.error,
        headline: 'Can’t check publish status right now',
        detail: _friendlyError(errorMessage),
        canOpenPublish: true,
        diff: diff,
      );
    }

    if (diff == null) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.unknown,
        headline: '',
        canOpenPublish: canOpen,
        diff: diff,
      );
    }

    if (diff.scheduleShared) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.blocked,
        headline: 'Schedule must use a separate Testing file',
        detail: 'Fix the Testing pointer in Settings before publishing',
        canOpenPublish: true,
        diff: diff,
      );
    }

    if (csvSyncPendingLabels.isNotEmpty) {
      final saving = _savingHeadline(csvSyncPendingLabels);
      final otherChanges = _otherPendingChanges(diff, workspace, csvSyncPendingLabels);
      return PublishStatusSnapshot(
        kind: PublishStatusKind.scheduleSaving,
        headline: saving,
        detail: otherChanges == null
            ? 'Publish will be available once Testing finishes saving'
            : 'Also waiting to compare saved data · $otherChanges',
        canOpenPublish: true,
        canPublish: false,
        diff: diff,
      );
    }

    if (diff.isYearRoll) {
      final year = diff.testingYear.trim();
      return PublishStatusSnapshot(
        kind: PublishStatusKind.yearRollReady,
        headline: year.isEmpty
            ? 'New festival year ready to publish'
            : 'Festival year $year ready to publish',
        detail: _changedAreasDetail(diff, workspace) ??
            'Production pointer will be updated for the new year',
        canOpenPublish: true,
        canPublish: true,
        diff: diff,
      );
    }

    if (diff.hasPublishableChanges) {
      return PublishStatusSnapshot(
        kind: PublishStatusKind.readyToPublish,
        headline:
            'Ready to publish — fans don’t have your latest changes yet',
        detail: _changedAreasDetail(diff, workspace),
        canOpenPublish: true,
        canPublish: true,
        diff: diff,
      );
    }

    return PublishStatusSnapshot(
      kind: PublishStatusKind.upToDate,
      headline: 'Production is up to date',
      detail: _sharedLiveDetail(diff),
      canOpenPublish: true,
      canPublish: false,
      diff: diff,
    );
  }

  static String? _changedAreasDetail(PromoteDiff diff, FestivalWorkspace ws) {
    if (diff.changeDetailLines.isNotEmpty) {
      return diff.changeDetailLines.first;
    }
    final parts = <String>[];
    if (ws.canEditBands && diff.bandsContentDiffer) {
      parts.add('artists');
    }
    if (ws.canEditSchedule && diff.eventsContentDiffer) {
      parts.add('schedule');
    }
    if (ws.canEditDescriptions && diff.mapContentDiffer) {
      parts.add('descriptions');
    }
    if (parts.isEmpty) return null;
    if (parts.length == 1) {
      return 'Changes in ${parts.single}';
    }
    if (parts.length == 2) {
      return 'Changes in ${parts[0]} and ${parts[1]}';
    }
    return 'Changes in artists, schedule, and descriptions';
  }

  static String _savingHeadline(List<String> labels) {
    if (labels.length == 1) {
      return '${labels.single} still saving to Testing…';
    }
    if (labels.length == 2) {
      return '${labels[0]} and ${labels[1]} still saving to Testing…';
    }
    return 'Changes still saving to Testing…';
  }

  static String? _otherPendingChanges(
    PromoteDiff diff,
    FestivalWorkspace ws,
    List<String> savingLabels,
  ) {
    final parts = <String>[];
    if (ws.canEditBands &&
        diff.bandsContentDiffer &&
        !savingLabels.contains('Artists')) {
      parts.add('artists');
    }
    if (ws.canEditSchedule &&
        diff.eventsContentDiffer &&
        !savingLabels.contains('Schedule')) {
      parts.add('schedule');
    }
    if (ws.canEditDescriptions &&
        diff.mapContentDiffer &&
        !savingLabels.contains('Description map')) {
      parts.add('descriptions');
    }
    if (parts.isEmpty) return null;
    return 'Unpublished changes in ${parts.join(' and ')}';
  }

  static String? _sharedLiveDetail(PromoteDiff diff) {
    final live = <String>[];
    if (diff.artistsShared) live.add('artists');
    if (diff.mapShared) live.add('descriptions');
    if (live.isEmpty) return null;
    if (live.length == 1) {
      return '${live.single[0].toUpperCase()}${live.single.substring(1)} '
          'already live in Production (shared file)';
    }
    return 'Artists and descriptions already live in Production (shared files)';
  }

  static String _friendlyError(String raw) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('timed out')) {
      return 'Check your internet connection and try again';
    }
    if (text.length > 120) {
      return '${text.substring(0, 117)}…';
    }
    return text;
  }
}
