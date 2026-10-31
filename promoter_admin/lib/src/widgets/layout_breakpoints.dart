import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shortest-side below which the admin UI switches to a compact (phone) layout.
/// Uses shortest side so iPhone landscape stays compact (width alone would not).
const kCompactLayoutShortestSide = 700.0;

/// Shortest-side for classic phones / closed Duo cover (portrait lock).
const kPhoneShortestSide = 600.0;

/// iOS phone chrome including open Duo. Stays below iPad mini (~744pt).
const kIosPhoneShortestSide = kCompactLayoutShortestSide;

/// True on phone-sized screens where the Mac/iPad table layout would overflow.
bool isCompactLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).shortestSide <
      kCompactLayoutShortestSide;
}

bool get _isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

/// Pure size/platform rule for phone chrome (testable without a widget tree).
/// Desktop stays on the desktop/iPad shell. iOS uses a higher threshold so open
/// Duo gets the one-line header + accordion nav; iPad mini and larger do not.
bool isPhoneLayoutForShortestSide(
  double shortestSide, {
  required bool isDesktopPlatform,
  required bool isIos,
}) {
  if (isDesktopPlatform) return false;
  final threshold = isIos ? kIosPhoneShortestSide : kPhoneShortestSide;
  return shortestSide < threshold;
}

/// True for iPhone (including Duo) and other phones — phone shell chrome.
/// False on Mac/Windows/Linux and on iPad.
bool isPhoneDevice(BuildContext context) {
  return isPhoneLayoutForShortestSide(
    MediaQuery.sizeOf(context).shortestSide,
    isDesktopPlatform: _isDesktopPlatform,
    isIos: !kIsWeb && Platform.isIOS,
  );
}

/// Portrait lock for classic phone / closed cover only. Open Duo may rotate.
bool shouldLockPhonePortrait(BuildContext context) {
  if (_isDesktopPlatform) return false;
  return MediaQuery.sizeOf(context).shortestSide < kPhoneShortestSide;
}

/// Locks portrait on phones; iPad and desktop keep all orientations.
class CompactPhoneOrientationScope extends StatefulWidget {
  const CompactPhoneOrientationScope({super.key, required this.child});

  final Widget child;

  @override
  State<CompactPhoneOrientationScope> createState() =>
      _CompactPhoneOrientationScopeState();
}

class _CompactPhoneOrientationScopeState
    extends State<CompactPhoneOrientationScope> {
  @override
  void dispose() {
    if (_supportsOrientationLock) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  bool get _supportsOrientationLock =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  void _applyOrientations(BuildContext context) {
    if (!_supportsOrientationLock) return;
    if (shouldLockPhonePortrait(context)) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  @override
  Widget build(BuildContext context) {
    _applyOrientations(context);
    return widget.child;
  }
}

/// Padding for list/table panels (Artists, Schedule, Descriptions, etc.).
EdgeInsets listPanelPadding(BuildContext context) {
  return isCompactLayout(context)
      ? const EdgeInsets.fromLTRB(10, 10, 10, 8)
      : const EdgeInsets.fromLTRB(12, 12, 12, 12);
}

/// Standard vertical gap before a table inside a list panel.
double listPanelSectionGap(BuildContext context) {
  return isCompactLayout(context) ? 8 : 12;
}

/// Width for dialog content areas — full width on phone, fixed on Mac/iPad.
double dialogContentWidth(BuildContext context, {double desktop = 480}) {
  return isCompactLayout(context)
      ? MediaQuery.sizeOf(context).width * 0.88
      : desktop;
}

/// Footer refresh control shared by list sections.
class SectionRefreshFooter extends StatelessWidget {
  const SectionRefreshFooter({
    super.key,
    required this.label,
    required this.onRefresh,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onRefresh;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: enabled ? onRefresh : null,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(label),
      ),
    );
  }
}
