import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_browser_preview.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_export_config.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app preview of the HTML running-order export for review and comparison.
///
/// macOS uses an embedded WebView. Windows opens the same HTML in the default
/// browser (no [webview_flutter] implementation on Windows).
class ScheduleRunningOrderPreview extends StatefulWidget {
  const ScheduleRunningOrderPreview({
    super.key,
    required this.workspace,
    required this.events,
  });

  final FestivalWorkspace workspace;
  final List<ScheduleEvent> events;

  @override
  State<ScheduleRunningOrderPreview> createState() =>
      _ScheduleRunningOrderPreviewState();
}

class _ScheduleRunningOrderPreviewState extends State<ScheduleRunningOrderPreview> {
  late RunningOrderExportConfig _config;
  WebViewController? _controller;
  String? _browserPreviewPath;
  bool _loading = true;
  String? _error;
  Timer? _browserOpenTimer;
  File? _pendingBrowserFile;

  bool get _useBrowserPreview => RunningOrderBrowserPreview.useExternalBrowser;

  @override
  void initState() {
    super.initState();
    _config = RunningOrderExportConfig(
      workspace: widget.workspace,
      events: widget.events,
    );
    _reloadPreview();
  }

  @override
  void dispose() {
    _browserOpenTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScheduleRunningOrderPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace ||
        oldWidget.events != widget.events) {
      _config = RunningOrderExportConfig(
        workspace: widget.workspace,
        events: widget.events,
        selectedTypes: _config.selectedTypes,
        colorMode: _config.colorMode,
      );
      _reloadPreview();
    }
  }

  Future<void> _reloadPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_config.filteredEvents.isEmpty) {
        setState(() {
          _loading = false;
          _controller = null;
          _browserPreviewPath = null;
        });
        return;
      }
      final bytes = await _config.buildHtmlBytes();
      if (!mounted) return;

      if (_useBrowserPreview) {
        final file = await RunningOrderBrowserPreview.writePreviewFile(bytes);
        if (!mounted) return;
        setState(() {
          _browserPreviewPath = file.path;
          _controller = null;
          _loading = false;
        });
        _scheduleBrowserOpen(file);
        return;
      }

      final html = utf8.decode(bytes);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled);
      await controller.loadHtmlString(html);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _browserPreviewPath = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _controller = null;
        _browserPreviewPath = null;
        _error = _cleanError(error);
      });
    }
  }

  void _scheduleBrowserOpen(File file) {
    _pendingBrowserFile = file;
    _browserOpenTimer?.cancel();
    _browserOpenTimer = Timer(const Duration(milliseconds: 400), () async {
      final target = _pendingBrowserFile;
      if (target == null || !mounted) return;
      try {
        await RunningOrderBrowserPreview.openInDefaultBrowser(target);
      } catch (error) {
        if (!mounted) return;
        setState(() => _error = _cleanError(error));
      }
    });
  }

  Future<void> _openBrowserPreviewNow() async {
    final path = _browserPreviewPath;
    if (path == null) return;
    try {
      await RunningOrderBrowserPreview.openInDefaultBrowser(File(path));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _cleanError(error));
    }
  }

  void _onOptionsChanged() {
    _reloadPreview();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _config.filteredEvents;
    final days = _config.dayCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF3D2E14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE6A23C)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _useBrowserPreview
                    ? Icons.open_in_browser
                    : Icons.visibility_outlined,
                color: const Color(0xFFFFD280),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _useBrowserPreview
                      ? 'Same layout as HTML export — opens in your default browser '
                          'on Windows. Change filters here; the preview file updates '
                          'automatically (refresh the browser tab or use Open again).'
                      : 'Same layout as HTML export — scroll to review days, venues, '
                          'and times. Compare with your source schedule before publishing.',
                  style: const TextStyle(
                    color: Color(0xFFFFD280),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<ScheduleExportColorMode>(
              segments: const [
                ButtonSegment(
                  value: ScheduleExportColorMode.color,
                  label: Text('Color'),
                  icon: Icon(Icons.palette_outlined, size: 18),
                ),
                ButtonSegment(
                  value: ScheduleExportColorMode.blackAndWhite,
                  label: Text('B&W'),
                  icon: Icon(Icons.contrast, size: 18),
                ),
              ],
              selected: {_config.colorMode},
              onSelectionChanged: _loading
                  ? null
                  : (selection) {
                      setState(() => _config.colorMode = selection.first);
                      _onOptionsChanged();
                    },
            ),
            Text(
              '${filtered.length} event(s) across $days day(s)',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            for (final type in _config.availableTypes)
              FilterChip(
                label: Text(type),
                selected: _config.selectedTypes.contains(type),
                onSelected: _loading
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _config.selectedTypes.add(type);
                          } else {
                            _config.selectedTypes.remove(type);
                          }
                        });
                        _onOptionsChanged();
                      },
              ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.errorText),
            ),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: PortalPanel(
            padding: EdgeInsets.zero,
            child: _buildPreviewBody(filtered),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewBody(List<ScheduleEvent> filtered) {
    if (widget.events.isEmpty) {
      return const Center(
        child: Text(
          'No schedule events yet.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'Select at least one event type with events.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_useBrowserPreview) {
      return _buildBrowserPreviewPanel();
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: Text(
          'Preview unavailable.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: Colors.white,
        child: WebViewWidget(controller: controller),
      ),
    );
  }

  Widget _buildBrowserPreviewPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.open_in_browser,
                size: 48,
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
              Text(
                'Schedule preview is open in your browser.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'This is the same HTML as Schedule export. Adjust event types or '
                'color above — the preview file updates automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _browserPreviewPath == null ? null : _openBrowserPreviewNow,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open in browser again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _cleanError(Object error) {
    final value = error.toString();
    return value
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }
}
