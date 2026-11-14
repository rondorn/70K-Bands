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

/// Installed or published app version (`1.0.24` + build `1`).
class DesktopAppVersion implements Comparable<DesktopAppVersion> {
  const DesktopAppVersion(this.parts, this.build);

  final List<int> parts;
  final int build;

  factory DesktopAppVersion.parse(String name, [String build = '0']) {
    final pieces = name
        .trim()
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    if (pieces.isEmpty) pieces.add(0);
    return DesktopAppVersion(pieces, int.tryParse(build.trim()) ?? 0);
  }

  int part(int index) => index < parts.length ? parts[index] : 0;

  String get label => '${parts.join('.')} ($build)';

  @override
  int compareTo(DesktopAppVersion other) {
    final count = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < count; i++) {
      final delta = part(i) - other.part(i);
      if (delta != 0) return delta;
    }
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
      ? RegExp(r'^omf-admin-windows-(\d+(?:\.\d+)*)_(\d+)\.zip$')
      : RegExp(r'^omf-admin-macos-(\d+(?:\.\d+)*)_(\d+)\.zip$');

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

/// Quit this process and let a helper swap in [update], then relaunch.
Future<void> relaunchIntoDesktopUpdate(PreparedDesktopUpdate update) async {
  if (Platform.isWindows) {
    if (!await _directoryIsWritable(update.installPath)) {
      throw StateError(
        'This folder is not writable, so the update cannot replace the app. '
        'Move the app to a folder you can write to and try again.',
      );
    }
    final script = File('${Directory.systemTemp.path}/omf-update-$pid.ps1');
    await script.writeAsString(_windowsHelperScript());
    await Process.start('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-WindowStyle',
      'Hidden',
      '-File',
      script.path,
      '-WaitPid',
      '$pid',
      '-Source',
      update.payloadPath,
      '-Dest',
      update.installPath,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }

  final script = File('${Directory.systemTemp.path}/omf-update-$pid.sh');
  await script.writeAsString(
    macUpdateHelperScript(
      sourceApp: update.payloadPath,
      destApp: update.installPath,
    ),
  );
  final elevated = !await _directoryIsWritable(
    File(update.installPath).parent.path,
  );
  await _runMacInstallScript(script.path, elevated: elevated);
  await _launchMacApp(update.installPath);
  exit(0);
}

Future<void> _runMacInstallScript(
  String scriptPath, {
  required bool elevated,
}) async {
  if (elevated) {
    final authorized = await Process.run('/usr/bin/osascript', [
      '-e',
      'do shell script "/bin/bash ${shellQuote(scriptPath)}" '
          'with administrator privileges',
    ]);
    if (authorized.exitCode != 0) {
      final detail = '${authorized.stderr}'.trim();
      throw StateError(
        detail.isEmpty
            ? 'The update was not installed.'
            : 'The update was not installed. $detail',
      );
    }
    return;
  }
  final result = await Process.run('/bin/bash', [scriptPath]);
  if (result.exitCode != 0) {
    final detail = '${result.stderr}'.trim();
    throw StateError(detail.isEmpty ? 'The update was not installed.' : detail);
  }
}

/// Opens [path] through Launch Services so the new copy is not a child of
/// this sandboxed process. A child would die when this process exits.
Future<void> _launchMacApp(String path) async {
  try {
    const channel = MethodChannel(
      'com.rdorn.open-metal-fest-admin/desktop_update',
    );
    await channel.invokeMethod<void>('launchApp', path);
    return;
  } catch (_) {}
  final opened = await Process.run('/usr/bin/open', ['-n', path]);
  if (opened.exitCode != 0) {
    throw StateError(
      'The update is installed. Quit this window and open ${AppBrand.name} again.',
    );
  }
}

String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

String macUpdateHelperScript({
  required String sourceApp,
  required String destApp,
}) {
  final src = shellQuote(sourceApp);
  final dest = shellQuote(destApp);
  final staging = shellQuote('$destApp.updating');
  final previous = shellQuote('$destApp.previous');
  return '''
#!/bin/bash
set -euo pipefail
rm -rf $staging
ditto $src $staging
xattr -cr $staging || true
if [ ! -d $staging/Contents/MacOS ]; then
  echo "The update did not contain an app." >&2
  rm -rf $staging
  exit 1
fi
rm -rf $previous
if [ -e $dest ]; then
  mv $dest $previous
fi
if ! mv $staging $dest; then
  if [ -e $previous ]; then
    mv $previous $dest || true
  fi
  echo "Could not move the new app into place." >&2
  exit 1
fi
''';
}

String _windowsHelperScript() => r'''
param(
  [int]$WaitPid,
  [string]$Source,
  [string]$Dest
)
$ErrorActionPreference = 'Stop'
while (Get-Process -Id $WaitPid -ErrorAction SilentlyContinue) {
  Start-Sleep -Milliseconds 400
}
Start-Sleep -Milliseconds 600
Copy-Item -Path (Join-Path $Source '*') -Destination $Dest -Recurse -Force
Start-Process -FilePath (Join-Path $Dest 'promoter_admin.exe') -WorkingDirectory $Dest
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
  final offer = await lookupDesktopUpdate();
  if (offer == null || !context.mounted) return;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Update available'),
      content: Text(
        'Version ${offer.version.label} of ${AppBrand.name} is ready to install.',
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
      offer,
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

  final relaunch = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Update ready'),
      content: Text(
        'Relaunch ${AppBrand.name} to finish installing version ${offer.version.label}.',
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
              Text('The new version will open in a moment.'),
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

Future<void> _showUpdateError(BuildContext context, Object error) {
  final message = error is StateError ? error.message : '$error';
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Update failed'),
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
