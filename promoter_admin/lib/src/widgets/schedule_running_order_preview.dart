import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/embedded_html_webview.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_export_config.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/centered_when_wrapped.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/embedded_html_webview_frame.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app preview of the HTML running-order export for review and comparison.
///
/// macOS uses WKWebView; Windows uses WebView2 via [webview_win_floating].
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
  bool _loading = true;
  String? _error;

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
        });
        return;
      }
      final bytes = await _config.buildHtmlBytes();
      if (!mounted) return;

      final html = utf8.decode(bytes);
      final controller = await createEmbeddedHtmlWebViewController(
        html,
        javaScriptMode: JavaScriptMode.disabled,
      );
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _controller = null;
        _error = _cleanError(error);
      });
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
              const Icon(
                Icons.visibility_outlined,
                color: Color(0xFFFFD280),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Same layout as HTML export — scroll to review days, venues, '
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
        CenteredWhenWrapped(
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
    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: Text(
          'Preview unavailable.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return EmbeddedHtmlWebViewFrame(controller: controller);
  }

  static String _cleanError(Object error) {
    final value = error.toString();
    return value
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }
}
