import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';

/// Local File Mode is for desktop compatibility when Dropbox is unavailable (Dropbox folder, git, etc.).
bool get emergencyLocalFileModeSupported {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

extension FestivalWorkspaceEmergencyLocalSupport on FestivalWorkspace {
  /// True only when Local File Mode is enabled and this platform supports it.
  ///
  /// On iOS/Android the stored flag may still be set (e.g. iCloud sync from Mac)
  /// but the app behaves as Dropbox mode.
  bool get usesEmergencyLocalMode =>
      emergencyLocalMode && emergencyLocalFileModeSupported;
}
