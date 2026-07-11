import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/portal_dropdown.dart';

class DescriptionsSection extends StatefulWidget {
  const DescriptionsSection({
    super.key,
    required this.workspace,
    required this.descriptionMapService,
    required this.lineupService,
    required this.scheduleService,
    required this.tab,
    required this.onTabChanged,
    required this.dropboxConnected,
    required this.onConnectDropbox,
    this.prefillLabel,
    this.onPrefillConsumed,
  });

  final FestivalWorkspace workspace;
  final DescriptionMapService descriptionMapService;
  final LineupService lineupService;
  final ScheduleService scheduleService;
  final DescriptionsTab tab;
  final ValueChanged<DescriptionsTab> onTabChanged;
  final bool dropboxConnected;
  final Future<void> Function() onConnectDropbox;
  final String? prefillLabel;
  final VoidCallback? onPrefillConsumed;

  @override
  State<DescriptionsSection> createState() => _DescriptionsSectionState();
}

class _DescriptionsSectionState extends State<DescriptionsSection> {
  List<DescriptionMapEntry> _entries = [];
  List<String> _labelNames = [];
  String? _error;
  String? _message;
  String? _shareUrl;
  bool _loading = true;
  bool _saving = false;

  String? _writeLabel;
  final _writeText = TextEditingController();

  String? _mapLabel;
  final _mapUrl = TextEditingController();
  final _mapDate = TextEditingController();
  int? _mapEditingIndex;

  bool get _isEditingMap => _mapEditingIndex != null;

  @override
  void initState() {
    super.initState();
    _mapDate.text = DescriptionMapService.cacheDateToday();
    _load();
  }

  @override
  void dispose() {
    _writeText.dispose();
    _mapUrl.dispose();
    _mapDate.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DescriptionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prefill = widget.prefillLabel?.trim();
    if (prefill != null &&
        prefill.isNotEmpty &&
        prefill != oldWidget.prefillLabel) {
      _applyPrefill(prefill);
    }
  }

  void _applyPrefill(String label) {
    setState(() {
      if (!_labelNames.contains(label)) {
        _labelNames = [..._labelNames, label]..sort();
      }
      _writeLabel = label;
      _writeText.clear();
      _message = 'Writing description for $label.';
    });
    widget.onPrefillConsumed?.call();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries =
          await widget.descriptionMapService.load(widget.workspace);
      final labels = <String>{};
      try {
        final bands = await widget.lineupService.load(widget.workspace);
        for (final b in bands) {
          if (b.name.isNotEmpty) labels.add(b.name);
        }
      } catch (_) {}
      try {
        final events = await widget.scheduleService.load(widget.workspace);
        for (final e in events) {
          if (e.band.isNotEmpty) labels.add(e.band);
        }
      } catch (_) {}
      for (final e in entries) {
        if (e.band.isNotEmpty) labels.add(e.band);
      }
      final prefill = widget.prefillLabel?.trim();
      if (prefill != null && prefill.isNotEmpty) labels.add(prefill);
      final sorted = labels.toList()..sort();
      final options = DropdownOptions.withEmpty(sorted);
      setState(() {
        _entries = entries;
        _labelNames = sorted;
        _writeLabel = DropdownOptions.pick(
          (prefill != null && prefill.isNotEmpty) ? prefill : null,
          options,
        );
        _mapLabel = DropdownOptions.empty;
        _loading = false;
        if (prefill != null && prefill.isNotEmpty) {
          _message = 'Writing description for $prefill.';
        }
      });
      if (prefill != null && prefill.isNotEmpty) {
        widget.onPrefillConsumed?.call();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveWrite({required bool addToMap}) async {
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    final label = (_writeLabel ?? '').trim();
    final text = _writeText.text.trim();
    if (label.isEmpty || text.isEmpty) {
      setState(() => _error = 'Band / event name and description text are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
      _shareUrl = null;
    });
    try {
      final shareUrl = await widget.descriptionMapService.writeDescriptionFile(
        workspace: widget.workspace,
        labelName: label,
        text: text,
      );
      if (addToMap) {
        final updated = List<DescriptionMapEntry>.from(_entries);
        final idx = updated.indexWhere(
          (e) => e.band.toLowerCase() == label.toLowerCase(),
        );
        final entry = DescriptionMapEntry(
          band: label,
          url: shareUrl,
          date: DescriptionMapService.cacheDateToday(),
        );
        if (idx >= 0) {
          updated[idx] = entry;
        } else {
          updated.add(entry);
        }
        updated.sort(
          (a, b) => a.band.toLowerCase().compareTo(b.band.toLowerCase()),
        );
        await widget.descriptionMapService.save(widget.workspace, updated);
        _entries = updated;
      }
      setState(() {
        _saving = false;
        // Only expose the URL when the map was not updated — user may need to
        // copy it for someone else / Map tab. Save & add to map already stored it.
        _shareUrl = addToMap ? null : shareUrl;
        _message = addToMap
            ? 'Saved description and updated map for $label.'
            : 'Saved description file for $label.';
        _writeText.clear();
        _writeLabel = DropdownOptions.empty;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveMapEntry() async {
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    final label = (_mapLabel ?? '').trim();
    final url = normalizeDropboxUrl(_mapUrl.text.trim());
    if (label.isEmpty || url.isEmpty) {
      setState(() => _error = 'Band / event name and Dropbox URL are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });
    try {
      final date = _mapDate.text.trim().isEmpty
          ? DescriptionMapService.cacheDateToday()
          : _mapDate.text.trim();
      final updated = List<DescriptionMapEntry>.from(_entries);
      final editIdx = _mapEditingIndex;
      final entry = DescriptionMapEntry(band: label, url: url, date: date);
      if (editIdx != null && editIdx >= 0 && editIdx < updated.length) {
        updated[editIdx] = entry;
      } else {
        final byName = updated.indexWhere(
          (e) => e.band.toLowerCase() == label.toLowerCase(),
        );
        if (byName >= 0) {
          updated[byName] = entry;
        } else {
          updated.add(entry);
        }
      }
      updated.sort(
        (a, b) => a.band.toLowerCase().compareTo(b.band.toLowerCase()),
      );
      await widget.descriptionMapService.save(widget.workspace, updated);
      setState(() {
        _entries = updated;
        _saving = false;
        _mapEditingIndex = null;
        _message = editIdx != null
            ? 'Updated map entry for $label.'
            : 'Map entry saved for $label.';
        _mapUrl.clear();
        _mapDate.text = DescriptionMapService.cacheDateToday();
        _mapLabel = DropdownOptions.empty;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  void _startEditMap(int index) {
    final e = _entries[index];
    setState(() {
      _mapEditingIndex = index;
      if (!_labelNames.contains(e.band)) {
        _labelNames = [..._labelNames, e.band]..sort();
      }
      _mapLabel = DropdownOptions.pick(
        e.band,
        DropdownOptions.withEmpty(_labelNames),
      );
      _mapUrl.text = e.url;
      _mapDate.text =
          e.date.isEmpty ? DescriptionMapService.cacheDateToday() : e.date;
      _error = null;
      _message = 'Editing map entry for ${e.band}.';
    });
  }

  Future<void> _deleteMapEntry(int index) async {
    final e = _entries[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Remove map entry'),
        content: Text('Remove ${e.band} from the description map?'),
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
      final updated = List<DescriptionMapEntry>.from(_entries)..removeAt(index);
      await widget.descriptionMapService.save(widget.workspace, updated);
      setState(() {
        _entries = updated;
        _saving = false;
        if (_mapEditingIndex == index) {
          _mapEditingIndex = null;
          _mapUrl.clear();
          _mapDate.text = DescriptionMapService.cacheDateToday();
        } else if (_mapEditingIndex != null && _mapEditingIndex! > index) {
          _mapEditingIndex = _mapEditingIndex! - 1;
        }
        _message = 'Removed “${e.band}” from description map (in place).';
      });
    } catch (err) {
      setState(() {
        _saving = false;
        _error = err.toString();
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
    if (widget.tab == DescriptionsTab.map) {
      return _buildMap();
    }
    return _buildWrite();
  }

  Widget _buildWrite() {
    final labels = DropdownOptions.withEmpty(_labelNames);
    return SingleChildScrollView(
      child: PortalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Descriptions folder: beside the description map file '
              '(${widget.workspace.descriptionMapUrl.isEmpty ? 'not configured' : 'from testing pointer'}).',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if (_message != null) StatusBanner(text: _message!),
            if (_error != null) StatusBanner(text: _error!, isError: true),
            if (_shareUrl != null) ...[
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
                      'Next step: copy this URL for the Map (or send it to the Map admin).',
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
            ],
            if (!widget.dropboxConnected)
              const StatusBanner(
                text: 'Connect Dropbox in Settings to write descriptions.',
                isError: true,
              ),
            FormRow(
              label: 'Band / event name',
              requiredField: true,
              child: PortalStringDropdown(
                value: _writeLabel,
                items: labels,
                onChanged: (v) => setState(() => _writeLabel = v),
                labelBuilder: (n) => n.isEmpty
                    ? (_labelNames.isEmpty ? '— load lineup first —' : '—')
                    : n,
              ),
            ),
            FormRow(
              label: 'Description text',
              requiredField: true,
              child: TextField(
                controller: _writeText,
                maxLines: 12,
                minLines: 8,
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: _saving ? null : () => _saveWrite(addToMap: true),
                  child: Text(
                    _saving ? 'Saving…' : 'Save & add to map',
                  ),
                ),
                OutlinedButton(
                  onPressed: _saving ? null : () => _saveWrite(addToMap: false),
                  child: const Text('Save description file only'),
                ),
                OutlinedButton(
                  onPressed: () => widget.onTabChanged(DescriptionsTab.map),
                  child: const Text('Open Map'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final labels = DropdownOptions.withEmpty(_labelNames);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null) StatusBanner(text: _message!),
        if (_error != null) StatusBanner(text: _error!, isError: true),
        Expanded(
          child: SingleChildScrollView(
            child: PortalPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FormRow(
                    label: 'Band / event name',
                    requiredField: true,
                    child: PortalStringDropdown(
                      value: _mapLabel,
                      items: labels,
                      onChanged: (v) => setState(() => _mapLabel = v),
                      labelBuilder: (n) => n.isEmpty ? '—' : n,
                    ),
                  ),
                  FormRow(
                    label: 'Dropbox URL',
                    requiredField: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _mapUrl,
                          decoration: const InputDecoration(
                            hintText: 'https://www.dropbox.com/...',
                          ),
                        ),
                        const HintText(
                          'dl=0 is replaced with raw=1 automatically on save.',
                        ),
                      ],
                    ),
                  ),
                  FormRow(
                    label: 'Cache date',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _mapDate,
                          decoration: const InputDecoration(
                            hintText: 'MM-DD-YYYY',
                          ),
                        ),
                        const HintText('Defaults to today.'),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 10,
                    children: [
                      FilledButton(
                        onPressed: _saving ? null : _saveMapEntry,
                        child: Text(
                          _saving
                              ? 'Saving…'
                              : (_isEditingMap
                                  ? 'Save changes'
                                  : 'Save map entry'),
                        ),
                      ),
                      if (_isEditingMap)
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _mapEditingIndex = null;
                            _mapUrl.clear();
                            _mapDate.text =
                                DescriptionMapService.cacheDateToday();
                            _message = null;
                          }),
                          child: const Text('Cancel edit'),
                        ),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Current map',
                    style: TextStyle(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_entries.isEmpty)
                    const Text(
                      'No map entries yet.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFF222222),
                        ),
                        columns: const [
                          DataColumn(label: Text('Band')),
                          DataColumn(label: Text('URL')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: [
                          for (var i = 0; i < _entries.length; i++)
                            DataRow(
                              cells: [
                                DataCell(Text(_entries[i].band)),
                                DataCell(
                                  SizedBox(
                                    width: 360,
                                    child: Text(
                                      _entries[i].url,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(_entries[i].date)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      OutlinedButton(
                                        onPressed: _saving
                                            ? null
                                            : () => _startEditMap(i),
                                        child: const Text('Edit'),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: _saving
                                            ? null
                                            : () => _deleteMapEntry(i),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
