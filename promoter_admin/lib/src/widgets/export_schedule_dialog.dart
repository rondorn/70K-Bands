import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/export_file_saver.dart';
import 'package:promoter_admin/src/services/schedule_export/event_type_labeling.dart';
import 'package:promoter_admin/src/services/schedule_export/pdf_exporter.dart';
import 'package:promoter_admin/src/services/schedule_export/running_order_export_config.dart';
import 'package:promoter_admin/src/services/schedule_qr/schedule_qr_export.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

export 'package:promoter_admin/src/services/schedule_export/running_order_export_config.dart'
    show ScheduleExportColorMode;

enum ScheduleExportFormat { pdf, html, qrPoster }

extension on ScheduleExportFormat {
  String get label => switch (this) {
        ScheduleExportFormat.pdf => 'PDF',
        ScheduleExportFormat.html => 'HTML',
        ScheduleExportFormat.qrPoster => 'QR poster',
      };

  String get extension => switch (this) {
        ScheduleExportFormat.pdf => 'pdf',
        ScheduleExportFormat.html => 'html',
        ScheduleExportFormat.qrPoster => 'pdf',
      };

  String get mimeType => switch (this) {
        ScheduleExportFormat.pdf => 'application/pdf',
        ScheduleExportFormat.html => 'text/html',
        ScheduleExportFormat.qrPoster => 'application/pdf',
      };

  bool get isRunningOrder => this != ScheduleExportFormat.qrPoster;
}

Future<void> showScheduleExportDialog(
  BuildContext context, {
  required FestivalWorkspace workspace,
  required List<ScheduleEvent> events,
  required bool qrCodeSupported,
  required List<String> bandNamesForQr,
  String scheduleQrGuideUrl = '',
  ScheduleExportFormat initialFormat = ScheduleExportFormat.pdf,
}) async {
  final result = await showDialog<_ScheduleExportResult>(
    context: context,
    builder: (_) => ExportScheduleDialog(
      workspace: workspace,
      events: events,
      qrCodeSupported: qrCodeSupported,
      bandNamesForQr: bandNamesForQr,
      scheduleQrGuideUrl: scheduleQrGuideUrl,
      initialFormat: initialFormat,
    ),
  );
  if (result == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.message)),
  );
}

class ExportScheduleDialog extends StatefulWidget {
  const ExportScheduleDialog({
    super.key,
    required this.workspace,
    required this.events,
    required this.qrCodeSupported,
    required this.bandNamesForQr,
    this.scheduleQrGuideUrl = '',
    this.initialFormat = ScheduleExportFormat.pdf,
  });

  final FestivalWorkspace workspace;
  final List<ScheduleEvent> events;
  final bool qrCodeSupported;
  final List<String> bandNamesForQr;
  final String scheduleQrGuideUrl;
  final ScheduleExportFormat initialFormat;

  @override
  State<ExportScheduleDialog> createState() => _ExportScheduleDialogState();
}

class _ExportScheduleDialogState extends State<ExportScheduleDialog> {
  late ScheduleExportFormat _format;
  late RunningOrderExportConfig _config;
  late final TextEditingController _scheduleChangeTitle;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _format = widget.initialFormat;
    _config = RunningOrderExportConfig(
      workspace: widget.workspace,
      events: widget.events,
      colorMode: _defaultColorMode(_format),
    );
    _scheduleChangeTitle = TextEditingController(text: 'Schedule Update');
  }

  @override
  void dispose() {
    _scheduleChangeTitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final box = context.findRenderObject() as RenderBox?;
    final shareOrigin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      late Uint8List bytes;
      late String suggestedName;
      late int eventCount;
      late int dayCount;
      late String typeLabel;

      if (_format == ScheduleExportFormat.qrPoster) {
        bytes = await ScheduleQrExport.buildPosterPdf(
          events: widget.events,
          bandNames: widget.bandNamesForQr,
          festivalName: widget.workspace.displayName,
          scheduleChangeTitle: _scheduleChangeTitle.text,
          guideUrl: widget.scheduleQrGuideUrl,
        );
        suggestedName =
            '${_safeName(widget.workspace.displayName)}'
            '${widget.workspace.eventYear.trim().isEmpty ? '' : '-${widget.workspace.eventYear.trim()}'}'
            '-schedule-qr-poster.pdf';
        eventCount = widget.events.length;
        dayCount = 1;
        typeLabel = 'QR poster';
      } else {
        final layout = _config.layout;
        if (layout.pages.isEmpty) {
          setState(() {
            _saving = false;
            _error = 'Select at least one event type with events.';
          });
          return;
        }
        final typeSlug = EventTypeLabeling.fileSlugForSelection(
          _config.selectedTypes,
        );
        suggestedName =
            '${_safeName(widget.workspace.displayName)}'
            '${widget.workspace.eventYear.trim().isEmpty ? '' : '-${widget.workspace.eventYear.trim()}'}'
            '${typeSlug == null ? '' : '-$typeSlug'}'
            '-running-order.${_format.extension}';

        final logo = await RunningOrderExportConfig.fetchFestivalLogoBytes(
          widget.workspace.festivalLogoUrl,
        );
        final labeling = EventTypeLabeling.forSelection(_config.selectedTypes);
        bytes = _format == ScheduleExportFormat.pdf
            ? await PdfExporter.build(
                layout: layout,
                festivalName: widget.workspace.displayName,
                logoBytes: logo,
                useColor: _config.colorMode == ScheduleExportColorMode.color,
                labeling: labeling,
              )
            : await _config.buildHtmlBytes();
        eventCount = layout.eventCount;
        dayCount = layout.pages.length;
        typeLabel = '${_format.label} document';
      }

      final saved = await saveExportBytes(
        bytes: bytes,
        suggestedName: suggestedName,
        extension: _format.extension,
        mimeType: _format.mimeType,
        typeLabel: typeLabel,
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
          eventCount: eventCount,
          dayCount: dayCount,
          format: _format,
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

  @override
  Widget build(BuildContext context) {
    final filtered = _config.filteredEvents;
    final days = _config.dayCount;
    final isQrPoster = _format == ScheduleExportFormat.qrPoster;
    final canSave = isQrPoster
        ? widget.events.isNotEmpty && widget.bandNamesForQr.isNotEmpty
        : filtered.isNotEmpty;

    return AlertDialog(
      title: Text(isQrPoster ? 'Export schedule QR poster' : 'Export running order'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isQrPoster
                    ? 'Create a letter-size poster with scannable schedule QR code(s) '
                        'for hallway printing on the ship or at the event.'
                    : 'Create a landscape schedule with venue columns and a time axis.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (!isQrPoster)
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
              if (isQrPoster)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2E1A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF4CAF50)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.qr_code_2_outlined,
                        color: Color(0xFF9BE59B),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Uses the same compressed binary QR payload as the 70K Bands app '
                          'and the poster generator script. Unofficial Event and Cruiser '
                          'Organized rows are omitted. Print at 100% scale for reliable scanning.',
                          style: TextStyle(
                            color: Color(0xFF9BE59B),
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
                segments: [
                  const ButtonSegment(
                    value: ScheduleExportFormat.pdf,
                    label: Text('PDF'),
                    icon: Icon(Icons.picture_as_pdf_outlined),
                  ),
                  const ButtonSegment(
                    value: ScheduleExportFormat.html,
                    label: Text('HTML'),
                    icon: Icon(Icons.code),
                  ),
                  if (widget.qrCodeSupported)
                    const ButtonSegment(
                      value: ScheduleExportFormat.qrPoster,
                      label: Text('QR poster'),
                      icon: Icon(Icons.qr_code_2),
                    ),
                ],
                selected: {_format},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() {
                        _format = selection.first;
                        if (_format.isRunningOrder) {
                          _config.colorMode = _defaultColorMode(_format);
                        }
                      }),
              ),
              if (isQrPoster) ...[
                const SizedBox(height: 20),
                const Text(
                  'SCHEDULE UPDATE TITLE',
                  style: TextStyle(
                    color: AppColors.heading,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _scheduleChangeTitle,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Meet and Greet, Clinic, Storm Schedule',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${widget.events.length} event(s) in testing schedule — '
                  '${widget.bandNamesForQr.length} artist(s) in lineup order',
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (widget.scheduleQrGuideUrl.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Includes Camera-app guide QR.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
              ] else ...[
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
                  selected: {_config.colorMode},
                  onSelectionChanged: _saving
                      ? null
                      : (selection) =>
                            setState(() => _config.colorMode = selection.first),
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
                for (final type in _config.availableTypes)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _config.selectedTypes.contains(type),
                    title: Text(type),
                    onChanged: _saving
                        ? null
                        : (checked) => setState(() {
                            if (checked ?? false) {
                              _config.selectedTypes.add(type);
                            } else {
                              _config.selectedTypes.remove(type);
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
              ],
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
          onPressed: _saving || !canSave ? null : _save,
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
    required this.format,
  });

  final String path;
  final int eventCount;
  final int dayCount;
  final ScheduleExportFormat format;

  String get message => format == ScheduleExportFormat.qrPoster
      ? 'Exported schedule QR poster ($eventCount event(s)) to $path'
      : 'Exported $eventCount event(s) across $dayCount day(s) to $path';
}
