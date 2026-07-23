import 'package:promoter_admin/src/models/dropbox_folder_access.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_folder_path_cache.dart';

/// Grant, list, and revoke Dropbox folder collaborators for festival data.
class DropboxFolderAccessService {
  DropboxFolderAccessService(this.dropboxApi);

  final DropboxApi dropboxApi;

  String folderPathFor(
    FestivalWorkspace workspace,
    FestivalAccessFolderKind kind,
  ) {
    return FestivalFolderPathCache.cachedPathFor(workspace, kind) ?? '';
  }

  bool isOwnerFor(FestivalWorkspace workspace, FestivalAccessFolderKind kind) {
    switch (kind) {
      case FestivalAccessFolderKind.master:
        return workspace.ownsMasterFilesFolder;
      case FestivalAccessFolderKind.artists:
        return workspace.ownsArtistFilesFolder;
      case FestivalAccessFolderKind.schedule:
        return workspace.ownsScheduleFilesFolder;
      case FestivalAccessFolderKind.descriptions:
        return workspace.ownsDescriptionFilesFolder;
      case FestivalAccessFolderKind.alerts:
        return workspace.ownsAlertFilesFolder;
    }
  }

  /// Fast path: use cached folder paths (refreshed in background on launch).
  Future<String?> resolveFolderPath(
    FestivalWorkspace workspace,
    FestivalAccessFolderKind kind,
  ) async {
    final cached = FestivalFolderPathCache.cachedPathFor(workspace, kind);
    if (cached != null) return cached;

    return FestivalFolderPathCache.resolveFromUrlsForSharing(
      workspace,
      dropboxApi,
      kind,
    );
  }

  /// Sharing actions resolve from share URLs so moved folders work immediately.
  Future<String?> resolveFolderPathForSharing(
    FestivalWorkspace workspace,
    FestivalAccessFolderKind kind,
  ) {
    return FestivalFolderPathCache.resolveFromUrlsForSharing(
      workspace,
      dropboxApi,
      kind,
    );
  }

  Future<DropboxFolderAccessInfo?> accessInfoFor(
    FestivalWorkspace workspace,
    FestivalAccessFolderKind kind,
  ) async {
    final path = await resolveFolderPathForSharing(workspace, kind);
    if (path == null) return null;
    return dropboxApi.getFolderAccessInfo(path);
  }

  Future<void> grantEditorAccess({
    required FestivalWorkspace workspace,
    required FestivalAccessFolderKind kind,
    required String email,
  }) async {
    final path = await resolveFolderPathForSharing(workspace, kind);
    if (path == null) {
      throw StateError('No ${kind.settingsLabel.toLowerCase()} folder is configured.');
    }
    final info = await dropboxApi.getFolderAccessInfo(path);
    if (info == null || !info.isOwner) {
      throw StateError(
        'Only the folder owner can grant ${kind.settingsLabel.toLowerCase()} access.',
      );
    }
    final sharedFolderId = info.sharedFolderId.isNotEmpty
        ? info.sharedFolderId
        : await dropboxApi.ensureSharedFolder(path);
    await dropboxApi.addFolderMemberByEmail(
      sharedFolderId: sharedFolderId,
      email: email,
    );
  }

  Future<List<DropboxFolderMember>> listMembers({
    required FestivalWorkspace workspace,
    required FestivalAccessFolderKind kind,
  }) async {
    final path = await resolveFolderPathForSharing(workspace, kind);
    if (path == null) return const [];
    final info = await dropboxApi.getFolderAccessInfo(path);
    if (info == null) return const [];
    final sharedFolderId = info.sharedFolderId.isNotEmpty
        ? info.sharedFolderId
        : (info.isOwner ? await dropboxApi.ensureSharedFolder(path) : '');
    if (sharedFolderId.isEmpty) return const [];
    return dropboxApi.listFolderMembers(sharedFolderId);
  }

  Future<void> revokeMember({
    required FestivalWorkspace workspace,
    required FestivalAccessFolderKind kind,
    required DropboxFolderMember member,
  }) async {
    final path = await resolveFolderPathForSharing(workspace, kind);
    if (path == null) {
      throw StateError('No ${kind.settingsLabel.toLowerCase()} folder is configured.');
    }
    final info = await dropboxApi.getFolderAccessInfo(path);
    if (info == null || !info.isOwner) {
      throw StateError(
        'Only the folder owner can revoke ${kind.settingsLabel.toLowerCase()} access.',
      );
    }
    final sharedFolderId = info.sharedFolderId.isNotEmpty
        ? info.sharedFolderId
        : await dropboxApi.ensureSharedFolder(path);
    await dropboxApi.removeFolderMember(
      sharedFolderId: sharedFolderId,
      member: member,
    );
  }
}
