import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/export_file_saver.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/platform_http.dart';
import 'package:promoter_admin/src/services/schedule_export/event_type_labeling.dart';
import 'package:promoter_admin/src/services/schedule_export/html_exporter.dart';
import 'package:promoter_admin/src/services/schedule_export/pdf_exporter.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_layout.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_validation.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

enum ScheduleExportFormat { pdf, html }

enum ScheduleExportColorMode { color, blackAndWhite }

extension on ScheduleExportFormat {
  String get label => this == ScheduleExportFormat.pdf ? 'PDF' : 'HTML';
  String get extension => this == ScheduleExportFormat.pdf ? 'pdf' : 'html';
  String get mimeType =>
      this == ScheduleExportFormat.pdf ? 'application/pdf' : 'text/html';
}

Future<void> showScheduleExportDialog(
  BuildContext context, {
  required FestivalWorkspace workspace,
  required List<ScheduleEvent> events,
  ScheduleExportFormat initialFormat = ScheduleExportFormat.pdf,
}) async {
  final result = await showDialog<_ScheduleExportResult>(
    context: context,
    builder: (_) => ExportScheduleDialog(
      workspace: workspace,
      events: events,
      initialFormat: initialFormat,
    ),
  );
  if (result == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Exported ${result.eventCount} event(s) across '
        '${result.dayCount} day(s) to ${result.path}',
      ),
    ),
  );
}

class ExportScheduleDialog extends StatefulWidget {
  const ExportScheduleDialog({
    super.key,
    required this.workspace,
    required this.events,
    this.initialFormat = ScheduleExportFormat.pdf,
  });

  final FestivalWorkspace workspace;
  final List<ScheduleEvent> events;
  final ScheduleExportFormat initialFormat;

  @override
  State<ExportScheduleDialog> createState() => _ExportScheduleDialogState();
}

class _ExportScheduleDialogState extends State<ExportScheduleDialog> {
  late ScheduleExportFormat _format;
  late ScheduleExportColorMode _colorMode;
  late final List<String> _types;
  late final Set<String> _selectedTypes;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _format = widget.initialFormat;
    _colorMode = _defaultColorMode(_format);
    final seen = <String>{};
    _types = [
      ...ScheduleValidation.withDefaultEventTypes(widget.workspace.eventTypes),
      ...widget.events.map((event) => event.type.trim()),
    ].where((type) => type.isNotEmpty && seen.add(type.toLowerCase())).toList();
    final preferred = _types
        .where((type) {
          final key = type.trim().toLowerCase();
          return key == 'show' || key == 'special event';
        })
        .toSet();
    _selectedTypes = preferred.isEmpty ? _types.toSet() : preferred;
  }

  List<ScheduleEvent> get _filtered =>
      RunningOrderLayout.filterByTypes(widget.events, _selectedTypes);

  RunningOrderLayout get _layout =>
      RunningOrderLayout.build(_filtered, widget.workspace);

  Future<void> _save() async {
    final layout = _layout;
    if (layout.pages.isEmpty) {
      setState(() => _error = 'Select at least one event type with events.');
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final extension = _format.extension;
      final typeSlug = EventTypeLabeling.fileSlugForSelection(_selectedTypes);
      final suggestedName =
          '${_safeName(widget.workspace.displayName)}'
          '${widget.workspace.eventYear.trim().isEmpty ? '' : '-${widget.workspace.eventYear.trim()}'}'
          '${typeSlug == null ? '' : '-$typeSlug'}'
          '-running-order.$extension';

      final logo = await _readLogo();
      final logoUrl = widget.workspace.festivalLogoUrl.trim();
      final labeling = EventTypeLabeling.forSelection(_selectedTypes);
      final bytes = _format == ScheduleExportFormat.pdf
          ? await PdfExporter.build(
              layout: layout,
              festivalName: widget.workspace.displayName,
              logoBytes: logo,
              useColor: _colorMode == ScheduleExportColorMode.color,
              labeling: labeling,
            )
          : HtmlExporter.build(
              layout: layout,
              festivalName: widget.workspace.displayName,
              logoBytes: logo,
              logoMimeType: _logoMimeType(logoUrl),
              useColor: _colorMode == ScheduleExportColorMode.color,
              labeling: labeling,
            );

      final saved = await saveExportBytes(
        bytes: bytes,
        suggestedName: suggestedName,
        extension: extension,
        mimeType: _format.mimeType,
        typeLabel: '${_format.label} document',
        sharePositionOrigin: shareOrigin,
      );
      if (!mounted) return;
      if (saved == null) {
        setState(() => _saving = false);
        return;
      }
      Navigator.of(context).pop(
        _ScheduleExportResult(
          path: saved.snackbarLocation,
          eventCount: layout.eventCount,
          dayCount: layout.pages.length,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _cleanError(error);
      });
    }
  }

  Future<Uint8List?> _readLogo() async {
    final url = normalizeDropboxUrl(widget.workspace.festivalLogoUrl.trim());
    if (url.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(url), headers: {'User-Agent': kSafariUserAgent})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (response.bodyBytes.isEmpty) return null;
      return response.bodyBytes;
    } catch (_) {
      // Optional branding — a failed fetch must not block export.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final days = filtered.map((event) => event.day.trim()).toSet().length;
    return AlertDialog(
      title: const Text('Export running order'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a landscape schedule with venue columns and a time axis.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D2E14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE6A23C)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFFFD280),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For official festival admins / event promoters. '
                        'You may use this as the official running order. '
                        'Do not use it to compete with an official PDF or '
                        'web schedule.',
                        style: TextStyle(
                          color: Color(0xFFFFD280),
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'FORMAT',
                style: TextStyle(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ScheduleExportFormat>(
                segments: const [
                  ButtonSegment(
                    value: ScheduleExportFormat.pdf,
                    label: Text('PDF'),
                    icon: Icon(Icons.picture_as_pdf_outlined),
                  ),
                  ButtonSegment(
                    value: ScheduleExportFormat.html,
                    label: Text('HTML'),
                    icon: Icon(Icons.code),
                  ),
                ],
                selected: {_format},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() {
                        _format = selection.first;
                        _colorMode = _defaultColorMode(_format);
                      }),
              ),
              const SizedBox(height: 20),
              const Text(
                'OUTPUT STYLE',
                style: TextStyle(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ScheduleExportColorMode>(
                segments: const [
                  ButtonSegment(
                    value: ScheduleExportColorMode.color,
                    label: Text('Color'),
                    icon: Icon(Icons.palette_outlined),
                  ),
                  ButtonSegment(
                    value: ScheduleExportColorMode.blackAndWhite,
                    label: Text('Black & white'),
                    icon: Icon(Icons.contrast),
                  ),
                ],
                selected: {_colorMode},
                onSelectionChanged: _saving
                    ? null
                    : (selection) =>
                          setState(() => _colorMode = selection.first),
              ),
              const SizedBox(height: 20),
              const Text(
                'INCLUDE EVENT TYPES',
                style: TextStyle(
                  color: AppColors.heading,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              for (final type in _types)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _selectedTypes.contains(type),
                  title: Text(type),
                  onChanged: _saving
                      ? null
                      : (checked) => setState(() {
                          if (checked ?? false) {
                            _selectedTypes.add(type);
                          } else {
                            _selectedTypes.remove(type);
                          }
                        }),
                ),
              const SizedBox(height: 8),
              Text(
                '${filtered.length} event(s) across $days day(s)',
                style: const TextStyle(color: AppColors.muted),
              ),
              if (widget.workspace.festivalLogoUrl.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Logo: ${widget.workspace.festivalLogoUrl}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.errorText),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving || filtered.isEmpty ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_alt),
          label: Text(_saving ? 'Saving…' : 'Save ${_format.label}…'),
        ),
      ],
    );
  }

  static String _safeName(String value) {
    final cleaned = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'festival' : cleaned;
  }

  static ScheduleExportColorMode _defaultColorMode(
    ScheduleExportFormat format,
  ) {
    return format == ScheduleExportFormat.pdf
        ? ScheduleExportColorMode.blackAndWhite
        : ScheduleExportColorMode.color;
  }

  static String _logoMimeType(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.gif')) return 'image/gif';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }

  static String _cleanError(Object error) {
    final value = error.toString();
    return value
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }
}

class _ScheduleExportResult {
  const _ScheduleExportResult({
    required this.path,
    required this.eventCount,
    required this.dayCount,
  });

  final String path;
  final int eventCount;
  final int dayCount;
}
