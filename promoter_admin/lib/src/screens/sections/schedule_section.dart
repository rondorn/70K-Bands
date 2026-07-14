import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_staging.dart';
import 'package:promoter_admin/src/services/schedule_validation.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/dropbox_folder_picker.dart';
import 'package:promoter_admin/src/widgets/portal_dropdown.dart';

class ScheduleSection extends StatefulWidget {
  const ScheduleSection({
    super.key,
    required this.workspace,
    required this.scheduleService,
    required this.lineupService,
    required this.descriptionMapService,
    required this.dropboxApi,
    required this.tab,
    required this.onTabChanged,
    required this.dropboxConnected,
    required this.onConnectDropbox,
    required this.onWorkspaceChanged,
  });

  final FestivalWorkspace workspace;
  final ScheduleService scheduleService;
  final LineupService lineupService;
  final DescriptionMapService descriptionMapService;
  final DropboxApi dropboxApi;
  final ScheduleTab tab;
  final ValueChanged<ScheduleTab> onTabChanged;
  final bool dropboxConnected;
  final Future<void> Function() onConnectDropbox;
  final Future<void> Function(FestivalWorkspace) onWorkspaceChanged;

  @override
  State<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends State<ScheduleSection> {
  List<ScheduleEvent> _events = [];
  List<String> _bandNames = [];
  String? _error;
  String? _message;
  String? _shareUrl;
  bool _loading = true;
  /// True only while validating / writing description / writing local staging.
  /// Dropbox sync runs in the background and must not block Add.
  bool _committing = false;
  /// Keys for events not yet on Dropbox (vs last synced snapshot).
  Set<String> _outstandingKeys = {};
  /// Keys that flipped from outstanding → synced on the latest sync notify.
  Set<String> _justSyncedKeys = {};

  int? _editingIndex;
  /// File index of the event shown in the bottom “last saved” confirmation.
  int? _lastSavedIndex;
  ScheduleEvent? _lastSavedEvent;

  bool get _isEditing => _editingIndex != null;
  bool get _canEdit => widget.workspace.canEditSchedule;

  String? _band;
  String? _type;
  String? _venue;
  String? _day;
  String? _date;
  String _startHour = '12';
  String _startMin = '00';
  String _endHour = '13';
  String _endMin = '00';
  String _length = '60';
  bool _verifyBypass = false;
  final _notes = TextEditingController();
  final _descriptionText = TextEditingController();
  final _imageUrl = TextEditingController();

  bool get _isNonBand =>
      ScheduleValidation.isNonBandEventType((_type ?? '').trim());

  static String _nonBandHelp(String type) {
    switch (type.trim()) {
      case 'Special Event':
        return 'Special Events are official festival activities that are not '
            'band performances (Best Tattoo Contest, organizer speech, etc.). '
            'Enter the event title, description, and optional image. '
            'Band Name is not used.';
      case 'Unofficial Event':
        return 'Unofficial Events are fan-run or unofficial happenings '
            '(pre-parties, meetups, etc.). Enter the event title, description, '
            'and optional image. Band Name is not used.';
      default:
        return '';
    }
  }

  bool get _lengthActive {
    final t = _length.trim();
    return t.isNotEmpty && int.tryParse(t) != null;
  }

  /// File order stays as entered; this is display-only chronological order.
  List<int> get _eventsDisplayOrder {
    final indices = List<int>.generate(_events.length, (i) => i);
    indices.sort((a, b) {
      final ea = _events[a];
      final eb = _events[b];
      final byDate = _dateSortKey(ea.date).compareTo(_dateSortKey(eb.date));
      if (byDate != 0) return byDate;
      final byStart =
          _timeSortKey(ea.startTime).compareTo(_timeSortKey(eb.startTime));
      if (byStart != 0) return byStart;
      return a.compareTo(b);
    });
    return indices;
  }

  static int _dateSortKey(String raw) {
    final parts = raw.trim().split(RegExp(r'[/-]'));
    if (parts.length < 3) return 0;
    final a = int.tryParse(parts[0]) ?? 0;
    final b = int.tryParse(parts[1]) ?? 0;
    final c = int.tryParse(parts[2]) ?? 0;
    // Prefer M/D/Y (US festival CSVs); if first part looks like a year, use Y/M/D.
    if (a >= 1000) return a * 10000 + b * 100 + c;
    return c * 10000 + a * 100 + b;
  }

  static int _timeSortKey(String raw) {
    final parts = raw.trim().split(':');
    final h = parts.isNotEmpty ? (int.tryParse(parts[0].trim()) ?? 0) : 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return h * 60 + m;
  }

  @override
  void initState() {
    super.initState();
    widget.scheduleService.addSyncListener(_onSyncStatus);
    _load();
  }

  @override
  void dispose() {
    widget.scheduleService.removeSyncListener(_onSyncStatus);
    _notes.dispose();
    _descriptionText.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _onSyncStatus() {
    if (!mounted) return;
    unawaited(_refreshOutstanding());
  }

  Future<void> _refreshOutstanding() async {
    try {
      final next = await widget.scheduleService.outstandingEventKeys(
        widget.workspace,
      );
      if (!mounted) return;
      final previous = _outstandingKeys;
      final justSynced = previous.difference(next);
      setState(() {
        _outstandingKeys = next;
        if (justSynced.isNotEmpty &&
            widget.scheduleService.syncStatus.state ==
                ScheduleSyncState.synced) {
          _justSyncedKeys = justSynced;
        } else if (next.isEmpty &&
            widget.scheduleService.syncStatus.state ==
                ScheduleSyncState.synced) {
          // Keep brief "Synced" flash for rows that cleared.
          if (justSynced.isNotEmpty) {
            _justSyncedKeys = justSynced;
          }
        }
        if (next.isNotEmpty) {
          // Still outstanding — don't keep stale just-synced for those keys.
          _justSyncedKeys = _justSyncedKeys.difference(next);
        }
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  bool _isOutstanding(ScheduleEvent event) =>
      _outstandingKeys.contains(ScheduleService.eventKey(event));

  bool _wasJustSynced(ScheduleEvent event) =>
      _justSyncedKeys.contains(ScheduleService.eventKey(event));

  List<String> get _venues =>
      DropdownOptions.withEmpty(widget.workspace.venues);

  List<String> get _dates => DropdownOptions.withEmpty(widget.workspace.dates);

  List<String> get _days => DropdownOptions.withEmpty(widget.workspace.days);

  List<String> get _types => DropdownOptions.withEmpty(
        ScheduleValidation.withDefaultEventTypes(widget.workspace.eventTypes),
      );

  List<String> get _bandOptions => DropdownOptions.withEmpty(_bandNames);

  List<String> get _hourOptions =>
      DropdownOptions.withEmpty(ScheduleService.hours);

  List<String> get _minOptions => DropdownOptions.withEmpty(ScheduleService.mins);

  List<String> get _lengthOptions => DropdownOptions.withEmpty(
        ScheduleService.lengths.where((l) => l.trim().isNotEmpty),
      );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.scheduleService.load(widget.workspace);
      List<String> bands = [];
      try {
        final lineup = await widget.lineupService.load(widget.workspace);
        bands = lineup.map((b) => b.name).where((n) => n.isNotEmpty).toList();
      } catch (_) {}

      // Keep vocabulary fresh from schedule if Settings lists are empty.
      var ws = widget.workspace;
      if (ws.venues.isEmpty || ws.dates.isEmpty) {
        final hints = ScheduleService.hintsFromEvents(events);
        ws = ws.copyWith(
          venues: ws.venues.isEmpty ? hints.venues : ws.venues,
          dates: ws.dates.isEmpty ? hints.dates : ws.dates,
          days: ws.days.isEmpty ? hints.days : ws.days,
          eventTypes: ScheduleValidation.withDefaultEventTypes(
            ws.eventTypes.isEmpty ? hints.eventTypes : ws.eventTypes,
          ),
        );
        await widget.onWorkspaceChanged(ws);
      }

      setState(() {
        _events = events;
        _bandNames = bands;
        _band = DropdownOptions.empty;
        _type = DropdownOptions.empty;
        _venue = DropdownOptions.empty;
        _day = DropdownOptions.empty;
        _date = DropdownOptions.empty;
        _startHour = DropdownOptions.pick('12', _hourOptions);
        _startMin = DropdownOptions.pick('00', _minOptions);
        _length = DropdownOptions.pick('60', _lengthOptions);
        _applyLengthToEnd();
        _loading = false;
      });
      await _refreshOutstanding();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Convenience only: when length is a number, fill end from start + length.
  /// Manual end edits are fine; length is not the source of truth on save.
  void _applyLengthToEnd() {
    if (!_lengthActive) return;
    final sh = int.tryParse(_startHour.trim()) ?? 0;
    final sm = int.tryParse(_startMin.trim()) ?? 0;
    final len = int.tryParse(_length.trim()) ?? 0;
    final total = sh * 60 + sm + len;
    final eh = ((total ~/ 60) % 24).toString().padLeft(2, '0');
    final em = (total % 60).toString().padLeft(2, '0');
    _endHour = DropdownOptions.pick(eh, _hourOptions);
    // Prefer an exact min option; if missing (odd length), keep computed text
    // by picking closest existing or falling back to empty-first list.
    if (_minOptions.contains(em)) {
      _endMin = em;
    } else {
      _endMin = DropdownOptions.pick(em, _minOptions);
    }
  }

  void _onStartHourChanged(String? v) {
    setState(() {
      _startHour = v ?? DropdownOptions.empty;
      // Mirror web: if hour is set and min is blank, default min to 00.
      if (_startHour.trim().isNotEmpty && _startMin.trim().isEmpty) {
        _startMin = DropdownOptions.pick('00', _minOptions);
      }
      _applyLengthToEnd();
    });
  }

  void _onStartMinChanged(String? v) {
    setState(() {
      _startMin = v ?? DropdownOptions.empty;
      _applyLengthToEnd();
    });
  }

  void _onLengthChanged(String? v) {
    setState(() {
      _length = v ?? DropdownOptions.empty;
      _applyLengthToEnd();
    });
  }

  /// After a successful add/update: stay on entry, clear band/notes/description,
  /// keep type/venue/day/date/times for the next event on the same stage.
  void _prepareNextEntry({
    required ScheduleEvent saved,
    required int savedIndex,
    required bool wasUpdate,
    String extraMessage = '',
  }) {
    _committing = false;
    _editingIndex = null;
    _lastSavedIndex = savedIndex;
    _lastSavedEvent = saved;
    var msg = wasUpdate
        ? 'Updated ${saved.band} at ${saved.startTime}.'
        : 'Added ${saved.band} at ${saved.startTime}.';
    if (extraMessage.isNotEmpty) msg = '$msg $extraMessage';
    _message = msg;
    _error = null;
    _band = DropdownOptions.empty;
    _notes.clear();
    _descriptionText.clear();
    _imageUrl.clear();
    // Keep _type, _venue, _day, _date, start/end/length as-is.
  }

  Future<void> _saveEvent() async {
    if (!_canEdit) return;
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    final type = (_type ?? '').trim();
    final nonBand = ScheduleValidation.isNonBandEventType(type);

    late final String band;
    late final String notes;
    late final String imageUrl;
    var descriptionUrl = ' ';

    if (nonBand) {
      // Event title is entered in the Notes/Event title field → Band column.
      band = _notes.text.trim();
      notes = ' ';
      final rawImage = _imageUrl.text.trim();
      imageUrl = rawImage.isEmpty ? ' ' : normalizeDropboxUrl(rawImage);
    } else {
      band = (_band ?? '').trim();
      notes = _notes.text.trim().isEmpty ? ' ' : _notes.text.trim();
      imageUrl = ' ';
    }

    if (band.isEmpty) {
      setState(() => _error = nonBand
          ? 'Event title is required.'
          : 'Band name is required.');
      return;
    }
    if (_startHour.trim().isEmpty || _startMin.trim().isEmpty) {
      setState(() => _error = 'Start time is required.');
      return;
    }
    final start = '$_startHour:$_startMin';
    // End time is the real data point (length is only a convenience filler).
    final endHour = _endHour.trim().isEmpty ? ' ' : _endHour;
    final endMin = _endMin.trim().isEmpty ? ' ' : _endMin;
    final end = '$endHour:$endMin';

    final descriptionBody = _descriptionText.text.trim();

    setState(() {
      _committing = true;
      _error = null;
      _message = null;
    });

    try {
      if (nonBand && descriptionBody.isNotEmpty) {
        final canEditMap = widget.workspace.canEditDescriptions;
        if (canEditMap) {
          if (widget.workspace.descriptionMapUrl.trim().isEmpty) {
            throw StateError(
              'Description map URL is not configured — '
              'Load festival data in Settings, or clear the description text.',
            );
          }
          descriptionUrl =
              await widget.descriptionMapService.writeDescriptionAndUpsertMap(
            workspace: widget.workspace,
            labelName: band,
            text: descriptionBody,
          );
        } else {
          descriptionUrl =
              await widget.descriptionMapService.writeDescriptionFileForUser(
            labelName: band,
            text: descriptionBody,
            promptForFolder: () => showDropboxFolderPicker(
              context: context,
              dropboxApi: widget.dropboxApi,
              title: 'Where should descriptions be saved?',
            ),
          );
        }
      }

      final event = ScheduleEvent(
        band: band,
        location: (_venue ?? ' ').trim().isEmpty ? ' ' : (_venue ?? ' ').trim(),
        date: (_date ?? ' ').trim().isEmpty ? ' ' : (_date ?? ' ').trim(),
        day: (_day ?? ' ').trim().isEmpty ? ' ' : (_day ?? ' ').trim(),
        startTime: start,
        endTime: end,
        type: type.isEmpty ? ' ' : type,
        descriptionUrl: descriptionUrl.trim().isEmpty ? ' ' : descriptionUrl,
        notes: notes,
        imageUrl: imageUrl,
      );

      final editIdx = _editingIndex;
      final existing = <ScheduleEvent>[
        for (var i = 0; i < _events.length; i++)
          if (editIdx == null || i != editIdx) _events[i],
      ];
      final validationErrors = ScheduleValidation.validateEvent(
        event: event,
        existing: existing,
        verifyBypass: _verifyBypass,
      );
      if (validationErrors.isNotEmpty) {
        setState(() {
          _committing = false;
          _error = validationErrors.join('\n');
          _message = null;
        });
        return;
      }

      final updated = List<ScheduleEvent>.from(_events);
      final wasUpdate =
          editIdx != null && editIdx >= 0 && editIdx < updated.length;
      final savedIndex = wasUpdate ? editIdx : updated.length;

      // When editing a non-band event without new description text, keep
      // the existing description URL on the row.
      ScheduleEvent toSave = event;
      if (wasUpdate &&
          nonBand &&
          descriptionBody.isEmpty &&
          updated[editIdx].descriptionUrl.trim().isNotEmpty) {
        toSave = ScheduleEvent(
          band: event.band,
          location: event.location,
          date: event.date,
          day: event.day,
          startTime: event.startTime,
          endTime: event.endTime,
          type: event.type,
          descriptionUrl: updated[editIdx].descriptionUrl,
          notes: event.notes,
          imageUrl: event.imageUrl,
        );
      }

      if (wasUpdate) {
        updated[editIdx] = toSave;
      } else {
        updated.add(toSave);
      }
      await widget.scheduleService.save(widget.workspace, updated);
      final handoffLink = descriptionBody.isNotEmpty &&
              !widget.workspace.canEditDescriptions &&
              descriptionUrl.trim().isNotEmpty
          ? descriptionUrl.trim()
          : null;
      setState(() {
        _events = updated;
        _shareUrl = handoffLink;
        _prepareNextEntry(
          saved: toSave,
          savedIndex: savedIndex,
          wasUpdate: wasUpdate,
          extraMessage: descriptionBody.isEmpty
              ? ''
              : (widget.workspace.canEditDescriptions
                  ? 'Description saved and added to the map.'
                  : 'Description file saved — copy the link below for the description admin.'),
        );
      });
      await _refreshOutstanding();
    } catch (e) {
      setState(() {
        _committing = false;
        _error = e.toString();
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _band = DropdownOptions.empty;
      _notes.clear();
      _descriptionText.clear();
      _imageUrl.clear();
      _error = null;
      _message = null;
      // Keep type/venue/day/date/times so the next entry stays sticky.
    });
  }

  void _startEdit(int index) {
    if (!_canEdit) return;
    final e = _events[index];
    final startParts = e.startTime.split(':');
    final hour = startParts.isNotEmpty ? startParts[0].padLeft(2, '0') : '';
    final min = startParts.length > 1 ? startParts[1].padLeft(2, '0') : '';
    final endParts = e.endTime.split(':');
    final endHour = endParts.isNotEmpty ? endParts[0].padLeft(2, '0') : '';
    final endMin = endParts.length > 1 ? endParts[1].padLeft(2, '0') : '';
    final nonBand = ScheduleValidation.isNonBandEventType(e.type);

    // Ensure band appears in dropdown even if not in lineup.
    final bands = List<String>.from(_bandNames);
    if (!nonBand && e.band.isNotEmpty && !bands.contains(e.band)) {
      bands.add(e.band);
      bands.sort();
    }

    setState(() {
      _editingIndex = index;
      _bandNames = bands;
      _type = DropdownOptions.pick(e.type, _types);
      _venue = DropdownOptions.pick(e.location, _venues);
      _day = DropdownOptions.pick(e.day, _days);
      _date = DropdownOptions.pick(e.date, _dates);
      _startHour = DropdownOptions.pick(hour, _hourOptions);
      _startMin = DropdownOptions.pick(min, _minOptions);
      _endHour = DropdownOptions.pick(endHour, _hourOptions);
      _endMin = DropdownOptions.pick(endMin, _minOptions);
      // Like the web modify form: leave length blank so stored end time wins.
      _length = DropdownOptions.empty;
      if (nonBand) {
        _band = DropdownOptions.empty;
        _notes.text = e.band.trim();
        _imageUrl.text = e.imageUrl.trim() == ' ' ? '' : e.imageUrl.trim();
        _descriptionText.clear();
      } else {
        _band = DropdownOptions.pick(e.band, DropdownOptions.withEmpty(bands));
        _notes.text = e.notes.trim();
        _imageUrl.clear();
        _descriptionText.clear();
      }
      _error = null;
    });
    widget.onTabChanged(ScheduleTab.entry);
  }

  Future<void> _deleteEvent(int index) async {
    if (!_canEdit) return;
    final e = _events[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Remove event'),
        content: Text('Remove ${e.band} (${e.startTime}) from the schedule?'),
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
      _committing = true;
      _error = null;
    });
    try {
      final updated = List<ScheduleEvent>.from(_events)..removeAt(index);
      await widget.scheduleService.save(widget.workspace, updated);
      setState(() {
        _events = updated;
        _committing = false;
        _message = 'Removed “${e.band}” from Testing schedule.';
        if (_lastSavedIndex != null) {
          if (_lastSavedIndex == index) {
            _lastSavedIndex = null;
            _lastSavedEvent = null;
          } else if (_lastSavedIndex! > index) {
            _lastSavedIndex = _lastSavedIndex! - 1;
          }
        }
        if (_editingIndex != null) {
          if (_editingIndex == index) {
            _editingIndex = null;
            _band = DropdownOptions.empty;
            _notes.clear();
          } else if (_editingIndex! > index) {
            _editingIndex = _editingIndex! - 1;
          }
        }
      });
      await _refreshOutstanding();
    } catch (err) {
      setState(() {
        _committing = false;
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
    if (widget.tab == ScheduleTab.view) {
      return _buildView();
    }
    if (widget.tab == ScheduleTab.stats) {
      return _buildStats();
    }
    return _buildEntry();
  }

  Widget _syncStatusBar() {
    final sync = widget.scheduleService.syncStatus;
    if (!sync.shouldShowBanner) {
      return const SizedBox.shrink();
    }
    final isError = sync.state == ScheduleSyncState.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: StatusBanner(text: sync.label, isError: isError),
          ),
          if (isError || sync.state == ScheduleSyncState.pending) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _committing
                  ? null
                  : () async {
                      try {
                        await widget.scheduleService.flushSync(widget.workspace);
                      } catch (e) {
                        if (!mounted) return;
                        // Keep the soft sync banner; avoid a second raw exception dump.
                        setState(() {});
                      }
                    },
              child: Text(isError ? 'Retry sync' : 'Sync now'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _syncChipFor(ScheduleEvent event) {
    final outstanding = _isOutstanding(event);
    final justSynced = _wasJustSynced(event);
    final showSyncedColumn =
        _outstandingKeys.isNotEmpty || _justSyncedKeys.isNotEmpty;

    if (!showSyncedColumn) {
      return const Text(
        'Synced',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      );
    }

    if (outstanding) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF3D2E14),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE6A23C)),
        ),
        child: const Text(
          'Pending',
          style: TextStyle(
            color: Color(0xFFFFD280),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Text(
      justSynced ? 'Synced just now' : 'Synced',
      style: TextStyle(
        color: justSynced ? AppColors.successText : AppColors.muted,
        fontSize: 12,
        fontWeight: justSynced ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildView() {
    final order = _eventsDisplayOrder;
    final highlightSync =
        _outstandingKeys.isNotEmpty || _justSyncedKeys.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _syncStatusBar(),
        if (widget.workspace.scheduleUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Working copy synced to: ${widget.workspace.scheduleUrl}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (_message != null) StatusBanner(text: _message!),
        if (_error != null) StatusBanner(text: _error!, isError: true),
        if (!_canEdit)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: StatusBanner(
              text: 'View only — no Dropbox write access to the schedule. '
                  'Edit and Delete are disabled.',
            ),
          ),
        if (_committing) const LinearProgressIndicator(color: AppColors.accent),
        Expanded(
          child: PortalPanel(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: _events.isEmpty
                ? const Text(
                    'No schedule events yet.',
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
                              dataRowMaxHeight: 52,
                              dividerThickness: 1,
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: AppColors.panelBorder.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                                verticalInside: BorderSide(
                                  color: AppColors.panelBorder.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFF222222),
                              ),
                              columns: const [
                                DataColumn(label: Text('Sync')),
                                DataColumn(label: Text('Band')),
                                DataColumn(label: Text('Location')),
                                DataColumn(label: Text('Date')),
                                DataColumn(label: Text('Day')),
                                DataColumn(label: Text('Start')),
                                DataColumn(label: Text('End')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: [
                                for (final i in order)
                                  DataRow(
                                    color: WidgetStateProperty.resolveWith((_) {
                                      if (!highlightSync) return null;
                                      if (_isOutstanding(_events[i])) {
                                        return const Color(0xFF33280F);
                                      }
                                      if (_wasJustSynced(_events[i])) {
                                        return const Color(0xFF1A2E1A);
                                      }
                                      return null;
                                    }),
                                    cells: [
                                      DataCell(_syncChipFor(_events[i])),
                                      DataCell(Text(_events[i].band)),
                                      DataCell(Text(_events[i].location)),
                                      DataCell(Text(_events[i].date)),
                                      DataCell(Text(_events[i].day)),
                                      DataCell(Text(_events[i].startTime)),
                                      DataCell(Text(_events[i].endTime)),
                                      DataCell(Text(_events[i].type)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              onPressed: !_canEdit || _committing
                                                  ? null
                                                  : () => _startEdit(i),
                                              child: const Text('Edit'),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              onPressed: !_canEdit || _committing
                                                  ? null
                                                  : () => _deleteEvent(i),
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
                        ),
                      );
                    },
                  ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('${_events.length} event(s) — Refresh'),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final typeCols = ScheduleValidation.statsTypeColumns(
      configuredTypes: widget.workspace.eventTypes,
      events: _events,
    );
    final bands = ScheduleValidation.statsBandRows(
      lineupNames: _bandNames,
      events: _events,
    );
    final stats = ScheduleValidation.buildStats(_events);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) StatusBanner(text: _error!, isError: true),
        Text(
          '${_events.length} total events — counts by band and event type '
          '(use this to confirm each band has the expected shows / meet & greets).',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PortalPanel(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: bands.isEmpty
                ? const Text(
                    'No artists or schedule events to summarize yet.',
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
                              columnSpacing: 18,
                              horizontalMargin: 8,
                              headingRowHeight: 40,
                              dataRowMinHeight: 36,
                              dataRowMaxHeight: 44,
                              dividerThickness: 1,
                              border: TableBorder(
                                horizontalInside: BorderSide(
                                  color: AppColors.panelBorder.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                                verticalInside: BorderSide(
                                  color: AppColors.panelBorder.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFF222222),
                              ),
                              columns: [
                                const DataColumn(label: Text('Band')),
                                for (final t in typeCols)
                                  DataColumn(label: Text(t)),
                              ],
                              rows: [
                                for (final band in bands)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(band)),
                                      for (final t in typeCols)
                                        DataCell(
                                          Text(
                                            '${stats[band]?[t] ?? 0}',
                                            style: TextStyle(
                                              color: (stats[band]?[t] ?? 0) == 0
                                                  ? AppColors.muted
                                                  : AppColors.heading,
                                              fontWeight:
                                                  (stats[band]?[t] ?? 0) > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                            ),
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
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('${_events.length} event(s) — Refresh'),
          ),
        ),
      ],
    );
  }

  Widget _buildEntry() {
    return SingleChildScrollView(
      child: PortalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _syncStatusBar(),
            if (_error != null) StatusBanner(text: _error!, isError: true),
            if (_message != null) StatusBanner(text: _message!),
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
                          const SnackBar(
                            content: Text('URL copied to clipboard'),
                          ),
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
                text: 'Connect Dropbox in Settings to save the schedule.',
                isError: true,
              ),
            if (!_isNonBand)
              FormRow(
                label: 'Band Name',
                requiredField: true,
                child: PortalStringDropdown(
                  value: _band,
                  items: _bandOptions,
                  onChanged: (v) => setState(() => _band = v),
                  emptyLabel: '—',
                  labelBuilder: (b) => b.isEmpty
                      ? (_bandNames.isEmpty ? '— load lineup first —' : '—')
                      : b,
                ),
              ),
            FormRow(
              label: 'Event Type',
              requiredField: true,
              child: PortalStringDropdown(
                value: _type,
                items: _types,
                onChanged: (v) => setState(() {
                  final next = v ?? DropdownOptions.empty;
                  final wasNonBand = ScheduleValidation.isNonBandEventType(
                    (_type ?? '').trim(),
                  );
                  final nowNonBand =
                      ScheduleValidation.isNonBandEventType(next.trim());
                  _type = next;
                  if (wasNonBand && !nowNonBand) {
                    _descriptionText.clear();
                    _imageUrl.clear();
                    _notes.clear();
                  } else if (!wasNonBand && nowNonBand) {
                    _band = DropdownOptions.empty;
                    _notes.clear();
                  }
                }),
              ),
            ),
            if (_isNonBand) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _nonBandHelp((_type ?? '').trim()),
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            ],
            FormRow(
              label: 'Venue',
              requiredField: true,
              child: PortalStringDropdown(
                value: _venue,
                items: _venues,
                onChanged: (v) => setState(() => _venue = v),
              ),
            ),
            FormRow(
              label: 'Day',
              requiredField: true,
              child: PortalStringDropdown(
                value: _day,
                items: _days,
                onChanged: (v) => setState(() => _day = v),
              ),
            ),
            FormRow(
              label: 'Date',
              requiredField: true,
              child: PortalStringDropdown(
                value: _date,
                items: _dates,
                onChanged: (v) => setState(() => _date = v),
              ),
            ),
            FormRow(
              label: 'Start Time',
              requiredField: true,
              child: Row(
                children: [
                  Expanded(
                    child: PortalStringDropdown(
                      value: _startHour,
                      items: _hourOptions,
                      onChanged: _onStartHourChanged,
                      decoration: const InputDecoration(labelText: 'Hour'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PortalStringDropdown(
                      value: _startMin,
                      items: _minOptions,
                      onChanged: _onStartMinChanged,
                      decoration: const InputDecoration(labelText: 'Min'),
                    ),
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Event Length',
              child: PortalStringDropdown(
                value: _length,
                items: _lengthOptions,
                onChanged: _onLengthChanged,
                labelBuilder: (L) =>
                    L.trim().isEmpty ? '— (manual end time)' : '$L min',
              ),
            ),
            FormRow(
              label: 'End Time',
              child: Row(
                children: [
                  Expanded(
                    child: PortalStringDropdown(
                      value: _endHour,
                      items: _hourOptions,
                      onChanged: (v) => setState(
                        () => _endHour = v ?? DropdownOptions.empty,
                      ),
                      decoration: const InputDecoration(labelText: 'Hour'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PortalStringDropdown(
                      value: _endMin,
                      items: _minOptions,
                      onChanged: (v) => setState(
                        () => _endMin = v ?? DropdownOptions.empty,
                      ),
                      decoration: const InputDecoration(labelText: 'Min'),
                    ),
                  ),
                ],
              ),
            ),
            FormRow(
              label: _isNonBand ? 'Event title' : 'Notes',
              requiredField: _isNonBand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _notes,
                    maxLines: _isNonBand ? 1 : 2,
                    decoration: InputDecoration(
                      hintText: _isNonBand
                          ? 'e.g. Best Tattoo Contest'
                          : null,
                    ),
                  ),
                  if (_isNonBand)
                    const HintText(
                      'This becomes the schedule row name (Band column).',
                    ),
                ],
              ),
            ),
            if (_isNonBand) ...[
              FormRow(
                label: 'Description',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _descriptionText,
                      maxLines: 6,
                      minLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Plain-text description for the app…',
                      ),
                    ),
                    HintText(
                      widget.workspace.canEditDescriptions
                          ? 'When you save, the note is written to Dropbox and '
                              'added to the description map automatically.'
                          : 'When you save, the note is written to your Dropbox '
                              'folder and you get a link to share with the '
                              'description admin. The URL is also stored on '
                              'this schedule row.',
                    ),
                    if (_isEditing)
                      const HintText(
                        'Leave blank while editing to keep the existing map URL.',
                      ),
                  ],
                ),
              ),
              FormRow(
                label: 'Image URL',
                child: TextField(
                  controller: _imageUrl,
                  decoration: const InputDecoration(
                    hintText: 'https://www.dropbox.com/…?raw=1',
                  ),
                ),
              ),
            ],
            FormRow(
              label: 'Verify bypass',
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _verifyBypass,
                onChanged: (v) => setState(() => _verifyBypass = v ?? false),
                title: const Text(
                  'Skip validation',
                  style: TextStyle(color: AppColors.heading),
                ),
                subtitle: const Text(
                  'Rules catch double-bookings and odd show lengths — '
                  'bypass when you intentionally need an exception.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: !_canEdit || _committing ? null : _saveEvent,
                  child: Text(
                    _committing
                        ? 'Saving…'
                        : (_isEditing ? 'Save changes' : 'Add event'),
                  ),
                ),
                OutlinedButton(
                  onPressed: _isEditing
                      ? _cancelEdit
                      : () => widget.onTabChanged(ScheduleTab.view),
                  child: Text(_isEditing ? 'Cancel edit' : 'View schedule'),
                ),
              ],
            ),
            if (_lastSavedEvent != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F3D1F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF33CC33)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last saved entry',
                      style: TextStyle(
                        color: Color(0xFF99FF99),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastSavedEvent!.band,
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_lastSavedEvent!.location}  ·  ${_lastSavedEvent!.day}  ·  ${_lastSavedEvent!.date}\n'
                      '${_lastSavedEvent!.startTime} – ${_lastSavedEvent!.endTime}'
                      '${_lastSavedEvent!.type.trim().isEmpty ? '' : '  ·  ${_lastSavedEvent!.type}'}',
                      style: const TextStyle(color: AppColors.label),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: !_canEdit ||
                                  _committing ||
                                  _lastSavedIndex == null
                              ? null
                              : () => _startEdit(_lastSavedIndex!),
                          child: const Text('Edit last entry'),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _lastSavedEvent = null;
                            _lastSavedIndex = null;
                            _message = null;
                          }),
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
