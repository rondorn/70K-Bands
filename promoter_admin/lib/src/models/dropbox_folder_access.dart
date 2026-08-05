/// Dropbox shared-folder member (for folder-level access control UI).
class DropboxFolderMember {
  const DropboxFolderMember({
    required this.email,
    required this.displayName,
    required this.dropboxId,
    required this.accessLevel,
    this.isOwner = false,
    this.isPendingInvite = false,
  });

  final String email;
  final String displayName;
  final String dropboxId;
  final String accessLevel;
  final bool isOwner;

  /// True when Dropbox listed this person under `invitees` (invite sent, not
  /// accepted yet). False for accepted `users` and groups.
  final bool isPendingInvite;

  /// Short status for Settings member lists.
  String get accessStatusLabel {
    if (isOwner) return 'Owner';
    if (isPendingInvite) return 'Invite pending';
    if (accessLevel.isEmpty) return 'Member';
    // Dropbox tags are lowercase (editor, viewer); title-case for display.
    return '${accessLevel[0].toUpperCase()}${accessLevel.substring(1)}';
  }
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
