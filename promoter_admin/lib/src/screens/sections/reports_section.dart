import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/report_html_preview.dart';

enum ReportVariant { endUser, full }

/// Stats report viewer for promoters with access to the reports folder.
class ReportsSection extends StatefulWidget {
  const ReportsSection({
    super.key,
    required this.workspace,
    this.dropboxConnected = false,
    this.onDiscoverReports,
  });

  final FestivalWorkspace workspace;
  final bool dropboxConnected;

  /// Rescan the reports folder when [forceRefresh] is true.
  final Future<FestivalWorkspace> Function({bool forceRefresh})?
      onDiscoverReports;

  @override
  State<ReportsSection> createState() => _ReportsSectionState();
}

class _ReportsSectionState extends State<ReportsSection> {
  ReportVariant _variant = ReportVariant.endUser;
  bool _discovering = false;
  int _previewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _discoverReports(forceRefresh: false);
  }

  @override
  void didUpdateWidget(covariant ReportsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.id != widget.workspace.id ||
        oldWidget.workspace.reportsFolderUrl !=
            widget.workspace.reportsFolderUrl ||
        oldWidget.workspace.eventYear != widget.workspace.eventYear) {
      if (_variant == ReportVariant.full &&
          widget.workspace.effectiveReportUrlFull.trim().isEmpty) {
        _variant = ReportVariant.endUser;
      }
      if (oldWidget.workspace.id != widget.workspace.id ||
          oldWidget.workspace.reportsFolderUrl !=
              widget.workspace.reportsFolderUrl ||
          oldWidget.workspace.eventYear != widget.workspace.eventYear) {
        _discoverReports(forceRefresh: false);
      }
    }
  }

  Future<void> _discoverReports({required bool forceRefresh}) async {
    final discover = widget.onDiscoverReports;
    if (discover == null ||
        !widget.dropboxConnected ||
        widget.workspace.reportsFolderUrl.trim().isEmpty) {
      return;
    }
    setState(() => _discovering = true);
    try {
      await discover(forceRefresh: forceRefresh);
      if (forceRefresh && mounted) {
        setState(() => _previewGeneration++);
      }
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  String get _activeUrl {
    return _variant == ReportVariant.full
        ? widget.workspace.effectiveReportUrlFull
        : widget.workspace.effectiveReportUrl;
  }

  bool get _canShowFull =>
      widget.workspace.effectiveReportUrlFull.trim().isNotEmpty;

  String get _emptyMessage {
    if (_variant == ReportVariant.full) {
      return 'No full report HTML found in the reports folder.';
    }
    return 'No English end-user report found. Load festival data or check '
        'the reports folder.';
  }

  void _showFullReport() {
    if (!_canShowFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No full report HTML found in the reports folder.'),
        ),
      );
      return;
    }
    setState(() => _variant = ReportVariant.full);
  }

  void _showEndUserReport() {
    setState(() => _variant = ReportVariant.endUser);
  }

  Future<void> _refreshReport() async {
    await _discoverReports(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final showingFull = _variant == ReportVariant.full;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PortalPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          showingFull
                              ? 'Full report (admin)'
                              : 'End-user report (English)',
                          style: const TextStyle(
                            color: AppColors.heading,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showingFull
                              ? 'Admin-only dashboard — view here only, not shareable.'
                              : 'Same English dashboard published to festival-goers.',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showingFull)
                    TextButton(
                      onPressed: _discovering ? null : _showEndUserReport,
                      child: const Text('End-user report'),
                    )
                  else if (_canShowFull)
                    TextButton(
                      onPressed: _discovering ? null : _showFullReport,
                      child: const Text('Full report'),
                    ),
                  IconButton(
                    tooltip: 'Rescan reports folder and reload',
                    onPressed: _discovering ? null : _refreshReport,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (_discovering) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ReportHtmlPreview(
            key: ValueKey(
              'report-${_variant.name}-${_activeUrl.trim()}-$_previewGeneration',
            ),
            reportUrl: _activeUrl,
            emptyMessage: _emptyMessage,
          ),
        ),
      ],
    );
  }
}
