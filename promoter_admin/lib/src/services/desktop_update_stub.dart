import 'package:flutter/widgets.dart';

/// Web and other non-IO targets do not self-update.
Future<void> promptForDesktopUpdate(
  GlobalKey<NavigatorState> navigatorKey,
) async {}
