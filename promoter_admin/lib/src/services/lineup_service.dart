import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_staging.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/emergency_local_mode_support.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

/// Lineup read/write against the testing band list URL (edit in place via Dropbox).
class LineupService {
  LineupService({
    required this.pointerService,
    required this.dropboxApi,
    CsvStagingCoordinator? staging,
  }) : staging = staging ??
            CsvStagingCoordinator(
              dropboxApi: dropboxApi,
              channelSuffix: 'artists',
              displayName: 'Artists',
              resolveUrl: (workspace) async {
                if (workspace.usesEmergencyLocalMode) {
                  final path = workspace.emergencyLocalPaths.artistsCsv.trim();
                  if (path.isEmpty) {
                    throw StateError('Artists CSV path is not configured.');
                  }
                  return path;
                }
                var url = workspace.bandListUrl.trim();
                if (url.isEmpty) {
                  final refreshed = await pointerService.applyTestingPointer(
                    workspace,
                  );
                  url = refreshed.bandListUrl.trim();
                }
                if (url.isEmpty) {
                  throw StateError('Testing pointer has no Current::artistUrl.');
                }
                return url;
              },
              pendingChangeCounter: (stagingCsv, syncedCsv) async {
                return CsvStagingCoordinator.pendingRowKeyCount(
                  stagingCsv: stagingCsv,
                  syncedCsv: syncedCsv,
                  keyColumn: 'bandName',
                  skipKeyLower: 'bandname',
                );
              },
            );

  final PointerService pointerService;
  final DropboxApi dropboxApi;
  final CsvStagingCoordinator staging;

  CsvSyncStatus get syncStatus => staging.status;

  void addSyncListener(VoidCallback listener) => staging.addListener(listener);

  void removeSyncListener(VoidCallback listener) =>
      staging.removeListener(listener);

  static const fields = [
    'bandName',
    'officalSite',
    'imageUrl',
    'youtube',
    'metalArchives',
    'wikipedia',
    'country',
    'genre',
    'noteworthy',
    'priorYears',
  ];

  /// CSV columns for the lineup file; includes city/state when enabled.
  static List<String> fieldsFor({required bool useCityState}) {
    if (!useCityState) return fields;
    return [...fields, 'city', 'state'];
  }

  Future<List<BandRow>> load(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    final text = forceRefresh
        ? await staging.reloadFromPublished(
            workspace,
            forceRefresh: true,
          )
        : await staging.loadWorkingCsv(workspace);
    return PointerService.parseLineupCsv(text);
  }

  /// Save locally immediately and queue a background Dropbox sync.
  Future<void> save(FestivalWorkspace workspace, List<BandRow> bands) async {
    await staging.saveLocalAndQueue(
      workspace,
      toCsv(
        bands,
        useCityState: workspace.useCityStateField,
      ),
    );
  }

  Future<void> flushSync(FestivalWorkspace workspace) =>
      staging.flushSync(workspace);

  void dispose() => staging.dispose();

  static String toCsv(
    List<BandRow> bands, {
    bool useCityState = false,
  }) {
    return mapsToCsv(
      fieldsFor(useCityState: useCityState),
      bands.map((b) => Map<String, String>.from(b.fields)).toList(),
    );
  }
}
