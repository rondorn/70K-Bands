import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';

/// Discovers stats report HTML files in the configured reports folder.
///
/// The end-user dashboard may also be published on the Production pointer
/// (`Current::reportUrl`). The full dashboard is **never** read from the
/// pointer — it is admin-only and always resolved from [FestivalWorkspace.reportsFolderUrl].
///
/// Discovery results are cached per festival until [FestivalWorkspace.eventYear]
/// or [FestivalWorkspace.reportsFolderUrl] changes. Pass [forceRefresh] to rescan.
class ReportDiscoveryService {
  ReportDiscoveryService._();

  /// Whether saved discovery metadata matches the current folder and event year.
  static bool isCacheValid(FestivalWorkspace workspace) {
    final folder = normalizeDropboxUrl(workspace.reportsFolderUrl.trim());
    final year = workspace.eventYear.trim();
    if (folder.isEmpty || year.isEmpty) return false;
    if (workspace.reportDiscoveryEventYear.trim() != year) return false;
    return normalizeDropboxUrl(workspace.reportDiscoveryFolderUrl.trim()) ==
        folder;
  }

  /// English end-user dashboard filename (`report_dashboard-en_2027.html`, etc.).
  static String? pickMainDashboardName(
    Iterable<String> fileNames,
    String eventYear,
  ) {
    final byLower = <String, String>{};
    for (final name in fileNames) {
      byLower[name.toLowerCase()] = name;
    }

    final year = eventYear.trim();
    final candidates = <String>[
      if (year.isNotEmpty) 'report_dashboard-en_$year.html',
      'report_dashboard-en.html',
      if (year.isNotEmpty) 'report_dashboard_$year.html',
      'report_dashboard.html',
    ];
    for (final candidate in candidates) {
      final match = byLower[candidate.toLowerCase()];
      if (match != null) return match;
    }
    return null;
  }

  /// Full dashboard filename (`report_dashboard_full_2027.html`, etc.).
  static String? pickFullDashboardName(
    Iterable<String> fileNames,
    String eventYear,
  ) {
    final byLower = <String, String>{};
    for (final name in fileNames) {
      byLower[name.toLowerCase()] = name;
    }

    final year = eventYear.trim();
    final candidates = <String>[
      if (year.isNotEmpty) 'report_dashboard_full_$year.html',
      'report_dashboard_full.html',
    ];
    for (final candidate in candidates) {
      final match = byLower[candidate.toLowerCase()];
      if (match != null) return match;
    }
    return null;
  }

  /// List HTML reports in [workspace.reportsFolderUrl] and fill missing URLs.
  ///
  /// Skips the Dropbox folder scan when [isCacheValid] unless [forceRefresh].
  ///
  /// - End-user URL: English dashboard from the folder when present; otherwise
  ///   kept from Production pointer (`reportUrl-en`, then `reportUrl`).
  /// - Full URL: always resolved from the folder (never the pointer).
  static Future<FestivalWorkspace> apply(
    FestivalWorkspace workspace,
    DropboxApi dropboxApi, {
    bool forceRefresh = false,
  }) async {
    final folderUrl = workspace.reportsFolderUrl.trim();
    if (folderUrl.isEmpty) return workspace;
    if (!await dropboxApi.auth.isConnected) return workspace;
    if (!forceRefresh && isCacheValid(workspace)) return workspace;

    try {
      final files = await dropboxApi.listFilesInShareFolder(folderUrl);
      final names = files.map((f) => f.name).toList();
      final year = workspace.eventYear.trim();
      final normalizedFolder = normalizeDropboxUrl(folderUrl);

      var reportUrl = workspace.reportUrl.trim();
      var reportUrlFull = workspace.reportUrlFull.trim();

      final mainName = pickMainDashboardName(names, year);
      final fullName = pickFullDashboardName(names, year);

      if (mainName != null) {
        final file = files.firstWhere((f) => f.name == mainName);
        reportUrl = normalizeDropboxUrl(
          await dropboxApi.shareUrlForPath(file.path),
        );
      }

      if (fullName != null) {
        final file = files.firstWhere((f) => f.name == fullName);
        reportUrlFull = normalizeDropboxUrl(
          await dropboxApi.shareUrlForPath(file.path),
        );
      } else {
        reportUrlFull = '';
      }

      return workspace.copyWith(
        reportUrl: reportUrl.isNotEmpty ? reportUrl : workspace.reportUrl,
        reportUrlFull: reportUrlFull,
        reportDiscoveryEventYear: year,
        reportDiscoveryFolderUrl: normalizedFolder,
      );
    } catch (_) {
      return workspace;
    }
  }
}
