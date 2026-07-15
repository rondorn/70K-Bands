import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/csv_util.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

/// Lineup read/write against the testing band list URL (edit in place via Dropbox).
class LineupService {
  LineupService({
    required this.pointerService,
    required this.dropboxApi,
  });

  final PointerService pointerService;
  final DropboxApi dropboxApi;

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
    final url = await _lineupUrl(workspace, forceRefresh: forceRefresh);
    return pointerService.fetchLineup(url, forceRefresh: forceRefresh);
  }

  Future<void> save(FestivalWorkspace workspace, List<BandRow> bands) async {
    final url = await _lineupUrl(workspace);
    final csv = toCsv(
      bands,
      useCityState: workspace.useCityStateField,
    );
    await dropboxApi.uploadTextInPlace(url, csv);
  }

  Future<String> _lineupUrl(
    FestivalWorkspace workspace, {
    bool forceRefresh = false,
  }) async {
    var url = workspace.bandListUrl.trim();
    if (url.isEmpty) {
      final refreshed = await pointerService.applyTestingPointer(
        workspace,
        forceRefresh: forceRefresh,
      );
      url = refreshed.bandListUrl.trim();
    }
    if (url.isEmpty) {
      throw StateError('Testing pointer has no Current::artistUrl.');
    }
    return url;
  }

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
