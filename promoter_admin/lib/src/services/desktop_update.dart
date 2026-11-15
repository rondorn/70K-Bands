import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

const desktopUpdateRepo = 'rondorn/70K-Bands';
const _userAgent = 'OpenMetalFestAdmin';
const macAppBundleName = 'Open Metal Fest Admin.app';
const macApplicationsDestination = '/Applications/$macAppBundleName';

/// Installed or published app version (`1.0.28a` + build `1`).
///
/// A trailing letter is an iteration of the same numeric version:
/// `1.0.28` < `1.0.28a` < `1.0.28b`. `1.0.28-a` is the same version as
/// `1.0.28a`.
class DesktopAppVersion implements Comparable<DesktopAppVersion> {
  const DesktopAppVersion(this.parts, this.letter, this.build);

  final List<int> parts;

  /// 0 is no letter. 1 is `a`, 2 is `b`, and so on.
  final int letter;
  final int build;

  static final _name = RegExp(r'^(\d+(?:\.\d+)*)-?([a-z])?$');

  factory DesktopAppVersion.parse(String name, [String build = '0']) {
    final match = _name.firstMatch(name.trim().toLowerCase());
    final pieces = match == null
        ? const <int>[0]
        : match.group(1)!.split('.').map((part) => int.parse(part)).toList();
    final letterChar = match?.group(2);
    final letter = letterChar == null ? 0 : letterChar.codeUnitAt(0) - 96;
    return DesktopAppVersion(pieces, letter, int.tryParse(build.trim()) ?? 0);
  }

  int part(int index) => index < parts.length ? parts[index] : 0;

  String get label {
    final suffix = letter == 0 ? '' : String.fromCharCode(96 + letter);
    return '${parts.join('.')}$suffix ($build)';
  }

  @override
  int compareTo(DesktopAppVersion other) {
    final count = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < count; i++) {
      final delta = part(i) - other.part(i);
      if (delta != 0) return delta;
    }
    final letterDelta = letter - other.letter;
    if (letterDelta != 0) return letterDelta;
    return build - other.build;
  }

  bool operator >(DesktopAppVersion other) => compareTo(other) > 0;
}

class DesktopUpdateOffer {
  const DesktopUpdateOffer({
    required this.version,
    required this.assetName,
    required this.downloadUrl,
  });

  final DesktopAppVersion version;
  final String assetName;
  final String downloadUrl;
}

class PreparedDesktopUpdate {
  const PreparedDesktopUpdate({
    required this.version,
    required this.payloadPath,
    required this.installPath,
  });

  /// macOS: the unpacked `.app`. Windows: the folder that contains the exe.
  final DesktopAppVersion version;
  final String payloadPath;

  /// macOS: destination `.app`. Windows: folder to copy into.
  final String installPath;
}

bool get desktopUpdatesSupported {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
  return Platform.isMacOS || Platform.isWindows;
}

String? macBundlePathFromExecutable(String executable) {
  const marker = '.app/Contents/MacOS/';
  final index = executable.indexOf(marker);
  if (index < 0) return null;
  return executable.substring(0, index + 4);
}

bool macBundleIsTranslocated(String bundlePath) {
  return bundlePath.contains('AppTranslocation');
}

/// Where a Mac update is installed. A translocated Downloads launch cannot
/// be replaced in place, so those installs go to Applications.
String macUpdateDestination(String executable) {
  final bundle = macBundlePathFromExecutable(executable);
  if (bundle == null || macBundleIsTranslocated(bundle)) {
    return macApplicationsDestination;
  }
  return bundle;
}

/// Pick the newest matching zip from a GitHub release JSON body.
DesktopUpdateOffer? desktopUpdateOfferFromReleaseJson(
  String body, {
  required bool windows,
  required DesktopAppVersion current,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final assets = decoded['assets'];
  if (assets is! List) return null;

  final pattern = windows
      ? RegExp(r'^omf-admin-windows-(\d+(?:\.\d+)*(?:-?[a-zA-Z])?)_(\d+)\.zip$')
      : RegExp(r'^omf-admin-macos-(\d+(?:\.\d+)*(?:-?[a-zA-Z])?)_(\d+)\.zip$');

  DesktopUpdateOffer? best;
  for (final asset in assets) {
    if (asset is! Map) continue;
    final name = '${asset['name'] ?? ''}';
    final match = pattern.firstMatch(name);
    if (match == null) continue;
    final url = '${asset['browser_download_url'] ?? ''}'.trim();
    if (url.isEmpty) continue;
    final version = DesktopAppVersion.parse(match.group(1)!, match.group(2)!);
    if (!(version > current)) continue;
    if (best == null || version > best.version) {
      best = DesktopUpdateOffer(
        version: version,
        assetName: name,
        downloadUrl: url,
      );
    }
  }
  return best;
}

Future<DesktopUpdateOffer?> lookupDesktopUpdate({
  http.Client? client,
  DesktopAppVersion? current,
}) async {
  if (!desktopUpdatesSupported && current == null) return null;
  final info = current ?? await _currentVersion();
  final tag = Platform.isWindows ? 'omf-admin-windows' : 'omf-admin-macos';
  final uri = Uri.parse(
    'https://api.github.com/repos/$desktopUpdateRepo/releases/tags/$tag',
  );
  if (client == null && Platform.isWindows) {
    final body = await _windowsReleaseBody(uri);
    if (body == null) return null;
    return desktopUpdateOfferFromReleaseJson(
      body,
      windows: true,
      current: info,
    );
  }
  final httpClient = client ?? http.Client();
  final closeClient = client == null;
  try {
    final response = await httpClient
        .get(
          uri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': _userAgent,
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return desktopUpdateOfferFromReleaseJson(
      response.body,
      windows: Platform.isWindows,
      current: info,
    );
  } catch (_) {
    return null;
  } finally {
    if (closeClient) httpClient.close();
  }
}

/// Windows Dart TLS does not use the certificate store the browser uses.
/// PowerShell does, so the update check follows the same trust as that browser.
Future<String?> _windowsReleaseBody(Uri uri) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}omf-release-$pid.json',
  );
  if (await file.exists()) await file.delete();
  final saved = await _windowsSaveUrl(
    uri.toString(),
    file.path,
    timeoutSeconds: 25,
  );
  if (saved.exitCode == 404) return null;
  if (saved.exitCode != 0 || !await file.exists()) {
    final detail = saved.error.isEmpty ? 'code ${saved.exitCode}' : saved.error;
    throw StateError('Could not check GitHub for an update. $detail');
  }
  final body = (await file.readAsString()).trim();
  if (body.isEmpty) {
    throw StateError('Could not check GitHub for an update.');
  }
  return body.startsWith('\uFEFF') ? body.substring(1) : body;
}

class _WindowsUrlSave {
  const _WindowsUrlSave(this.exitCode, this.error);

  final int exitCode;
  final String error;
}

Future<_WindowsUrlSave> _windowsSaveUrl(
  String url,
  String outPath, {
  required int timeoutSeconds,
}) async {
  final script = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}omf-fetch-$pid.ps1',
  );
  final quotedUrl = url.replaceAll("'", "''");
  final quotedOut = outPath.replaceAll("'", "''");
  await script.writeAsString('''
\$ProgressPreference = 'SilentlyContinue'
\$protocols = [Net.SecurityProtocolType]::Tls12
if ([enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls13') {
  \$protocols = \$protocols -bor [Net.SecurityProtocolType]::Tls13
}
[Net.ServicePointManager]::SecurityProtocol = \$protocols
\$headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = '$_userAgent' }
try {
  Invoke-WebRequest -UseBasicParsing -TimeoutSec $timeoutSeconds -Headers \$headers -Uri '$quotedUrl' -OutFile '$quotedOut'
  exit 0
} catch {
  \$response = \$_.Exception.Response
  if (\$null -ne \$response) {
    [Console]::Error.WriteLine(\$_.Exception.Message)
    exit [int]\$response.StatusCode
  }
  [Console]::Error.WriteLine(\$_.Exception.Message)
  exit 1
}
''');
  final result = await Process.run('powershell', [
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    script.path,
  ]);
  return _WindowsUrlSave(result.exitCode, '${result.stderr}'.trim());
}

Future<DesktopAppVersion> _currentVersion() async {
  final info = await PackageInfo.fromPlatform();
  return DesktopAppVersion.parse(info.version, info.buildNumber);
}

/// Download the zip and unpack it. Throws on failure. [onProgress] receives
/// 0..1, or null when the server omits the size.
Future<PreparedDesktopUpdate> prepareDesktopUpdate(
  DesktopUpdateOffer offer, {
  void Function(double? progress)? onProgress,
  bool Function()? isCancelled,
}) async {
  final root = await Directory.systemTemp.createTemp('omf-update-');
  final zip = File('${root.path}/${offer.assetName}');
  await _download(
    offer.downloadUrl,
    zip,
    onProgress: onProgress,
    isCancelled: isCancelled,
  );
  if (isCancelled?.call() == true) {
    throw const DesktopUpdateCancelled();
  }
  final unpacked = Directory('${root.path}/unpacked');
  await unpacked.create();
  await _unzip(zip.path, unpacked.path);
  if (isCancelled?.call() == true) {
    throw const DesktopUpdateCancelled();
  }
  if (Platform.isMacOS) {
    if (macBundlePathFromExecutable(Platform.resolvedExecutable) == null) {
      throw StateError(
        'Updates can only be installed from the downloaded app.',
      );
    }
    final app = Directory('${unpacked.path}/$macAppBundleName');
    if (!await app.exists()) {
      throw StateError('The update did not contain $macAppBundleName.');
    }
    return PreparedDesktopUpdate(
      version: offer.version,
      payloadPath: app.path,
      installPath: macUpdateDestination(Platform.resolvedExecutable),
    );
  }
  final exe = File('${unpacked.path}/promoter_admin.exe');
  if (!await exe.exists()) {
    throw StateError('The update did not contain promoter_admin.exe.');
  }
  final installDir = File(Platform.resolvedExecutable).parent.path;
  return PreparedDesktopUpdate(
    version: offer.version,
    payloadPath: unpacked.path,
    installPath: installDir,
  );
}

const macDragInstallFolderName = 'Open Metal Fest Admin Update';

String macDragInstallDirectory(String home) {
  return '$home/Downloads/$macDragInstallFolderName';
}

const macDragInstallNoteName = 'Drag onto Applications.txt';

const macDragInstallSteps =
    'This app has closed so macOS can replace it.\n\n'
    '1. Drag Open Metal Fest Admin onto Applications.\n'
    '2. If macOS asks to replace the app, choose Replace.\n'
    '3. Open Open Metal Fest Admin from Applications.\n\n'
    'Do not open the copy that is still in Downloads.';

/// Expand the downloaded app into Downloads and open that folder in Finder.
/// Sandbox sets HOME to the app container. The real Downloads folder is elsewhere.
String? homeDirectoryFromIdP(String line) {
  final parts = line.trim().split(':');
  if (parts.length < 9) return null;
  final home = parts[8].trim();
  if (!home.startsWith('/')) return null;
  return home;
}

Future<String> macRealHomeDirectory() async {
  try {
    const channel = MethodChannel(
      'com.rdorn.open-metal-fest-admin/desktop_update',
    );
    final home = await channel.invokeMethod<String>('realHomeDirectory');
    if (home != null && home.startsWith('/Users/')) return home;
  } catch (_) {}
  final id = await Process.run('/usr/bin/id', ['-P']);
  final home = homeDirectoryFromIdP('${id.stdout}');
  if (id.exitCode == 0 && home != null) return home;
  throw StateError('Could not find your Downloads folder.');
}

Future<String> stageMacDragInstall(String sourceApp) async {
  final home = await macRealHomeDirectory();
  final folder = macDragInstallDirectory(home);
  final appDest = '$folder/$macAppBundleName';
  await Process.run('/bin/rm', ['-rf', folder]);
  await Directory(folder).create(recursive: true);
  final copied = await Process.run('/usr/bin/ditto', [
    '--norsrc',
    '--noextattr',
    sourceApp,
    appDest,
  ]);
  if (copied.exitCode != 0) {
    throw StateError('Could not prepare the update in Downloads.');
  }
  if (!await Directory('$appDest/Contents/MacOS').exists()) {
    throw StateError('The update did not contain an app.');
  }
  await Process.run('/usr/bin/xattr', ['-cr', appDest]);
  await File(
    '$folder/$macDragInstallNoteName',
  ).writeAsString(macDragInstallSteps);
  final link = await Process.run('/bin/ln', [
    '-sfn',
    '/Applications',
    '$folder/Applications',
  ]);
  await revealInFinder(folder);
  if (link.exitCode != 0) {
    await revealInFinder('/Applications');
  }
  return folder;
}

Future<void> revealInFinder(String folder) async {
  try {
    const channel = MethodChannel(
      'com.rdorn.open-metal-fest-admin/desktop_update',
    );
    await channel.invokeMethod<void>('revealFolder', folder);
    return;
  } on MissingPluginException {
    // Fall through to the open command.
  } on PlatformException catch (error) {
    final message = error.message?.trim() ?? '';
    throw StateError(
      message.isEmpty ? 'Could not open the update in Finder.' : message,
    );
  }
  final opened = await Process.run('/usr/bin/open', [folder]);
  if (opened.exitCode != 0) {
    throw StateError(
      'The update is in $folder. Drag the app onto Applications.',
    );
  }
}

/// Leave the .app bundle so Finder can replace it. A running app cannot be replaced.
Future<void> quitMacApp() async {
  try {
    const channel = MethodChannel(
      'com.rdorn.open-metal-fest-admin/desktop_update',
    );
    await channel.invokeMethod<void>('quitApp');
  } catch (_) {}
  exit(0);
}

/// Quit this process after the new Windows files are in place, then open them.
Future<void> relaunchIntoDesktopUpdate(PreparedDesktopUpdate update) async {
  if (Platform.isWindows) {
    if (!await _directoryIsWritable(update.installPath)) {
      throw StateError(
        'This folder is not writable, so the update cannot replace the app. '
        'Move the app to a folder you can write to and try again.',
      );
    }
    final script = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}omf-update-$pid.ps1',
    );
    await script.writeAsString(windowsInstallHelperScript());
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script.path,
      '-WaitPid',
      '$pid',
      '-Source',
      update.payloadPath,
      '-Dest',
      update.installPath,
    ]);
    if (result.exitCode != 0) {
      final detail = '${result.stderr}'.trim();
      throw StateError(detail.isEmpty ? 'The update did not install.' : detail);
    }
    exit(0);
  }

  throw StateError('This Mac update is installed from Finder.');
}

/// Moves the running files aside, copies the new tree in, then starts it.
///
/// Windows lets a running exe be renamed, so the swap happens before this
/// process exits. Copy-Item onto the live folder fails and leaves the old app.
String windowsInstallHelperScript() => r'''
param(
  [int]$WaitPid,
  [string]$Source,
  [string]$Dest
)
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'omf-update-last.log'
function Log($message) {
  Add-Content -LiteralPath $log -Value ("{0} {1}" -f (Get-Date -Format o), $message)
}
$backup = Join-Path $env:TEMP "omf-previous-$WaitPid"
if (Test-Path -LiteralPath $backup) {
  Remove-Item -LiteralPath $backup -Recurse -Force
}
New-Item -ItemType Directory -Path $backup | Out-Null

function Move-Aside($from, $to) {
  New-Item -ItemType Directory -Force -Path $to | Out-Null
  Get-ChildItem -LiteralPath $from -Force | ForEach-Object {
    $target = Join-Path $to $_.Name
    if ($_.PSIsContainer) {
      Move-Aside $_.FullName $target
      if (Test-Path -LiteralPath $_.FullName) {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
      }
    } else {
      $moved = $false
      for ($i = 0; $i -lt 20 -and -not $moved; $i++) {
        try {
          Move-Item -LiteralPath $_.FullName -Destination $target -Force -ErrorAction Stop
          $moved = $true
        } catch {
          Start-Sleep -Milliseconds 300
        }
      }
      if (-not $moved) { throw "Could not move $($_.Name)" }
    }
  }
}

function Restore-Backup {
  if (-not (Test-Path -LiteralPath $backup)) { return }
  Get-ChildItem -LiteralPath $Dest -Force -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
  }
  Move-Aside $backup $Dest
}

try {
  Log "move $Dest aside"
  Move-Aside $Dest $backup
  Log "copy $Source"
  & robocopy $Source $Dest /E /R:5 /W:1 /NFL /NDL /NJH /NJS /NP
  $code = $LASTEXITCODE
  if ($code -ge 8) { throw "Could not copy the update (robocopy $code)." }
  $exe = Join-Path $Dest 'promoter_admin.exe'
  if (-not (Test-Path -LiteralPath $exe)) {
    throw 'The update did not contain promoter_admin.exe.'
  }
  Log "start $exe"
  Start-Process -FilePath $exe -WorkingDirectory $Dest
  Log 'started'
  exit 0
} catch {
  Log "failed: $($_.Exception.Message)"
  try { Restore-Backup } catch { Log "restore failed: $($_.Exception.Message)" }
  [Console]::Error.WriteLine($_.Exception.Message)
  exit 1
}
''';

Future<void> _removeMacInstallLeftovers() async {
  if (!Platform.isMacOS) return;
  final bundle = macBundlePathFromExecutable(Platform.resolvedExecutable);
  if (bundle == null) return;
  for (final suffix in const ['.previous', '.updating']) {
    await Process.run('/bin/rm', ['-rf', '$bundle$suffix']);
  }
}

Future<bool> _directoryIsWritable(String path) async {
  final probe = File('$path/.omf-update-probe-$pid');
  try {
    await probe.writeAsString('ok');
  } catch (_) {
    return false;
  }
  try {
    await probe.delete();
  } catch (_) {}
  return true;
}

Future<void> _download(
  String url,
  File dest, {
  void Function(double? progress)? onProgress,
  bool Function()? isCancelled,
}) async {
  if (Platform.isWindows) {
    final saved = await _windowsSaveUrl(url, dest.path, timeoutSeconds: 180);
    final size = await dest.exists() ? await dest.length() : 0;
    if (saved.exitCode == 0 && size > 0) {
      onProgress?.call(1);
      return;
    }
    final detail = saved.error.isEmpty ? 'code ${saved.exitCode}' : saved.error;
    throw StateError('Download failed. $detail');
  }
  final client = http.Client();
  IOSink? sink;
  try {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = _userAgent;
    final response = await client
        .send(request)
        .timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Download failed (HTTP ${response.statusCode}).');
    }
    final total = response.contentLength;
    var received = 0;
    sink = dest.openWrite();
    await for (final chunk in response.stream) {
      if (isCancelled?.call() == true) {
        throw const DesktopUpdateCancelled();
      }
      sink.add(chunk);
      received += chunk.length;
      if (total == null || total <= 0) {
        onProgress?.call(null);
      } else {
        onProgress?.call(received / total);
      }
    }
    await sink.flush();
    await sink.close();
    sink = null;
  } finally {
    if (sink != null) {
      await sink.close();
    }
    client.close();
  }
}

Future<void> _unzip(String zipPath, String destination) async {
  if (Platform.isMacOS) {
    final result = await Process.run('ditto', [
      '-x',
      '-k',
      zipPath,
      destination,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Could not unpack the update.');
    }
    return;
  }
  final result = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    "Expand-Archive -LiteralPath '${zipPath.replaceAll("'", "''")}' "
        "-DestinationPath '${destination.replaceAll("'", "''")}' -Force",
  ]);
  if (result.exitCode != 0) {
    throw StateError('Could not unpack the update.');
  }
}

class DesktopUpdateCancelled implements Exception {
  const DesktopUpdateCancelled();
}

Future<void> promptForDesktopUpdate(
  GlobalKey<NavigatorState> navigatorKey,
) async {
  if (!desktopUpdatesSupported) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_promptWhenReady(navigatorKey));
  });
}

Future<void> _promptWhenReady(GlobalKey<NavigatorState> navigatorKey) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      await _runUpdatePrompt(context);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
}

Future<void> _runUpdatePrompt(BuildContext context) async {
  if (Platform.isMacOS &&
      macBundlePathFromExecutable(Platform.resolvedExecutable) == null) {
    return;
  }
  unawaited(_removeMacInstallLeftovers());
  final DesktopUpdateOffer? offer;
  try {
    offer = await lookupDesktopUpdate();
  } catch (e) {
    if (context.mounted) {
      await _showUpdateError(context, e, title: 'Update check failed');
    }
    return;
  }
  if (offer == null || !context.mounted) return;
  final ready = offer;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Update available'),
      content: Text(
        'Version ${ready.version.label} of ${AppBrand.name} is ready to install.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Update'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;

  final cancelled = ValueNotifier(false);
  final progress = ValueNotifier<double?>(null);
  final shown = Completer<void>();
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      if (!shown.isCompleted) shown.complete();
      return AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Downloading update'),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: value, color: AppColors.accent),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled.value = true;
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
  await shown.future;

  PreparedDesktopUpdate prepared;
  try {
    prepared = await prepareDesktopUpdate(
      ready,
      onProgress: (value) => progress.value = value,
      isCancelled: () => cancelled.value,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await dialog;
  } on DesktopUpdateCancelled {
    return;
  } catch (e) {
    if (cancelled.value) return;
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await dialog;
      if (context.mounted) await _showUpdateError(context, e);
    }
    return;
  }
  if (!context.mounted) return;

  if (Platform.isMacOS) {
    await _finishMacDragInstall(context, prepared);
    return;
  }

  final relaunch = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Update ready'),
      content: Text(
        'Relaunch ${AppBrand.name} to finish installing version ${ready.version.label}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Relaunch'),
        ),
      ],
    ),
  );
  if (relaunch != true || !context.mounted) return;
  final installing = Completer<void>();
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!installing.isCompleted) installing.complete();
        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Installing update'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text('The new version will open, then this copy will close.'),
            ],
          ),
        );
      },
    ),
  );
  await installing.future;
  try {
    await relaunchIntoDesktopUpdate(prepared);
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await _showUpdateError(context, e);
    }
  }
}

Future<void> _finishMacDragInstall(
  BuildContext context,
  PreparedDesktopUpdate prepared,
) async {
  final preparing = Completer<void>();
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!preparing.isCompleted) preparing.complete();
        return const AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('Preparing update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text(
                'Finder will open, then this app will close so you can replace it.',
              ),
            ],
          ),
        );
      },
    ),
  );
  await preparing.future;
  try {
    await stageMacDragInstall(prepared.payloadPath);
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await _showUpdateError(context, e);
    }
    return;
  }
  await quitMacApp();
}

Future<void> _showUpdateError(
  BuildContext context,
  Object error, {
  String title = 'Update failed',
}) {
  var message = error is StateError ? error.message : '$error';
  message = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (message.length > 400) {
    message = '${message.substring(0, 400)}…';
  }
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
