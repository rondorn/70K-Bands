import 'package:promoter_admin/src/models/dropbox_folder_access.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_year_service.dart';

/// Persisted Dropbox folder paths ([FestivalWorkspace] `*FilesFolderPath` fields)
/// are a performance cache. Share URLs remain authoritative.
///
/// **Load:** the UI reads cached paths and persisted `canEdit*` flags immediately.
/// **Background:** [refreshFromUrls] re-resolves paths from URLs; if anything
/// changed, the app persists updates and refreshes the UI silently.
class FestivalFolderPathCache {
  FestivalFolderPathCache._();

  static String normalize(String path) {
    var p = path.trim().replaceAll('\\', '/');
    if (p.isEmpty) return '';
    if (!p.startsWith('/')) p = '/$p';
    return p.replaceAll(RegExp(r'/+$'), '');
  }

  static bool equal(String a, String b) => normalize(a) == normalize(b);

  static bool cacheDiffers(FestivalWorkspace before, FestivalWorkspace after) {
    return !equal(before.masterFilesFolderPath, after.masterFilesFolderPath) ||
        !equal(before.artistFilesFolderPath, after.artistFilesFolderPath) ||
        !equal(before.scheduleFilesFolderPath, after.scheduleFilesFolderPath) ||
        !equal(
          before.descriptionFilesFolderPath,
          after.descriptionFilesFolderPath,
        ) ||
        !equal(before.alertFilesFolderPath, after.alertFilesFolderPath);
  }

  static bool writeAccessDiffers(
    FestivalWorkspace before,
    FestivalWorkspace after,
  ) {
    return before.canEditBands != after.canEditBands ||
        before.canEditSchedule != after.canEditSchedule ||
        before.canEditDescriptions != after.canEditDescriptions ||
        before.canEditPointers != after.canEditPointers ||
        before.canEditAlerts != after.canEditAlerts;
  }

  static bool ownershipDiffers(
    FestivalWorkspace before,
    FestivalWorkspace after,
  ) {
    return before.ownsMasterFilesFolder != after.ownsMasterFilesFolder ||
        before.ownsArtistFilesFolder != after.ownsArtistFilesFolder ||
        before.ownsScheduleFilesFolder != after.ownsScheduleFilesFolder ||
        before.ownsDescriptionFilesFolder != after.ownsDescriptionFilesFolder ||
        before.ownsAlertFilesFolder != after.ownsAlertFilesFolder;
  }

  /// Whether a background Dropbox probe found anything worth refreshing in UI.
  static bool backgroundProbeDiffers(
    FestivalWorkspace before,
    FestivalWorkspace after,
  ) {
    return cacheDiffers(before, after) ||
        writeAccessDiffers(before, after) ||
        ownershipDiffers(before, after);
  }

  /// Persisted fields that should be written when a background probe changes them.
  static bool persistedProbeDiffers(
    FestivalWorkspace before,
    FestivalWorkspace after,
  ) {
    return cacheDiffers(before, after) || writeAccessDiffers(before, after);
  }

  /// Resolve folder paths from share URLs and update the workspace cache.
  ///
  /// Returns [cacheChanged] when any cached path was invalidated or refreshed.
  static Future<({FestivalWorkspace workspace, bool cacheChanged})>
      refreshFromUrls(
    FestivalWorkspace workspace,
    DropboxApi dropboxApi,
  ) async {
    final updated = await _resolveAllFromUrls(workspace, dropboxApi);
    return (
      workspace: updated,
      cacheChanged: cacheDiffers(workspace, updated),
    );
  }

  static Future<FestivalWorkspace> _resolveAllFromUrls(
    FestivalWorkspace workspace,
    DropboxApi dropboxApi,
  ) async {
    Future<String?> parentOf(String url) async {
      final trimmed = url.trim();
      if (trimmed.isEmpty) return null;
      try {
        final path = await dropboxApi.resolveApiPath(trimmed);
        return FestivalYearService.parentFolderOfPath(path);
      } catch (_) {
        return null;
      }
    }

    final artist = workspace.bandListUrl.trim().isNotEmpty
        ? await parentOf(workspace.bandListUrl)
        : null;
    final schedule = workspace.scheduleUrl.trim().isNotEmpty
        ? await parentOf(workspace.scheduleUrl)
        : null;
    final description = workspace.descriptionMapUrl.trim().isNotEmpty
        ? await parentOf(workspace.descriptionMapUrl)
        : null;

    String? alert;
    final alertUrl = workspace.alertFolderUrl.trim();
    if (alertUrl.isNotEmpty) {
      try {
        alert = await dropboxApi.resolveApiPath(alertUrl);
      } catch (_) {
        alert = null;
      }
    }

    String? master;
    for (final url in [
      workspace.testingPointerUrl,
      workspace.productionPointerUrl,
    ]) {
      final parent = await parentOf(url);
      if (parent != null) {
        master = parent;
        break;
      }
    }

    return workspace.copyWith(
      masterFilesFolderPath: _masterCacheValue(workspace, master),
      artistFilesFolderPath: _dataFileCacheValue(
        workspace.bandListUrl,
        workspace.artistFilesFolderPath,
        artist,
      ),
      scheduleFilesFolderPath: _dataFileCacheValue(
        workspace.scheduleUrl,
        workspace.scheduleFilesFolderPath,
        schedule,
      ),
      descriptionFilesFolderPath: _dataFileCacheValue(
        workspace.descriptionMapUrl,
        workspace.descriptionFilesFolderPath,
        description,
      ),
      alertFilesFolderPath:
          alertUrl.isEmpty ? '' : (alert ?? workspace.alertFilesFolderPath),
    );
  }

  static String _dataFileCacheValue(
    String shareUrl,
    String cached,
    String? resolved,
  ) {
    if (shareUrl.trim().isEmpty) return cached;
    return resolved ?? cached;
  }

  static String _masterCacheValue(FestivalWorkspace workspace, String? resolved) {
    final hasPointer = workspace.testingPointerUrl.trim().isNotEmpty ||
        workspace.productionPointerUrl.trim().isNotEmpty;
    if (!hasPointer) return workspace.masterFilesFolderPath;
    return resolved ?? workspace.masterFilesFolderPath;
  }

  /// Fast path: return a cached folder path when present.
  static String? cachedPathFor(
    FestivalWorkspace workspace,
    FestivalAccessFolderKind kind,
  ) {
    final path = switch (kind) {
      FestivalAccessFolderKind.master => workspace.masterFilesFolderPath,
      FestivalAccessFolderKind.artists => workspace.artistFilesFolderPath,
      FestivalAccessFolderKind.schedule => workspace.scheduleFilesFolderPath,
      FestivalAccessFolderKind.descriptions =>
        workspace.descriptionFilesFolderPath,
      FestivalAccessFolderKind.alerts => workspace.alertFilesFolderPath,
    }.trim();
    return path.isEmpty ? null : path;
  }

  /// Authoritative path for sharing actions — always resolves from URLs when set.
  static Future<String?> resolveFromUrlsForSharing(
    FestivalWorkspace workspace,
    DropboxApi dropboxApi,
    FestivalAccessFolderKind kind,
  ) async {
    switch (kind) {
      case FestivalAccessFolderKind.alerts:
        final alertUrl = workspace.alertFolderUrl.trim();
        if (alertUrl.isEmpty) return null;
        try {
          return await dropboxApi.resolveApiPath(alertUrl);
        } catch (_) {
          return cachedPathFor(workspace, kind);
        }

      case FestivalAccessFolderKind.master:
        for (final url in [
          workspace.testingPointerUrl,
          workspace.productionPointerUrl,
        ]) {
          final trimmed = url.trim();
          if (trimmed.isEmpty) continue;
          try {
            final apiPath = await dropboxApi.resolveApiPath(trimmed);
            return FestivalYearService.parentFolderOfPath(apiPath);
          } catch (_) {}
        }
        return cachedPathFor(workspace, kind);

      case FestivalAccessFolderKind.artists:
        return _parentFolderFromFileUrl(
          dropboxApi,
          workspace.bandListUrl,
          workspace,
          kind,
        );

      case FestivalAccessFolderKind.schedule:
        return _parentFolderFromFileUrl(
          dropboxApi,
          workspace.scheduleUrl,
          workspace,
          kind,
        );

      case FestivalAccessFolderKind.descriptions:
        return _parentFolderFromFileUrl(
          dropboxApi,
          workspace.descriptionMapUrl,
          workspace,
          kind,
        );
    }
  }

  static Future<String?> _parentFolderFromFileUrl(
    DropboxApi dropboxApi,
    String shareUrl,
    FestivalWorkspace workspace,
    FestivalAccessFolderKind kind,
  ) async {
    final url = shareUrl.trim();
    if (url.isEmpty) return cachedPathFor(workspace, kind);
    try {
      final apiPath = await dropboxApi.resolveApiPath(url);
      return FestivalYearService.parentFolderOfPath(apiPath);
    } catch (_) {
      return cachedPathFor(workspace, kind);
    }
  }
}
