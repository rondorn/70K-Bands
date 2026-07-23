/// Dropbox shared-folder member (for folder-level access control UI).
class DropboxFolderMember {
  const DropboxFolderMember({
    required this.email,
    required this.displayName,
    required this.dropboxId,
    required this.accessLevel,
    this.isOwner = false,
  });

  final String email;
  final String displayName;
  final String dropboxId;
  final String accessLevel;
  final bool isOwner;
}

/// Resolved sharing metadata for a Dropbox folder path.
class DropboxFolderAccessInfo {
  const DropboxFolderAccessInfo({
    required this.apiPath,
    required this.sharedFolderId,
    required this.isOwner,
  });

  final String apiPath;
  final String sharedFolderId;
  final bool isOwner;

  bool get canManageMembers => isOwner && sharedFolderId.isNotEmpty;
}

/// Which festival data folder is being managed in Settings.
enum FestivalAccessFolderKind {
  master,
  artists,
  schedule,
  descriptions,
  alerts;

  String get settingsLabel {
    switch (this) {
      case FestivalAccessFolderKind.master:
        return 'Master';
      case FestivalAccessFolderKind.artists:
        return 'Artists';
      case FestivalAccessFolderKind.schedule:
        return 'Schedule';
      case FestivalAccessFolderKind.descriptions:
        return 'Descriptions';
      case FestivalAccessFolderKind.alerts:
        return 'Alerts';
    }
  }

  String get grantButtonLabel {
    switch (this) {
      case FestivalAccessFolderKind.master:
        return 'Grant Master Access Rights';
      case FestivalAccessFolderKind.artists:
        return 'Grant Artists Access Rights';
      case FestivalAccessFolderKind.schedule:
        return 'Grant Schedule Access Rights';
      case FestivalAccessFolderKind.descriptions:
        return 'Grant Description Access Rights';
      case FestivalAccessFolderKind.alerts:
        return 'Grant Alert Monitoring Access Rights';
    }
  }
}
