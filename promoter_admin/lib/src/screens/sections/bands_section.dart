import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/band_discover_service.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/location_parse.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/admin_table_cells.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/dropbox_folder_picker.dart';
import 'package:promoter_admin/src/widgets/export_artists_dialog.dart';
import 'package:promoter_admin/src/widgets/url_image_preview.dart';
import 'package:url_launcher/url_launcher.dart';

class BandsSection extends StatefulWidget {
  const BandsSection({
    super.key,
    required this.workspace,
    required this.lineupService,
    required this.descriptionMapService,
    required this.dropboxApi,
    required this.tab,
    required this.onTabChanged,
    required this.onFormModeChanged,
    required this.dropboxConnected,
    required this.onConnectDropbox,
  });

  final FestivalWorkspace workspace;
  final LineupService lineupService;
  final DescriptionMapService descriptionMapService;
  final DropboxApi dropboxApi;
  final BandsTab tab;
  final ValueChanged<BandsTab> onTabChanged;
  final ValueChanged<bool> onFormModeChanged;
  final bool dropboxConnected;
  final Future<void> Function() onConnectDropbox;

  @override
  State<BandsSection> createState() => _BandsSectionState();
}

class _BandsSectionState extends State<BandsSection> {
  final _discover = BandDiscoverService();
  List<BandRow> _bands = [];
  String? _error;
  String? _message;
  String? _shareUrl;
  bool _loading = true;
  bool _saving = false;
  bool _discovering = false;
  String? _discoverStatus;
  String? _discoverWarnings;
  String? _discoverPickListUrl;
  String? _discoverPickListLabel;
  int? _editingIndex;
  bool _addDescription = false;

  final _name = TextEditingController();
  final _metalArchives = TextEditingController();
  final _musicBrainz = TextEditingController();
  final _latestAlbum = TextEditingController();
  final _site = TextEditingController();
  final _image = TextEditingController();
  final _youtube = TextEditingController();
  final _wikipedia = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _genre = TextEditingController();
  final _noteworthy = TextEditingController();
  final _priorYears = TextEditingController();
  final _description = TextEditingController();

  bool get _isEditing => _editingIndex != null;
  bool get _useCityState => widget.workspace.useCityStateField;
  bool get _canEdit => widget.workspace.canEditBands;

  /// File order stays as entered; alphabetical is display-only.
  List<int> get _bandsDisplayOrder {
    final indices = List<int>.generate(_bands.length, (i) => i);
    indices.sort((a, b) {
      final byName = _bands[a]
          .name
          .toLowerCase()
          .compareTo(_bands[b].name.toLowerCase());
      if (byName != 0) return byName;
      return a.compareTo(b);
    });
    return indices;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BandsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != BandsTab.add && widget.tab == BandsTab.add) {
      // Opening form from list Add (unless already editing).
      if (_editingIndex == null) {
        _clearForm();
        _addDescription = false;
      }
    }
    if (widget.tab == BandsTab.list && oldWidget.tab != BandsTab.list) {
      _editingIndex = null;
      _addDescription = false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _metalArchives.dispose();
    _musicBrainz.dispose();
    _latestAlbum.dispose();
    _site.dispose();
    _image.dispose();
    _youtube.dispose();
    _wikipedia.dispose();
    _country.dispose();
    _city.dispose();
    _state.dispose();
    _genre.dispose();
    _noteworthy.dispose();
    _priorYears.dispose();
    _description.dispose();
    super.dispose();
  }

  void _clearForm() {
    _name.clear();
    _metalArchives.clear();
    _musicBrainz.clear();
    _latestAlbum.clear();
    _site.clear();
    _image.clear();
    _youtube.clear();
    _wikipedia.clear();
    _country.clear();
    _city.clear();
    _state.clear();
    _genre.clear();
    _noteworthy.clear();
    _priorYears.clear();
    _description.clear();
    _discoverStatus = null;
    _discoverWarnings = null;
    _discoverPickListUrl = null;
    _discoverPickListLabel = null;
  }

  void _fillForm(BandRow band) {
    _name.text = band.name;
    _metalArchives.text = band.fields['metalArchives'] ?? '';
    _musicBrainz.clear();
    _latestAlbum.clear();
    _site.text = (band.fields['officalSite'] ?? '').trim();
    _image.text = (band.fields['imageUrl'] ?? '').trim();
    _youtube.text = (band.fields['youtube'] ?? '').trim();
    _wikipedia.text = (band.fields['wikipedia'] ?? '').trim();
    _country.text = band.country;
    _city.text = (band.fields['city'] ?? '').trim();
    _state.text = _normalizedState((band.fields['state'] ?? '').trim());
    _genre.text = band.genre;
    _noteworthy.text = (band.fields['noteworthy'] ?? '').trim();
    _priorYears.text = (band.fields['priorYears'] ?? '').trim();
    _discoverStatus = null;
    _discoverWarnings = null;
    _discoverPickListUrl = null;
    _discoverPickListLabel = null;
  }

  /// Full US state names → two-letter codes (e.g. California → CA).
  String _normalizedState(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return stateNameToCode(trimmed);
  }

  BandRow _rowFromForm(String name) {
    final fields = <String, String>{
      'bandName': name,
      'officalSite': _site.text.trim().isEmpty ? ' ' : _site.text.trim(),
      'imageUrl': _image.text.trim().isEmpty ? ' ' : _image.text.trim(),
      'youtube': _youtube.text.trim().isEmpty ? ' ' : _youtube.text.trim(),
      'metalArchives': _metalArchives.text.trim(),
      'wikipedia':
          _wikipedia.text.trim().isEmpty ? ' ' : _wikipedia.text.trim(),
      'country': _country.text.trim(),
      'genre': _genre.text.trim(),
      'noteworthy':
          _noteworthy.text.trim().isEmpty ? ' ' : _noteworthy.text.trim(),
      'priorYears': _priorYears.text.trim(),
    };
    if (_useCityState) {
      fields['city'] = _city.text.trim();
      fields['state'] = _normalizedState(_state.text);
    }
    return BandRow(fields);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bands = await widget.lineupService.load(
        widget.workspace,
        forceRefresh: forceRefresh,
      );
      setState(() {
        _bands = bands;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runDiscover() async {
    final ma = _metalArchives.text.trim();
    final mb = _musicBrainz.text.trim();
    final band = _name.text.trim();
    if (ma.isEmpty && mb.isEmpty && band.isEmpty) {
      setState(() {
        _discoverStatus =
            'Enter a Metal Archives URL, MusicBrainz URL, or band name.';
        _discoverWarnings = null;
        _discoverPickListUrl = null;
        _discoverPickListLabel = null;
      });
      return;
    }
    setState(() {
      _discovering = true;
      _discoverWarnings = null;
      _discoverPickListUrl = null;
      _discoverPickListLabel = null;
      if (ma.isNotEmpty) {
        _discoverStatus = Platform.isIOS
            ? 'Querying Metal Archives (may take ~15–30s)…'
            : 'Querying Metal Archives…';
      } else if (mb.isNotEmpty) {
        _discoverStatus = 'Querying MusicBrainz…';
      } else {
        _discoverStatus =
            'Searching Metal Archives by exact name (then MusicBrainz)…';
      }
    });
    try {
      final result = await _discover.discover(
        metalArchivesUrl: ma,
        musicBrainzUrl: mb,
        bandName: band,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() {
          _discovering = false;
          _discoverStatus = result.error;
          _discoverWarnings =
              result.warnings.isEmpty ? null : result.warnings.join(' ');
          _discoverPickListUrl =
              result.pickListUrl.isEmpty ? null : result.pickListUrl;
          _discoverPickListLabel =
              result.pickListLabel.isEmpty ? null : result.pickListLabel;
        });
        return;
      }
      void fill(TextEditingController c, String key) {
        final v = result.data[key];
        if (v != null) c.text = v;
      }

      fill(_name, 'bandName');
      fill(_metalArchives, 'metalArchives');
      fill(_musicBrainz, 'musicBrainz');
      fill(_latestAlbum, 'latestAlbum');
      fill(_site, 'officalSite');
      fill(_image, 'imageUrl');
      fill(_youtube, 'youtube');
      fill(_wikipedia, 'wikipedia');
      fill(_country, 'country');
      fill(_genre, 'genre');
      if (_useCityState) {
        fill(_city, 'city');
        final stateRaw = result.data['state'];
        if (stateRaw != null && stateRaw.trim().isNotEmpty) {
          _state.text = _normalizedState(stateRaw);
        }
      }

      setState(() {
        _discovering = false;
        _discoverStatus =
            'Populated from ${result.source}.';
        _discoverWarnings =
            result.warnings.isEmpty ? null : result.warnings.join(' ');
        _discoverPickListUrl = null;
        _discoverPickListLabel = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _discovering = false;
        _discoverStatus = 'Request failed: $e';
        _discoverPickListUrl = null;
        _discoverPickListLabel = null;
      });
    }
  }

  Future<void> _saveBand() async {
    if (!_canEdit) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Artist name is required.');
      return;
    }
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final updated = List<BandRow>.from(_bands);
      final row = _rowFromForm(name);
      final editIdx = _editingIndex;
      if (editIdx != null && editIdx >= 0 && editIdx < updated.length) {
        updated[editIdx] = row;
      } else {
        updated.add(row);
      }
      // Keep file order as entered; alphabetical sorting is display-only.
      await widget.lineupService.save(widget.workspace, updated);

      var descriptionNote = '';
      String? handoffLink;
      final wantDescription = _addDescription && !_isEditing;
      final descriptionText = _description.text.trim();
      if (wantDescription && descriptionText.isNotEmpty) {
        if (widget.workspace.canEditDescriptions) {
          if (widget.workspace.descriptionMapUrl.trim().isEmpty) {
            throw StateError(
              'Description map URL is not configured — '
              'Load festival data in Settings, or uncheck Add description.',
            );
          }
          await widget.descriptionMapService.writeDescriptionAndUpsertMap(
            workspace: widget.workspace,
            labelName: name,
            text: descriptionText,
          );
          descriptionNote = ' Description saved and added to the map.';
        } else {
          handoffLink =
              await widget.descriptionMapService.writeDescriptionFileForUser(
            labelName: name,
            text: descriptionText,
            promptForFolder: () => showDropboxFolderPicker(
              context: context,
              dropboxApi: widget.dropboxApi,
              title: 'Where should descriptions be saved?',
            ),
          );
          descriptionNote =
              ' Description file saved — copy the link below for the description admin.';
        }
      }

      _clearForm();
      setState(() {
        _bands = updated;
        _saving = false;
        _editingIndex = null;
        _addDescription = false;
        _shareUrl = handoffLink;
        _message = editIdx != null
            ? 'Updated “$name” in Testing artists.'
            : 'Saved “$name” to Testing artists.$descriptionNote';
      });
      widget.onTabChanged(BandsTab.list);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  void _startAdd() {
    if (!_canEdit) return;
    setState(() {
      _editingIndex = null;
      _addDescription = false;
      _error = null;
      _clearForm();
    });
    widget.onFormModeChanged(false);
    widget.onTabChanged(BandsTab.add);
  }

  void _startEdit(int index) {
    if (!_canEdit) return;
    final band = _bands[index];
    setState(() {
      _editingIndex = index;
      _addDescription = false;
      _error = null;
      _fillForm(band);
    });
    widget.onFormModeChanged(true);
    widget.onTabChanged(BandsTab.add);
  }

  Future<void> _deleteBand(int index) async {
    if (!_canEdit) return;
    final band = _bands[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Remove band'),
        content: Text('Remove ${band.name} from the artists list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = List<BandRow>.from(_bands)..removeAt(index);
      await widget.lineupService.save(widget.workspace, updated);
      setState(() {
        _bands = updated;
        _saving = false;
        _message = 'Removed “${band.name}” from Testing artists.';
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    if (widget.tab == BandsTab.add) {
      return _buildForm();
    }
    return _buildList();
  }

  Widget _buildList() {
    final order = _bandsDisplayOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.workspace.bandListUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Reading from: ${widget.workspace.bandListUrl}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (_message != null) StatusBanner(text: _message!),
        if (_error != null) StatusBanner(text: _error!, isError: true),
        if (_shareUrl != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2430),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF6B8CFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share this URL with whoever maintains the description map:',
                  style: TextStyle(color: AppColors.label),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  _shareUrl!,
                  style: const TextStyle(color: AppColors.heading),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final url = _shareUrl!;
                    await Clipboard.setData(ClipboardData(text: url));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied to clipboard')),
                    );
                  },
                  child: const Text('Copy URL'),
                ),
              ],
            ),
          ),
        if (!_canEdit)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: StatusBanner(
              text: 'View only — no Dropbox write access to the artists list. '
                  'Add, Edit, and Delete are disabled.',
            ),
          ),
        if (_saving) const LinearProgressIndicator(color: AppColors.accent),
        Expanded(
          child: PortalPanel(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    FilledButton(
                      onPressed: _canEdit ? _startAdd : null,
                      child: const Text('Add artist'),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _bands.isEmpty
                          ? null
                          : () => showArtistsExportDialog(
                                context,
                                workspace: widget.workspace,
                                bands: _bands,
                              ),
                      icon: const Icon(Icons.ios_share_outlined, size: 18),
                      label: const Text('Export…'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _bands.isEmpty
                      ? const Text(
                          'No artists in the Testing lineup yet.',
                          style: TextStyle(color: AppColors.muted),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columnSpacing: 14,
                                    horizontalMargin: 8,
                                    headingRowHeight: 40,
                                    dataRowMinHeight: 40,
                                    dataRowMaxHeight: adminTableRowHeight,
                                    dividerThickness: 1,
                                    border: TableBorder(
                                      horizontalInside: BorderSide(
                                        color: AppColors.panelBorder
                                            .withValues(alpha: 0.85),
                                      ),
                                      verticalInside: BorderSide(
                                        color: AppColors.panelBorder
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFF222222),
                                    ),
                                    columns: [
                                      DataColumn(
                                        columnWidth: adminTableWideFlexColumn,
                                        label: Text('Band'),
                                      ),
                                      DataColumn(
                                        columnWidth: adminTableFlexColumn,
                                        label: Text('Country'),
                                      ),
                                      DataColumn(
                                        columnWidth: adminTableWideFlexColumn,
                                        label: Text('Genre'),
                                      ),
                                      DataColumn(
                                        columnWidth: adminTableWideFlexColumn,
                                        label: Text('Noteworthy'),
                                      ),
                                      DataColumn(
                                        columnWidth: adminTableActionsColumn,
                                        label: adminTableActionsHeading(),
                                      ),
                                    ],
                                    rows: [
                                      for (final i in order)
                                        DataRow(
                                          cells: [
                                            DataCell(
                                              adminTableText(_bands[i].name),
                                            ),
                                            DataCell(
                                              adminTableText(_bands[i].country),
                                            ),
                                            DataCell(
                                              adminTableText(_bands[i].genre),
                                            ),
                                            DataCell(
                                              adminTableText(
                                                _bands[i].noteworthy,
                                              ),
                                            ),
                                            DataCell(
                                              adminTableActionsCell([
                                                OutlinedButton(
                                                  style: OutlinedButton
                                                      .styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  onPressed: !_canEdit || _saving
                                                      ? null
                                                      : () => _startEdit(i),
                                                  child: const Text('Edit'),
                                                ),
                                                OutlinedButton(
                                                  style: OutlinedButton
                                                      .styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  onPressed: !_canEdit || _saving
                                                      ? null
                                                      : () => _deleteBand(i),
                                                  child: const Text('Delete'),
                                                ),
                                              ]),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _load(forceRefresh: true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('${_bands.length} artist(s) — Refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: PortalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) StatusBanner(text: _error!, isError: true),
            if (!widget.dropboxConnected)
              const StatusBanner(
                text: 'Connect Dropbox in Settings to save artists.',
                isError: true,
              ),
            UrlImagePreview(controller: _image),
            FormRow(
              label: 'Artist name',
              requiredField: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _name),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _discovering ? null : _runDiscover,
                    child: Text(_discovering ? 'Discovering…' : 'Discover'),
                  ),
                  if (_discoverStatus != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _discoverStatus!,
                      style: TextStyle(
                        color: _discoverStatus!.startsWith('Populated')
                            ? AppColors.successText
                            : AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_discoverPickListUrl != null) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () async {
                        final uri = Uri.tryParse(_discoverPickListUrl!);
                        if (uri == null) return;
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.accent,
                      ),
                      child: Text(
                        _discoverPickListLabel ?? 'Open search results',
                        style: const TextStyle(
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                  if (_discoverWarnings != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _discoverWarnings!,
                      style: const TextStyle(
                        color: Color(0xFFFFB86B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const HintText(
                    'Standard: type the band name, click Discover, then verify. '
                    'If several matches appear, research the links, paste the '
                    'correct URL into Metal Archives or MusicBrainz below, and '
                    'Discover again. You can always edit or replace any field by '
                    'hand. Prefer a band page URL when name search is ambiguous.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Metal Archives',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _metalArchives,
                    decoration: const InputDecoration(
                      hintText: 'https://www.metal-archives.com/bands/...',
                    ),
                  ),
                  const HintText(
                    'Optional. Band page URL; stored with https://. '
                    'Discover uses this when provided.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'MusicBrainz',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _musicBrainz,
                    decoration: const InputDecoration(
                      hintText: 'https://musicbrainz.org/artist/...',
                    ),
                  ),
                  const HintText(
                    'Artist page URL (not saved to CSV). Used when Metal Archives '
                    'is unavailable.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Latest album',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _latestAlbum),
                  const HintText(
                    'Optional. From discography; used for YouTube search only '
                    '(not saved to CSV).',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Official site',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _site),
                  const HintText('Stored without https://.'),
                ],
              ),
            ),
            FormRow(
              label: 'Image URL',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _image),
                  const HintText('Stored without https://.'),
                ],
              ),
            ),
            FormRow(
              label: 'YouTube',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _youtube),
                  const HintText(
                    'Search URL; stored with https://. Filled by Discover.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Wikipedia',
              child: TextField(controller: _wikipedia),
            ),
            FormRow(
              label: 'Country',
              child: TextField(controller: _country),
            ),
            if (_useCityState) ...[
              FormRow(
                label: 'City',
                child: TextField(controller: _city),
              ),
              FormRow(
                label: 'State',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _state,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(32),
                      ],
                      onEditingComplete: () {
                        final normalized = _normalizedState(_state.text);
                        if (normalized != _state.text) {
                          _state.text = normalized;
                          _state.selection = TextSelection.collapsed(
                            offset: normalized.length,
                          );
                        }
                      },
                    ),
                    const HintText(
                      'Optional. Two-letter US state code (e.g. CA). '
                      'Full names from Discover are converted automatically.',
                    ),
                  ],
                ),
              ),
            ],
            FormRow(
              label: 'Genre',
              child: TextField(controller: _genre),
            ),
            FormRow(
              label: 'Noteworthy',
              child: TextField(controller: _noteworthy, maxLines: 3),
            ),
            FormRow(
              label: 'Prior years',
              child: TextField(controller: _priorYears),
            ),
            if (!_isEditing)
              FormRow(
                label: 'Description',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _addDescription,
                      onChanged: (v) =>
                          setState(() => _addDescription = v ?? false),
                      title: const Text(
                        'Add description',
                        style: TextStyle(color: AppColors.heading, fontSize: 15),
                      ),
                      activeColor: AppColors.accent,
                    ),
                    if (_addDescription) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: _description,
                        maxLines: 8,
                        minLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Band description text…',
                        ),
                      ),
                      HintText(
                        widget.workspace.canEditDescriptions
                            ? 'Writes the description file and adds it to the '
                                'description map automatically.'
                            : 'Saves to your Dropbox folder; you will get a '
                                'link to share with the description admin.',
                      ),
                    ] else
                      HintText(
                        widget.workspace.canEditDescriptions
                            ? 'Check to enter a description that will be saved '
                                'and mapped when you save this band.'
                            : 'Check to enter a description file (map handoff '
                                'link will be shown after save).',
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: !_canEdit || _saving ? null : _saveBand,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : (_isEditing ? 'Save changes' : 'Save to Testing'),
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _editingIndex = null;
                      _addDescription = false;
                      _clearForm();
                    });
                    widget.onTabChanged(BandsTab.list);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
