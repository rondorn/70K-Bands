import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:promoter_admin/src/models/festival_setup_package.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/export_file_saver.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';

/// Export / import portable festival admin setup packages.
class FestivalSetupService {
  FestivalSetupService({
    required this.pointerService,
    required this.dropboxApi,
  });

  final PointerService pointerService;
  final DropboxApi dropboxApi;

  /// Build JSON bytes for [workspace], optionally including reports/alerts URLs.
  Uint8List encodeExportBytes(
    FestivalWorkspace workspace, {
    required bool includeReports,
    required bool includeAlerts,
  }) {
    final package = FestivalSetupPackage.fromWorkspace(
      workspace,
      includeReports: includeReports,
      includeAlerts: includeAlerts,
    );
    return Uint8List.fromList(utf8.encode(package.toPrettyJson()));
  }

  /// Save a setup file via desktop Save As or mobile share sheet.
  Future<SavedExport?> exportToFile(
    FestivalWorkspace workspace, {
    required bool includeReports,
    required bool includeAlerts,
    Rect? sharePositionOrigin,
  }) {
    final name = FestivalSetupPackage.suggestedFileName(workspace.festivalName);
    return saveExportBytes(
      bytes: encodeExportBytes(
        workspace,
        includeReports: includeReports,
        includeAlerts: includeAlerts,
      ),
      suggestedName: name,
      extension: 'json',
      mimeType: 'application/json',
      typeLabel: 'Festival setup',
      sharePositionOrigin: sharePositionOrigin,
    );
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
