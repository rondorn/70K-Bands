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
