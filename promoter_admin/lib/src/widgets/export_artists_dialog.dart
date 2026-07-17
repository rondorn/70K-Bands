import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/artists_export/artist_export_entry.dart';
import 'package:promoter_admin/src/services/artists_export/html_exporter.dart';
import 'package:promoter_admin/src/services/artists_export/logo_fetcher.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

enum ArtistsExportColorMode { color, blackAndWhite }

Future<void> showArtistsExportDialog(
  BuildContext context, {
  required FestivalWorkspace workspace,
  required List<BandRow> bands,
}) async {
  final result = await showDialog<_ArtistsExportResult>(
    context: context,
    builder: (_) => ExportArtistsDialog(
      workspace: workspace,
      bands: bands,
    ),
  );
  if (result == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Saved ${result.artistCount} artist(s) to ${result.path}',
      ),
    ),
  );
}

class ExportArtistsDialog extends StatefulWidget {
  const ExportArtistsDialog({
    super.key,
    required this.workspace,
    required this.bands,
  });

  final FestivalWorkspace workspace;
  final List<BandRow> bands;

  @override
  State<ExportArtistsDialog> createState() => _ExportArtistsDialogState();
}

class _ExportArtistsDialogState extends State<ExportArtistsDialog> {
  ArtistsExportColorMode _colorMode = ArtistsExportColorMode.color;
  bool _saving = false;
  String? _status;
  String? _error;

  Future<void> _save() async {
    final entries = ArtistExportEntry.fromBands(widget.bands);
    if (entries.isEmpty) {
      setState(() => _error = 'There are no artists to export.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _status = 'Choose where to save…';
    });
    try {
      const extension = 'html';
      final location = await getSaveLocation(
        suggestedName:
            '${_safeName(widget.workspace.displayName)}'
            '${widget.workspace.eventYear.trim().isEmpty ? '' : '-${widget.workspace.eventYear.trim()}'}'
            '-lineup.$extension',
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'HTML document',
            extensions: [extension],
          ),
        ],
      );
      if (location == null) {
        if (mounted) {
          setState(() {
            _saving = false;
            _status = null;
          });
        }
        return;
      }
      final targetPath =
          p.extension(location.path).toLowerCase() == '.$extension'
          ? location.path
          : '${location.path}.$extension';

      if (mounted) setState(() => _status = 'Downloading logos…');
      final festivalLogoUrl = widget.workspace.festivalLogoUrl.trim();
      final festivalLogo = await LogoFetcher.fetchBytes(festivalLogoUrl);
      final withLogos = await LogoFetcher.attachBandLogos(entries);

      if (mounted) setState(() => _status = 'Building HTML…');
      final bytes = ArtistsHtmlExporter.build(
        artists: withLogos,
        festivalName: widget.workspace.displayName,
        year: widget.workspace.eventYear,
        festivalLogoBytes: festivalLogo,
        festivalLogoMimeType: logoMimeType(festivalLogoUrl),
        useColor: _colorMode == ArtistsExportColorMode.color,
      );

      await XFile.fromData(
        bytes,
        name: p.basename(targetPath),
        mimeType: 'text/html',
      ).saveTo(targetPath);
      if (!mounted) return;
      Navigator.of(context).pop(
        _ArtistsExportResult(path: targetPath, artistCount: withLogos.length),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _status = null;
        _error = _cleanError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = ArtistExportEntry.fromBands(widget.bands).length;
    return AlertDialog(
      title: const Text('Export lineup'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export $count artist(s) as an HTML logo grid (4 across). '
              'Hover a logo for the band name; click to open the official site.',
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
            const SizedBox(height: 18),
            const Text(
              'COLOR',
              style: TextStyle(
                color: AppColors.heading,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ArtistsExportColorMode>(
              segments: const [
                ButtonSegment(
                  value: ArtistsExportColorMode.color,
                  label: Text('Color'),
                ),
                ButtonSegment(
                  value: ArtistsExportColorMode.blackAndWhite,
                  label: Text('Black & white'),
                ),
              ],
              selected: {_colorMode},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() => _colorMode = value.first),
            ),
            if (widget.workspace.festivalLogoUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Festival logo from Settings will appear at the top.',
                style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9)),
              ),
            ],
            if (_status != null) ...[
              const SizedBox(height: 14),
              Text(_status!, style: const TextStyle(color: AppColors.muted)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.errorText)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }

  static String _safeName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^\w\s\-]+'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    return cleaned.isEmpty ? 'festival' : cleaned.toLowerCase();
  }

  static String _cleanError(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }
}

class _ArtistsExportResult {
  const _ArtistsExportResult({required this.path, required this.artistCount});

  final String path;
  final int artistCount;
}
