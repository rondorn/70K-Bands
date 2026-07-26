import 'package:flutter/material.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/embedded_html_webview.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/embedded_html_webview_frame.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Fetches a Dropbox stats report and renders it as HTML (not raw source text).
///
/// Dropbox shared links serve unprocessed HTML; this widget downloads the file
/// and loads it into an embedded WebView (WebView2 on Windows, WKWebView on macOS).
///
/// Each mount re-fetches from Dropbox with [fetchUrlText] `forceRefresh: true`
/// (local cache bypass + CDN cache-bust). Use a new [key] to reload while the
/// same report URL is still shown.
class ReportHtmlPreview extends StatefulWidget {
  const ReportHtmlPreview({
    super.key,
    required this.reportUrl,
    this.emptyMessage = 'No report URL configured. Load festival data after '
        'setting the Production link.',
  });

  final String reportUrl;
  final String emptyMessage;

  @override
  State<ReportHtmlPreview> createState() => _ReportHtmlPreviewState();
}

class _ReportHtmlPreviewState extends State<ReportHtmlPreview> {
  WebViewController? _controller;
  bool _loading = false;
  String? _error;
  String _loadedUrl = '';

  @override
  void initState() {
    super.initState();
    _loadIfNeeded(force: true);
  }

  @override
  void didUpdateWidget(covariant ReportHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportUrl.trim() != widget.reportUrl.trim()) {
      _loadIfNeeded(force: true);
    }
  }

  Future<void> _loadIfNeeded({required bool force}) async {
    final url = normalizeDropboxUrl(widget.reportUrl.trim());
    if (url.isEmpty) {
      setState(() {
        _loading = false;
        _error = null;
        _controller = null;
        _loadedUrl = '';
      });
      return;
    }
    if (!force && url == _loadedUrl && _controller != null) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final html = await fetchUrlText(url, forceRefresh: force);
      if (!mounted) return;
      if (html.trim().isEmpty) {
        throw StateError('Downloaded report HTML was empty.');
      }

      final controller = await createEmbeddedHtmlWebViewController(html);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loading = false;
        _loadedUrl = url;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _controller = null;
        _error = error.toString();
        _loadedUrl = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.reportUrl.trim();
    if (url.isEmpty) {
      return PortalPanel(
        child: Text(
          widget.emptyMessage,
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (_error != null) {
      return PortalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.errorText),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _loadIfNeeded(force: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return EmbeddedHtmlWebViewFrame(controller: controller);
  }
}
