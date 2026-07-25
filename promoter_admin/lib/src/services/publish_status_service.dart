import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/models/publish_status.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/promote_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';

/// Background Testing vs Production comparison for global publish UI.
class PublishStatusService extends ChangeNotifier {
  PublishStatusService({
    required PromoteService promoteService,
    required PointerService pointerService,
    required ScheduleService scheduleService,
    required LineupService lineupService,
    required DescriptionMapService descriptionMapService,
  })  : _promote = promoteService,
        _pointers = pointerService,
        _schedule = scheduleService,
        _lineup = lineupService,
        _descriptions = descriptionMapService;

  final PromoteService _promote;
  final PointerService _pointers;
  final ScheduleService _schedule;
  final LineupService _lineup;
  final DescriptionMapService _descriptions;

  PublishStatusSnapshot _snapshot = PublishStatusSnapshot.initial;
  PublishStatusSnapshot get snapshot => _snapshot;

  FestivalWorkspace? _workspace;
  bool _dropboxConnected = false;
  int _generation = 0;
  Timer? _debounce;

  void bind({
    required FestivalWorkspace workspace,
    required bool dropboxConnected,
  }) {
    final changed = _workspace?.id != workspace.id ||
        _dropboxConnected != dropboxConnected;
    _workspace = workspace;
    _dropboxConnected = dropboxConnected;
    if (changed) {
      requestCheck(immediate: true, forceRefresh: true);
    }
  }

  /// Debounced re-check after Testing data may have changed (sync complete, etc.).
  void notifyTestingDataChanged({
    bool forceRefresh = false,
    bool immediate = false,
  }) {
    requestCheck(
      immediate: immediate,
      forceRefresh: forceRefresh,
    );
  }

  /// Immediate re-check after a local save, using on-disk staging CSV overrides.
  void notifyRecordSaved() {
    requestCheck(
      immediate: true,
      forceRefresh: false,
      useLocalStagingOverrides: true,
    );
  }

  /// Update header pending-sync labels without a network compare.
  void refreshPendingSyncState() {
    final workspace = _workspace;
    if (workspace == null) return;
    _setSnapshot(
      PublishStatusSnapshot.fromCheckResult(
        workspace: workspace,
        dropboxConnected: _dropboxConnected,
        diff: _snapshot.diff,
        csvSyncPendingLabels: _pendingCsvLabels(workspace),
        errorMessage: null,
      ),
    );
  }

  /// Debounced re-check (navigation, tab changes).
  void requestCheck({
    bool immediate = false,
    bool forceRefresh = false,
    bool useLocalStagingOverrides = false,
  }) {
    _debounce?.cancel();
    if (immediate) {
      unawaited(
        _runCheck(
          forceRefresh: forceRefresh,
          useLocalStagingOverrides: useLocalStagingOverrides,
        ),
      );
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 1200), () {
      unawaited(_runCheck(forceRefresh: forceRefresh));
    });
  }

  /// Load festival data from Dropbox, then compare Testing vs Production.
  Future<FestivalWorkspace?> refreshPointersAndCheck(
    FestivalWorkspace workspace,
  ) async {
    if (workspace.testingPointerUrl.trim().isEmpty) return workspace;
    try {
      final updated = await _pointers.applyPointers(
        workspace,
        forceRefresh: true,
      );
      _workspace = updated;
      await _runCheck(forceRefresh: true);
      return updated;
    } catch (e) {
      _setSnapshot(
        PublishStatusSnapshot.fromCheckResult(
          workspace: workspace,
          dropboxConnected: _dropboxConnected,
          diff: _snapshot.diff,
          csvSyncPendingLabels: _pendingCsvLabels(workspace),
          errorMessage: e.toString(),
        ),
      );
      return null;
    }
  }

  Future<void> _runCheck({
    required bool forceRefresh,
    bool useLocalStagingOverrides = false,
  }) async {
    final workspace = _workspace;
    if (workspace == null) return;

    final gen = ++_generation;
    _setSnapshot(PublishStatusSnapshot.checking());

    if (!workspace.hasAnyEditAccess ||
        workspace.testingPointerUrl.trim().isEmpty ||
        workspace.productionPointerUrl.trim().isEmpty) {
      if (gen != _generation) return;
      _setSnapshot(
        PublishStatusSnapshot.fromCheckResult(
          workspace: workspace,
          dropboxConnected: _dropboxConnected,
          diff: null,
          csvSyncPendingLabels: const [],
          errorMessage: null,
        ),
      );
      return;
    }

    final pendingLabels = _pendingCsvLabels(workspace);
    final scheduleOverride = await _testingCsvOverride(
      enabled: workspace.canEditSchedule &&
          workspace.scheduleUrl.trim().isNotEmpty,
      useLocalOverride: useLocalStagingOverrides,
      hasUnsynced: _schedule.syncStatus.hasUnsynced,
      readLocal: () => _schedule.staging.readLocalCsvIfPresent(workspace),
    );
    final artistsOverride = await _testingCsvOverride(
      enabled:
          workspace.canEditBands && workspace.bandListUrl.trim().isNotEmpty,
      useLocalOverride: useLocalStagingOverrides,
      hasUnsynced: _lineup.syncStatus.hasUnsynced,
      readLocal: () => _lineup.staging.readLocalCsvIfPresent(workspace),
    );
    final mapOverride = await _testingCsvOverride(
      enabled: workspace.canEditDescriptions &&
          workspace.descriptionMapUrl.trim().isNotEmpty,
      useLocalOverride: useLocalStagingOverrides,
      hasUnsynced: _descriptions.syncStatus.hasUnsynced,
      readLocal: () => _descriptions.staging.readLocalCsvIfPresent(workspace),
    );

    try {
      final diff = await _promote.previewQuick(
        workspace,
        forceRefresh: forceRefresh,
        scheduleTestingCsvOverride: scheduleOverride,
        artistsTestingCsvOverride: artistsOverride,
        descriptionMapTestingCsvOverride: mapOverride,
      );
      if (gen != _generation) return;
      _setSnapshot(
        PublishStatusSnapshot.fromCheckResult(
          workspace: workspace,
          dropboxConnected: _dropboxConnected,
          diff: diff,
          csvSyncPendingLabels: pendingLabels,
          errorMessage: null,
        ),
      );
    } catch (e) {
      if (gen != _generation) return;
      _setSnapshot(
        PublishStatusSnapshot.fromCheckResult(
          workspace: workspace,
          dropboxConnected: _dropboxConnected,
          diff: null,
          csvSyncPendingLabels: pendingLabels,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<String?> _testingCsvOverride({
    required bool enabled,
    required bool useLocalOverride,
    required bool hasUnsynced,
    required Future<String?> Function() readLocal,
  }) async {
    if (!enabled) return null;
    if (!useLocalOverride && !hasUnsynced) return null;
    try {
      return await readLocal();
    } catch (_) {
      return null;
    }
  }

  List<String> _pendingCsvLabels(FestivalWorkspace workspace) {
    final labels = <String>[];
    if (workspace.canEditSchedule &&
        workspace.scheduleUrl.trim().isNotEmpty &&
        _schedule.syncStatus.hasUnsynced) {
      labels.add('Schedule');
    }
    if (workspace.canEditBands &&
        workspace.bandListUrl.trim().isNotEmpty &&
        _lineup.syncStatus.hasUnsynced) {
      labels.add('Artists');
    }
    if (workspace.canEditDescriptions &&
        workspace.descriptionMapUrl.trim().isNotEmpty &&
        _descriptions.syncStatus.hasUnsynced) {
      labels.add('Description map');
    }
    return labels;
  }

  void _setSnapshot(PublishStatusSnapshot next) {
    if (_snapshot.kind == next.kind &&
        _snapshot.headline == next.headline &&
        _snapshot.detail == next.detail &&
        _snapshot.canPublish == next.canPublish &&
        _snapshot.diff?.hasPublishableChanges ==
            next.diff?.hasPublishableChanges) {
      return;
    }
    _snapshot = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
