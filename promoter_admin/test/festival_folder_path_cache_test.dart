import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/dropbox_folder_access.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/festival_folder_path_cache.dart';

void main() {
  test('normalize treats trailing slashes and missing leading slash as equal', () {
    expect(
      FestivalFolderPathCache.equal(
        '/Maryland Deathfest_Alert_Files',
        'Maryland Deathfest_Alert_Files/',
      ),
      isTrue,
    );
  });

  test('cacheDiffers detects alert folder move', () {
    const before = FestivalWorkspace(
      alertFolderUrl: 'https://dropbox.example/old-folder',
      alertFilesFolderPath: '/Old_Alert_Files',
    );
    final after = before.copyWith(
      alertFilesFolderPath: '/Maryland Deathfest_Alert_Files',
    );
    expect(FestivalFolderPathCache.cacheDiffers(before, after), isTrue);
    expect(FestivalFolderPathCache.cacheDiffers(after, after), isFalse);
  });

  test('cachedPathFor returns null when path is empty', () {
    const workspace = FestivalWorkspace();
    expect(
      FestivalFolderPathCache.cachedPathFor(
        workspace,
        FestivalAccessFolderKind.alerts,
      ),
      isNull,
    );
  });

  test('backgroundProbeDiffers ignores unchanged workspace', () {
    const workspace = FestivalWorkspace(
      alertFilesFolderPath: '/Festival_Alert_Files',
      canEditAlerts: true,
      ownsAlertFilesFolder: true,
    );
    expect(
      FestivalFolderPathCache.backgroundProbeDiffers(workspace, workspace),
      isFalse,
    );
  });

  test('backgroundProbeDiffers detects ownership-only change', () {
    const before = FestivalWorkspace(ownsAlertFilesFolder: false);
    const after = FestivalWorkspace(ownsAlertFilesFolder: true);
    expect(
      FestivalFolderPathCache.backgroundProbeDiffers(before, after),
      isTrue,
    );
    expect(
      FestivalFolderPathCache.persistedProbeDiffers(before, after),
      isFalse,
    );
  });
}
