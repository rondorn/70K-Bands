import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/dropbox_folder_picker.dart';

enum _FormMode { addDescription, addLink, edit }

class _ListRow {
  _ListRow({
    required this.name,
    required this.entry,
    required this.inLineup,
  });

  final String name;
  final DescriptionMapEntry? entry;
  final bool inLineup;

  bool get hasDescription =>
      entry != null && entry!.url.trim().isNotEmpty;
}

class DescriptionsSection extends StatefulWidget {
  const DescriptionsSection({
    super.key,
    required this.workspace,
    required this.descriptionMapService,
    required this.lineupService,
    required this.dropboxApi,
    required this.tab,
    required this.onTabChanged,
    required this.onFormModeChanged,
    required this.dropboxConnected,
    required this.onConnectDropbox,
    this.prefillLabel,
    this.onPrefillConsumed,
  });

  final FestivalWorkspace workspace;
  final DescriptionMapService descriptionMapService;
  final LineupService lineupService;
  final DropboxApi dropboxApi;
  final DescriptionsTab tab;
  final ValueChanged<DescriptionsTab> onTabChanged;
  final ValueChanged<String> onFormModeChanged;
  final bool dropboxConnected;
  final Future<void> Function() onConnectDropbox;
  final String? prefillLabel;
  final VoidCallback? onPrefillConsumed;

  @override
  State<DescriptionsSection> createState() => _DescriptionsSectionState();
}

class _DescriptionsSectionState extends State<DescriptionsSection> {
  List<_ListRow> _rows = [];
  String? _error;
  String? _message;
  String? _shareUrl;
  bool _loading = true;
  bool _saving = false;

  _FormMode _formMode = _FormMode.addDescription;
  String _formLabel = '';
  final _text = TextEditingController();
  final _url = TextEditingController();
  bool _editText = true;
  bool _editLink = false;
  bool _loadingText = false;

  bool get _canEditMap => widget.workspace.canEditDescriptions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DescriptionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prefill = widget.prefillLabel?.trim();
    if (prefill != null &&
        prefill.isNotEmpty &&
        prefill != oldWidget.prefillLabel) {
      _openAddDescription(prefill);
      widget.onPrefillConsumed?.call();
    }
    if (widget.tab == DescriptionsTab.list &&
        oldWidget.tab != DescriptionsTab.list) {
      _clearForm(keepMessage: true);
    }
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<DescriptionMapEntry> entries = [];
      try {
        entries = await widget.descriptionMapService.load(
          widget.workspace,
          forceRefresh: forceRefresh,
        );
      } catch (e) {
        // Still show lineup even if map is missing / unreadable.
        if (widget.workspace.descriptionMapUrl.trim().isNotEmpty) {
          _error = e.toString();
        }
      }

      final lineupNames = <String>{};
      try {
        final bands = await widget.lineupService.load(
          widget.workspace,
          forceRefresh: forceRefresh,
        );
        for (final b in bands) {
          if (b.name.trim().isNotEmpty) lineupNames.add(b.name.trim());
        }
      } catch (_) {}

      final byName = <String, DescriptionMapEntry>{};
      for (final e in entries) {
        if (e.band.trim().isEmpty) continue;
        byName[e.band.trim().toLowerCase()] = e;
      }

      final rows = <_ListRow>[];
      final seen = <String>{};
      for (final name in lineupNames) {
        final key = name.toLowerCase();
        seen.add(key);
        rows.add(
          _ListRow(
            name: name,
            entry: byName[key],
            inLineup: true,
          ),
        );
      }
      for (final e in entries) {
        final key = e.band.trim().toLowerCase();
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        rows.add(
          _ListRow(
            name: e.band.trim(),
            entry: e,
            inLineup: false,
          ),
        );
      }
      rows.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      final prefill = widget.prefillLabel?.trim();
      setState(() {
        _rows = rows;
        _loading = false;
      });
      if (prefill != null && prefill.isNotEmpty) {
        _openAddDescription(prefill);
        widget.onPrefillConsumed?.call();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _clearForm({bool keepMessage = false}) {
    _formLabel = '';
    _text.clear();
    _url.clear();
    _editText = true;
    _editLink = false;
    _loadingText = false;
    if (!keepMessage) {
      _message = null;
      _shareUrl = null;
      _error = null;
    }
  }

  void _openAddDescription(String name) {
    setState(() {
      _formMode = _FormMode.addDescription;
      _formLabel = name;
      _text.clear();
      _url.clear();
      _error = null;
      _message = null;
      _shareUrl = null;
    });
    widget.onFormModeChanged('Create Description');
    widget.onTabChanged(DescriptionsTab.form);
  }

  void _openAddLink(String name) {
    if (!_canEditMap) return;
    setState(() {
      _formMode = _FormMode.addLink;
      _formLabel = name;
      _text.clear();
      _url.clear();
      _error = null;
      _message = null;
      _shareUrl = null;
    });
    widget.onFormModeChanged('Attach Link');
    widget.onTabChanged(DescriptionsTab.form);
  }

  Future<void> _openEdit(_ListRow row) async {
    if (!_canEditMap || row.entry == null) return;
    setState(() {
      _formMode = _FormMode.edit;
      _formLabel = row.name;
      _url.text = row.entry!.url;
      _text.clear();
      _editText = true;
      _editLink = false;
      _error = null;
      _message = null;
      _shareUrl = null;
      _loadingText = true;
    });
    widget.onFormModeChanged('Edit Description');
    widget.onTabChanged(DescriptionsTab.form);
    try {
      final text =
          await widget.descriptionMapService.loadDescriptionText(row.entry!.url);
      if (!mounted) return;
      setState(() {
        _text.text = text;
        _loadingText = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingText = false;
        _error =
            'Could not load description text (you can still edit the link): $e';
        _editText = false;
        _editLink = true;
      });
    }
  }

  Future<String?> _promptFolder() {
    return showDropboxFolderPicker(
      context: context,
      dropboxApi: widget.dropboxApi,
      title: 'Where should descriptions be saved?',
    );
  }

  Future<void> _saveAddDescription() async {
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    final label = _formLabel.trim();
    final text = _text.text;
    if (label.isEmpty || text.trim().isEmpty) {
      setState(() => _error = 'Artist name and description text are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
      _shareUrl = null;
    });
    try {
      String shareUrl;
      if (_canEditMap) {
        if (widget.workspace.descriptionMapUrl.trim().isEmpty) {
          throw StateError(
            'Description map URL is not configured — Load festival data in Settings.',
          );
        }
        shareUrl =
            await widget.descriptionMapService.writeDescriptionAndUpsertMap(
          workspace: widget.workspace,
          labelName: label,
          text: text,
        );
        await _load();
        setState(() {
          _saving = false;
          _message = 'Saved description and updated the map for $label.';
          _shareUrl = null;
        });
        widget.onTabChanged(DescriptionsTab.list);
      } else {
        shareUrl =
            await widget.descriptionMapService.writeDescriptionFileForUser(
          labelName: label,
          text: text,
          promptForFolder: _promptFolder,
        );
        setState(() {
          _saving = false;
          _shareUrl = shareUrl;
          _message =
              'Saved description for $label. Copy this link and send it to '
              'whoever maintains the description map.';
        });
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveAddLink() async {
    if (!_canEditMap) return;
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    final label = _formLabel.trim();
    final url = normalizeDropboxUrl(_url.text.trim());
    if (label.isEmpty || url.isEmpty) {
      setState(() => _error = 'Artist name and Dropbox URL are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.descriptionMapService.upsertMapEntry(
        workspace: widget.workspace,
        labelName: label,
        url: url,
        bumpDate: true,
      );
      await _load();
      setState(() {
        _saving = false;
        _message = 'Added description link for $label.';
      });
      widget.onTabChanged(DescriptionsTab.list);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveEdit() async {
    if (!_canEditMap) return;
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    final label = _formLabel.trim();
    if (label.isEmpty) {
      setState(() => _error = 'Artist name is required.');
      return;
    }
    if (!_editText && !_editLink) {
      setState(() => _error = 'Choose Edit description text or Edit description link.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final current = _rows
          .where((r) => r.name.toLowerCase() == label.toLowerCase())
          .map((r) => r.entry)
          .firstWhere((e) => e != null, orElse: () => null);
      var url = normalizeDropboxUrl(_url.text.trim());
      if (url.isEmpty) url = current?.url.trim() ?? '';

      if (_editLink) {
        if (url.isEmpty) {
          throw StateError('Dropbox URL is required.');
        }
        // Link-only: update map URL and bump cache date. Do not rewrite
        // description file text.
        await widget.descriptionMapService.upsertMapEntry(
          workspace: widget.workspace,
          labelName: label,
          url: url,
          bumpDate: true,
        );
      } else if (_editText) {
        final text = _text.text;
        if (text.trim().isEmpty) {
          throw StateError('Description text is required.');
        }
        if (url.isEmpty) {
          throw StateError('No description URL to update.');
        }
        await widget.descriptionMapService.updateDescriptionTextInPlace(
          workspace: widget.workspace,
          labelName: label,
          shareUrl: url,
          text: text,
        );
      }

      await _load();
      setState(() {
        _saving = false;
        _message = _editLink
            ? 'Updated description link for $label (cache date bumped).'
            : 'Updated description for $label.';
      });
      widget.onTabChanged(DescriptionsTab.list);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deleteRow(_ListRow row) async {
    if (!_canEditMap || row.entry == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Remove map entry'),
        content: Text(
          'Remove ${row.name} from the description map?\n\n'
          'The Dropbox description file is not deleted.',
        ),
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
      await widget.descriptionMapService.removeMapEntry(
        workspace: widget.workspace,
        labelName: row.name,
      );
      await _load();
      setState(() {
        _saving = false;
        _message = 'Removed “${row.name}” from the description map.';
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
    if (_loading && widget.tab == DescriptionsTab.list) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (widget.tab == DescriptionsTab.form) {
      return _buildForm();
    }
    return _buildList();
  }

  Widget _shareBanner() {
    if (_shareUrl == null) return const SizedBox.shrink();
    return Container(
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
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null) StatusBanner(text: _message!),
        if (_error != null) StatusBanner(text: _error!, isError: true),
        _shareBanner(),
        if (!_canEditMap)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: StatusBanner(
              text: 'No description-map write access. You can still create '
                  'description files (you will be asked where to save them) '
                  'and copy the link for the description admin. Map Edit / '
                  'Delete and Attach Link are hidden.',
            ),
          ),
        if (_saving) const LinearProgressIndicator(color: AppColors.accent),
        Expanded(
          child: PortalPanel(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _rows.isEmpty
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
                                    dataRowMinHeight: 44,
                                    dataRowMaxHeight: 56,
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFF222222),
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('Artist')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Cache date')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: [
                                      for (final row in _rows)
                                        DataRow(
                                          color: WidgetStateProperty.all(
                                            row.hasDescription
                                                ? null
                                                : const Color(0xFF1E1E1E),
                                          ),
                                          cells: [
                                            DataCell(
                                              Text(
                                                row.name,
                                                style: TextStyle(
                                                  color: row.hasDescription
                                                      ? AppColors.heading
                                                      : AppColors.muted,
                                                  fontWeight: row.hasDescription
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                row.hasDescription
                                                    ? (row.inLineup
                                                        ? 'On map'
                                                        : 'On map (not in lineup)')
                                                    : 'No description',
                                                style: TextStyle(
                                                  color: row.hasDescription
                                                      ? AppColors.label
                                                      : AppColors.muted,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                row.entry?.date ?? '—',
                                                style: TextStyle(
                                                  color: row.hasDescription
                                                      ? AppColors.label
                                                      : AppColors.muted,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (!row.hasDescription) ...[
                                                    OutlinedButton(
                                                      style: _actionStyle,
                                                      onPressed: _saving
                                                          ? null
                                                          : () =>
                                                              _openAddDescription(
                                                                row.name,
                                                              ),
                                                      child: const Text(
                                                        'Create Description',
                                                      ),
                                                    ),
                                                    if (_canEditMap) ...[
                                                      const SizedBox(width: 6),
                                                      OutlinedButton(
                                                        style: _actionStyle,
                                                        onPressed: _saving
                                                            ? null
                                                            : () =>
                                                                _openAddLink(
                                                                  row.name,
                                                                ),
                                                        child: const Text(
                                                          'Attach Link',
                                                        ),
                                                      ),
                                                    ],
                                                  ] else if (_canEditMap) ...[
                                                    OutlinedButton(
                                                      style: _actionStyle,
                                                      onPressed: _saving
                                                          ? null
                                                          : () =>
                                                              _openEdit(row),
                                                      child: const Text('Edit'),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    OutlinedButton(
                                                      style: _actionStyle,
                                                      onPressed: _saving
                                                          ? null
                                                          : () =>
                                                              _deleteRow(row),
                                                      child:
                                                          const Text('Delete'),
                                                    ),
                                                  ] else
                                                    Text(
                                                      row.entry?.url ?? '',
                                                      style: const TextStyle(
                                                        color: AppColors.muted,
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                ],
                                              ),
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
                    onPressed: _saving ? null : () => _load(forceRefresh: true),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('${_rows.length} artist(s) — Refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  ButtonStyle get _actionStyle => OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );

  Widget _buildForm() {
    return SingleChildScrollView(
      child: PortalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message != null) StatusBanner(text: _message!),
            if (_error != null) StatusBanner(text: _error!, isError: true),
            _shareBanner(),
            if (!widget.dropboxConnected)
              const StatusBanner(
                text: 'Connect Dropbox in Settings to save descriptions.',
                isError: true,
              ),
            FormRow(
              label: 'Artist',
              child: Text(
                _formLabel,
                style: const TextStyle(
                  color: AppColors.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_formMode == _FormMode.addDescription) ...[
              FormRow(
                label: 'Description text',
                requiredField: true,
                child: TextField(
                  controller: _text,
                  maxLines: 14,
                  minLines: 8,
                ),
              ),
              if (!_canEditMap)
                const HintText(
                  'Without map write access, the file is saved in your chosen '
                  'Dropbox folder and you get a link to share with the '
                  'description admin.',
                ),
            ],
            if (_formMode == _FormMode.addLink) ...[
              FormRow(
                label: 'Dropbox URL',
                requiredField: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _url,
                      decoration: const InputDecoration(
                        hintText: 'https://www.dropbox.com/...',
                      ),
                    ),
                    const HintText(
                      'dl=0 is replaced with raw=1 automatically on save. '
                      'Cache date is set so fan apps refresh.',
                    ),
                  ],
                ),
              ),
            ],
            if (_formMode == _FormMode.edit) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _editText,
                onChanged: (v) {
                  final on = v ?? false;
                  setState(() {
                    _editText = on;
                    if (on) _editLink = false;
                  });
                },
                title: const Text(
                  'Edit description text',
                  style: TextStyle(color: AppColors.heading, fontSize: 15),
                ),
                activeColor: AppColors.accent,
              ),
              if (_editText && !_editLink)
                FormRow(
                  label: 'Description text',
                  requiredField: true,
                  child: _loadingText
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          ),
                        )
                      : TextField(
                          controller: _text,
                          maxLines: 12,
                          minLines: 8,
                        ),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _editLink,
                onChanged: (v) {
                  final on = v ?? false;
                  setState(() {
                    _editLink = on;
                    if (on) _editText = false;
                  });
                },
                title: const Text(
                  'Edit description link',
                  style: TextStyle(color: AppColors.heading, fontSize: 15),
                ),
                activeColor: AppColors.accent,
              ),
              if (_editLink)
                FormRow(
                  label: 'Dropbox URL',
                  requiredField: true,
                  child: TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                      hintText: 'https://www.dropbox.com/...',
                    ),
                  ),
                ),
              const HintText(
                'Edit description text updates the file and bumps the cache '
                'date. Edit description link only changes the map URL and '
                'bumps the cache date — description text is left unchanged.',
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () {
                          switch (_formMode) {
                            case _FormMode.addDescription:
                              _saveAddDescription();
                            case _FormMode.addLink:
                              _saveAddLink();
                            case _FormMode.edit:
                              _saveEdit();
                          }
                        },
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
                OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _clearForm(keepMessage: _shareUrl != null);
                          });
                          widget.onTabChanged(DescriptionsTab.list);
                        },
                  child: Text(_shareUrl != null ? 'Back to list' : 'Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
