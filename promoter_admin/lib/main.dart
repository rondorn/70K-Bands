import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart';
import 'package:promoter_admin/src/app.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  // Required by desktop_webview_window (Dropbox OAuth + Metal Archives fetch).
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
  runApp(const PromoterAdminApp());
}
