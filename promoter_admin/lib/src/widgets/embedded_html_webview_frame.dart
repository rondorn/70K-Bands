import 'package:flutter/material.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Bordered in-app HTML preview surface shared by schedule and report views.
class EmbeddedHtmlWebViewFrame extends StatelessWidget {
  const EmbeddedHtmlWebViewFrame({
    super.key,
    required this.controller,
    this.backgroundColor = Colors.white,
  });

  final WebViewController controller;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: AppColors.navBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
