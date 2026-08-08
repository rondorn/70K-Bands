import 'package:promoter_admin/src/models/festival_setup_package.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

/// Result of uploading a festival setup file to Dropbox.
class FestivalSetupDropboxExport {
  const FestivalSetupDropboxExport({
    required this.shareUrl,
    required this.apiPath,
    required this.fileName,
  });

  /// Dropbox share link (normalized, typically `raw=1`).
  final String shareUrl;

  /// Dropbox API path where the file was written.
  final String apiPath;

  final String fileName;
}

/// Export / import portable festival admin setup packages.
class FestivalSetupService {
  FestivalSetupService({
    required this.pointerService,
    required this.dropboxApi,
  });

  final PointerService pointerService;
  final DropboxApi dropboxApi;

  /// True when the signed-in user can write the Testing pointer (same folder
  /// as master pointer files) and a master folder location can be resolved.
  static bool canExportToMasterFolder(FestivalWorkspace workspace) {
    if (!workspace.canEditPointers) return false;
    if (workspace.festivalName.trim().isEmpty) return false;
    return workspace.masterFilesFolderPath.trim().isNotEmpty ||
        workspace.testingPointerUrl.trim().isNotEmpty;
  }

  /// Build JSON text for [workspace], optionally including reports/alerts URLs.
  String encodeExportJson(
    FestivalWorkspace workspace, {
    required bool includeReports,
    required bool includeAlerts,
  }) {
    return FestivalSetupPackage.fromWorkspace(
      workspace,
      includeReports: includeReports,
      includeAlerts: includeAlerts,
    ).toPrettyJson();
  }

  /// Upload the setup JSON next to the Testing/Production pointer files and
  /// return a share link (overwrites the same filename on re-export).
  Future<FestivalSetupDropboxExport> exportToDropboxMaster(
    FestivalWorkspace workspace, {
    required bool includeReports,
    required bool includeAlerts,
  }) async {
    if (!canExportToMasterFolder(workspace)) {
      throw StateError(
        'Export requires write access to the festival’s master pointer folder. '
        'Ask the primary festival administrator to share that folder with you.',
      );
    }
    final folder = await resolveMasterFolderPath(workspace);
    final fileName =
        FestivalSetupPackage.suggestedFileName(workspace.festivalName);
    final apiPath = _joinDropboxPath(folder, fileName);
    final json = encodeExportJson(
      workspace,
      includeReports: includeReports,
      includeAlerts: includeAlerts,
    );
    final shareUrl =
        await dropboxApi.uploadNewTextFileAndShare(apiPath, json);
    return FestivalSetupDropboxExport(
      shareUrl: shareUrl,
      apiPath: apiPath,
      fileName: fileName,
    );
  }

  /// Dropbox folder that holds Testing/Production pointer files.
  Future<String> resolveMasterFolderPath(FestivalWorkspace workspace) async {
    final cached = workspace.masterFilesFolderPath.trim();
    if (cached.isNotEmpty) {
      return cached.endsWith('/')
          ? cached.substring(0, cached.length - 1)
          : cached;
    }
    final pointerUrl = workspace.testingPointerUrl.trim();
    if (pointerUrl.isEmpty) {
      throw StateError(
        'Cannot find the master pointer folder. Set a Testing link and '
        'Load festival data, then try Export again.',
      );
    }
    final pointerPath = await dropboxApi.resolveApiPath(pointerUrl);
    final slash = pointerPath.lastIndexOf('/');
    if (slash <= 0) {
      throw StateError(
        'Cannot determine the folder for Testing link path: $pointerPath',
      );
    }
    return pointerPath.substring(0, slash);
  }

  static String _joinDropboxPath(String folder, String fileName) {
    var root = folder.trim().replaceAll('\\', '/');
    if (!root.startsWith('/')) root = '/$root';
    root = root.replaceAll(RegExp(r'/+$'), '');
    return '$root/$fileName';
  }

  /// Fetch a Dropbox (or HTTP) setup link and apply it into a workspace.
  ///
  /// Vocabulary from the package is preserved; pointer load only fills empty
  /// lists. When [dropboxConnected], probes write access afterward.
  ///
  /// Dropbox share links with `dl=0` are normalized to `raw=1` by [fetchUrlText].
  Future<FestivalWorkspace> importFromUrl(
    String setupUrl, {
    required bool dropboxConnected,
    String id = '',
  }) async {
    final url = setupUrl.trim();
    if (url.isEmpty) {
      throw ArgumentError('Setup link is required.');
    }
    final text = await fetchUrlText(url, forceRefresh: true);
    final package = FestivalSetupPackage.parse(text);
    return materializePackage(
      package,
      dropboxConnected: dropboxConnected,
      id: id,
    );
  }

  /// Replace the active festival’s config from a setup link, keeping [current].id.
  ///
  /// Reports / Alerts folder URLs from [current] are kept when the package did
  /// not include those fields. Local File Mode paths and data-source year
  /// override are also preserved.
  Future<FestivalWorkspace> updateFromUrl(
    String setupUrl, {
    required FestivalWorkspace current,
    required bool dropboxConnected,
  }) async {
    final url = setupUrl.trim();
    if (url.isEmpty) {
      throw ArgumentError('Setup link is required.');
    }
    final text = await fetchUrlText(url, forceRefresh: true);
    final package = FestivalSetupPackage.parse(text);
    var draft = await materializePackage(
      package,
      dropboxConnected: dropboxConnected,
      id: current.id,
    );
    draft = draft.copyWith(
      emergencyLocalMode: current.emergencyLocalMode,
      emergencyLocalPaths: current.emergencyLocalPaths,
      dataSourceYearOverride: current.dataSourceYearOverride,
    );
    if (!package.includesReports) {
      draft = draft.copyWith(
        reportsFolderUrl: current.reportsFolderUrl,
        reportUrl: current.reportUrl,
        reportUrlFull: current.reportUrlFull,
        reportDiscoveryEventYear: current.reportDiscoveryEventYear,
        reportDiscoveryFolderUrl: current.reportDiscoveryFolderUrl,
        reportFilesFolderPath: current.reportFilesFolderPath,
        canViewReports: current.canViewReports,
      );
    }
    if (!package.includesAlerts) {
      draft = draft.copyWith(
        alertFolderUrl: current.alertFolderUrl,
        alertFilesFolderPath: current.alertFilesFolderPath,
        canEditAlerts: current.canEditAlerts,
        ownsAlertFilesFolder: current.ownsAlertFilesFolder,
      );
    }
    if (dropboxConnected &&
        (!package.includesReports || !package.includesAlerts)) {
      draft = await FestivalCreateService.probeFullWorkspaceAccess(
        draft,
        dropboxApi,
      );
    }
    return draft;
  }

  /// Turn a parsed package into a ready workspace (pointers + optional probe).
  Future<FestivalWorkspace> materializePackage(
    FestivalSetupPackage package, {
    required bool dropboxConnected,
    String id = '',
  }) async {
    var draft = package.toWorkspace(id: id);
    if (draft.productionPointerUrl.trim().isNotEmpty) {
      draft = await pointerService.applyPointers(draft);
    } else {
      draft = await pointerService.applyTestingPointer(draft);
    }
    if (dropboxConnected) {
      draft = await FestivalCreateService.inferSplitFoldersFromUrls(
        draft,
        dropboxApi,
      );
      draft = await FestivalCreateService.probeFullWorkspaceAccess(
        draft,
        dropboxApi,
      );
    }
    return draft;
  }

  /// Build a workspace from manually pasted links (optional reports/alerts).
  Future<FestivalWorkspace> materializeManualLinks({
    required String festivalName,
    required String testingPointerUrl,
    String productionPointerUrl = '',
    String reportsFolderUrl = '',
    String alertFolderUrl = '',
    required bool dropboxConnected,
    String id = '',
  }) async {
    var draft = FestivalWorkspace(
      id: id,
      festivalName: festivalName.trim(),
      testingPointerUrl: testingPointerUrl.trim(),
      productionPointerUrl: productionPointerUrl.trim(),
      reportsFolderUrl: reportsFolderUrl.trim(),
      alertFolderUrl: alertFolderUrl.trim(),
    );
    if (draft.productionPointerUrl.trim().isNotEmpty) {
      draft = await pointerService.applyPointers(draft);
    } else {
      draft = await pointerService.applyTestingPointer(draft);
    }
    if (dropboxConnected) {
      draft = await FestivalCreateService.inferSplitFoldersFromUrls(
        draft,
        dropboxApi,
      );
      draft = await FestivalCreateService.probeFullWorkspaceAccess(
        draft,
        dropboxApi,
      );
    }
    return draft;
  }
}
