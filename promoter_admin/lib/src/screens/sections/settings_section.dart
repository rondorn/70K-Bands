import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/screens/create_festival_dialog.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';
import 'package:promoter_admin/src/services/festival_year_service.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/promote_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_validation.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/portal_dropdown.dart';
import 'package:promoter_admin/src/widgets/recent_alerts_list.dart';

class SettingsSection extends StatefulWidget {
  const SettingsSection({
    super.key,
    required this.workspace,
    required this.festivalChoices,
    required this.activeFestivalId,
    required this.pointerService,
    required this.dropboxApi,
    required this.scheduleService,
    required this.dropboxConnected,
    required this.dropboxLabel,
    required this.dropboxConnecting,
    required this.showPromote,
    required this.onShowPromote,
    required this.onWorkspaceChanged,
    required this.onSwitchFestival,
    required this.onAddFestival,
    required this.onDeleteFestival,
    required this.onConnectDropbox,
    required this.onDisconnectDropbox,
  });

  final FestivalWorkspace workspace;
  final List<({String id, String name})> festivalChoices;
  final String activeFestivalId;
  final PointerService pointerService;
  final DropboxApi dropboxApi;
  final ScheduleService scheduleService;
  final bool dropboxConnected;
  final String dropboxLabel;
  final bool dropboxConnecting;
  final bool showPromote;
  final ValueChanged<bool> onShowPromote;
  final Future<void> Function(FestivalWorkspace) onWorkspaceChanged;
  final Future<void> Function(String festivalId) onSwitchFestival;
  final Future<void> Function(FestivalWorkspace workspace) onAddFestival;
  final Future<void> Function(String festivalId) onDeleteFestival;
  final Future<void> Function() onConnectDropbox;
  final Future<void> Function() onDisconnectDropbox;

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  late final TextEditingController _name;
  late final TextEditingController _testing;
  late final TextEditingController _production;
  late final TextEditingController _alertFolder;
  late final TextEditingController _venues;
  late final TextEditingController _dates;
  late final TextEditingController _days;
  late final TextEditingController _eventTypes;
  late bool _canEditBands;
  late bool _canEditSchedule;
  late bool _canEditDescriptions;
  late bool _canEditPointers;
  late bool _canEditAlerts;
  late bool _useCityStateField;
  String? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.workspace.festivalName);
    _testing = TextEditingController(text: widget.workspace.testingPointerUrl);
    _production =
        TextEditingController(text: widget.workspace.productionPointerUrl);
    _alertFolder =
        TextEditingController(text: widget.workspace.alertFolderUrl);
    _venues = TextEditingController(text: widget.workspace.venues.join('\n'));
    _dates = TextEditingController(text: widget.workspace.dates.join('\n'));
    _days = TextEditingController(text: widget.workspace.days.join('\n'));
    _eventTypes = TextEditingController(
      text: ScheduleValidation.withDefaultEventTypes(widget.workspace.eventTypes)
          .join('\n'),
    );
    _canEditBands = widget.workspace.canEditBands;
    _canEditSchedule = widget.workspace.canEditSchedule;
    _canEditDescriptions = widget.workspace.canEditDescriptions;
    _canEditPointers = widget.workspace.canEditPointers;
    _canEditAlerts = widget.workspace.canEditAlerts;
    _useCityStateField = widget.workspace.useCityStateField;
  }

  @override
  void didUpdateWidget(covariant SettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace != widget.workspace) {
      _syncControllersFromWorkspace();
    }
  }

  void _syncControllersFromWorkspace() {
    final w = widget.workspace;
    if (_name.text != w.festivalName) _name.text = w.festivalName;
    if (_testing.text != w.testingPointerUrl) {
      _testing.text = w.testingPointerUrl;
    }
    if (_production.text != w.productionPointerUrl) {
      _production.text = w.productionPointerUrl;
    }
    if (_alertFolder.text != w.alertFolderUrl) {
      _alertFolder.text = w.alertFolderUrl;
    }
    final v = w.venues.join('\n');
    if (_venues.text != v) _venues.text = v;
    final d = w.dates.join('\n');
    if (_dates.text != d) _dates.text = d;
    final days = w.days.join('\n');
    if (_days.text != days) _days.text = days;
    final t = ScheduleValidation.withDefaultEventTypes(w.eventTypes).join('\n');
    if (_eventTypes.text != t) _eventTypes.text = t;
    _canEditBands = w.canEditBands;
    _canEditSchedule = w.canEditSchedule;
    _canEditDescriptions = w.canEditDescriptions;
    _canEditPointers = w.canEditPointers;
    _canEditAlerts = w.canEditAlerts;
    _useCityStateField = w.useCityStateField;
  }

  @override
  void dispose() {
    _name.dispose();
    _testing.dispose();
    _production.dispose();
    _alertFolder.dispose();
    _venues.dispose();
    _dates.dispose();
    _days.dispose();
    _eventTypes.dispose();
    super.dispose();
  }

  List<String> _lines(String text) => text
      .split('\n')
      .map((s) => s.trimRight())
      .where((s) => s.isNotEmpty || s == ' ')
      .toList();

  FestivalWorkspace _draft() {
    return widget.workspace.copyWith(
      id: widget.workspace.id.isEmpty
          ? widget.activeFestivalId
          : widget.workspace.id,
      festivalName: _name.text.trim(),
      testingPointerUrl: _testing.text.trim(),
      productionPointerUrl: _production.text.trim(),
      alertFolderUrl: _alertFolder.text.trim(),
      venues: _lines(_venues.text),
      dates: _lines(_dates.text),
      days: _lines(_days.text),
      eventTypes: ScheduleValidation.withDefaultEventTypes(_lines(_eventTypes.text)),
      canEditBands: _canEditBands,
      canEditSchedule: _canEditSchedule,
      canEditDescriptions: _canEditDescriptions,
      canEditPointers: _canEditPointers,
      canEditAlerts: _canEditAlerts,
      useCityStateField: _useCityStateField,
    );
  }

  Future<FestivalWorkspace> _probeAccess(FestivalWorkspace workspace) async {
    if (!widget.dropboxConnected) return workspace;
    final hasUrls = workspace.bandListUrl.trim().isNotEmpty ||
        workspace.scheduleUrl.trim().isNotEmpty ||
        workspace.descriptionMapUrl.trim().isNotEmpty ||
        workspace.testingPointerUrl.trim().isNotEmpty ||
        workspace.productionPointerUrl.trim().isNotEmpty ||
        workspace.alertFolderUrl.trim().isNotEmpty;
    if (!hasUrls) return workspace;
    return widget.dropboxApi.probeWorkspaceWriteAccess(workspace);
  }

  String _accessSummary(FestivalWorkspace w) {
    final parts = <String>[];
    parts.add(w.canEditBands ? 'Artists ✓' : 'Artists ✗');
    parts.add(w.canEditSchedule ? 'Schedule ✓' : 'Schedule ✗');
    parts.add(w.canEditDescriptions ? 'Descriptions ✓' : 'Descriptions ✗');
    parts.add(w.canEditPointers ? 'Links ✓' : 'Links ✗');
    if (w.alertFolderUrl.trim().isNotEmpty) {
      parts.add(w.canEditAlerts ? 'Alerts ✓' : 'Alerts ✗');
    }
    return parts.join(' · ');
  }

  /// When an alert folder URL is set, require Dropbox write access before saving.
  Future<FestivalWorkspace> _verifyAlertFolderAccess(
    FestivalWorkspace draft,
  ) async {
    final folder = draft.alertFolderUrl.trim();
    if (folder.isEmpty) {
      return draft.copyWith(canEditAlerts: false);
    }
    if (!widget.dropboxConnected) {
      throw StateError(
        'Connect Dropbox to verify write access on the alert folder before saving.',
      );
    }
    final canWrite = await widget.dropboxApi.canWriteFolderShareUrl(folder);
    if (!canWrite) {
      throw StateError(
        'No Dropbox write access to the alert folder. '
        'Ask the folder owner to grant edit access, then try Save again.',
      );
    }
    return draft.copyWith(canEditAlerts: true);
  }

  Future<void> _switchFestival(String? festivalId) async {
    if (festivalId == null || festivalId == widget.activeFestivalId) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Switching festival…';
    });
    try {
      // Save current form before switching so edits aren't lost.
      await widget.onWorkspaceChanged(_draft());
      await widget.onSwitchFestival(festivalId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Switched festival.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
        _status = null;
      });
    }
  }

  Future<void> _addFestival() async {
    final result = await showCreateFestivalDialog(
      context: context,
      dropboxConnected: widget.dropboxConnected,
    );
    if (result == null || !mounted) return;

    if (result.createPointerFiles && !widget.dropboxConnected) {
      setState(() {
        _error =
            'Connect Dropbox before creating new festival links and data files.';
        _status = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = result.createPointerFiles
          ? 'Creating festival on Dropbox…'
          : 'Loading festival from links…';
    });
    try {
      await widget.onWorkspaceChanged(_draft());
      late final FestivalWorkspace created;
      if (result.createPointerFiles) {
        created = await FestivalCreateService(widget.dropboxApi).createFestival(
          festivalName: result.name,
          eventYear: result.eventYear,
          dropboxFolder: result.folder,
          filePrefix: result.filePrefix,
        );
      } else {
        var draft = FestivalWorkspace(
          festivalName: result.name,
          testingPointerUrl: result.testingPointerUrl,
          productionPointerUrl: result.productionPointerUrl,
        );
        if (draft.productionPointerUrl.trim().isNotEmpty) {
          draft = await widget.pointerService.applyPointers(draft);
        } else {
          draft = await widget.pointerService.applyTestingPointer(draft);
        }
        if (widget.dropboxConnected) {
          draft = await widget.dropboxApi.probeWorkspaceWriteAccess(draft);
        }
        created = draft;
      }
      await widget.onAddFestival(created);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = result.createPointerFiles
            ? 'Created “${created.festivalName}” in ${result.folder}. '
                'Testing and Production links are ready — send them to your '
                'app developer if needed.'
            : 'Added “${created.festivalName}” from existing links '
                '(year ${created.eventYear}).';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
        _status = null;
      });
    }
  }

  Future<void> _deleteActiveFestival() async {
    if (widget.festivalChoices.length <= 1) {
      setState(() => _error = 'Cannot delete the only festival configuration.');
      return;
    }
    final name = widget.workspace.displayName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Delete festival config'),
        content: Text(
          'Remove “$name” from this app? '
          'Dropbox data files are not deleted — only this local configuration.',
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDeleteFestival(widget.activeFestivalId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Deleted festival config “$name”.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadFromPointer() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Loading festival data…';
    });
    try {
      var updated = await widget.pointerService.applyPointers(
        _draft(),
        forceRefresh: true,
      );
      if (widget.dropboxConnected) {
        setState(() => _status = 'Checking Dropbox write access…');
        updated = await _probeAccess(updated);
      }
      await widget.onWorkspaceChanged(updated);
      if (!mounted) return;
      setState(() {
        _canEditBands = updated.canEditBands;
        _canEditSchedule = updated.canEditSchedule;
        _canEditDescriptions = updated.canEditDescriptions;
        _canEditPointers = updated.canEditPointers;
        _canEditAlerts = updated.canEditAlerts;
        _status =
            'Loaded testing data files + production vocabulary '
            '(year ${updated.eventYear}). '
            '${updated.venues.where((v) => v.trim().isNotEmpty).length} venues, '
            '${updated.dates.where((d) => d.trim().isNotEmpty).length} dates, '
            '${updated.days.where((d) => d.trim().isNotEmpty).length} days, '
            '${updated.eventTypes.length} event types. '
            '${widget.dropboxConnected ? 'Access: ${_accessSummary(updated)}.' : 'Connect Dropbox to detect write access.'}';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _status = null;
        _busy = false;
      });
    }
  }

  Future<void> _refreshAccess() async {
    if (!widget.dropboxConnected) {
      setState(() {
        _error = 'Connect Dropbox first to detect write access.';
        _status = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Checking Dropbox write access…';
    });
    try {
      final updated = await _probeAccess(_draft());
      await widget.onWorkspaceChanged(updated);
      if (!mounted) return;
      setState(() {
        _canEditBands = updated.canEditBands;
        _canEditSchedule = updated.canEditSchedule;
        _canEditDescriptions = updated.canEditDescriptions;
        _canEditPointers = updated.canEditPointers;
        _canEditAlerts = updated.canEditAlerts;
        _status = 'Write access: ${_accessSummary(updated)}. '
            'Admin sections without access are hidden.';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _status = null;
        _busy = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var draft = _draft();
      if (draft.testingPointerUrl.isNotEmpty && draft.bandListUrl.isEmpty) {
        if (draft.productionPointerUrl.isNotEmpty) {
          draft = await widget.pointerService.applyPointers(draft);
        } else {
          draft = await widget.pointerService.applyTestingPointer(draft);
        }
        if (widget.dropboxConnected) {
          draft = await _probeAccess(draft);
        }
      }
      draft = await _verifyAlertFolderAccess(draft);
      await widget.onWorkspaceChanged(draft);
      if (!mounted) return;
      setState(() {
        _canEditBands = draft.canEditBands;
        _canEditSchedule = draft.canEditSchedule;
        _canEditDescriptions = draft.canEditDescriptions;
        _canEditPointers = draft.canEditPointers;
        _canEditAlerts = draft.canEditAlerts;
        _status = draft.alertFolderUrl.trim().isEmpty
            ? 'Configuration saved.'
            : 'Configuration saved. Alert folder write access verified.';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _addNewYear() async {
    if (!widget.dropboxConnected || !_canEditPointers) return;

    final yearService = FestivalYearService(widget.dropboxApi);
    String? inferredFolder;
    try {
      inferredFolder = await yearService.inferFolderFromWorkspace(_draft());
    } catch (_) {
      inferredFolder = null;
    }

    if (!mounted) return;
    final draft = _draft();
    final currentYear = draft.eventYear.trim().isNotEmpty
        ? draft.eventYear.trim()
        : DateTime.now().year.toString();
    final result = await showDialog<_AddNewYearResult>(
      context: context,
      builder: (context) => _AddNewYearDialog(
        currentYear: currentYear,
        festivalName: draft.festivalName,
        initialFolder: inferredFolder ??
            FestivalCreateService.defaultFolderForName(draft.festivalName),
        initialPrefix: FestivalCreateService.defaultFilePrefix(draft.festivalName),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _status = 'Adding year ${result.newYear}…';
    });
    try {
      await widget.onWorkspaceChanged(draft);
      var updated = await yearService.rollNewYear(
        workspace: draft,
        newYear: result.newYear,
        dropboxFolder: result.folder,
        filePrefix: result.filePrefix,
      );
      await widget.scheduleService.staging.clearForFestival(updated);
      if (updated.productionPointerUrl.trim().isNotEmpty) {
        try {
          updated = await widget.pointerService.applyPointers(updated);
        } catch (_) {
          // Derived URLs already set from roll; vocabulary load is best-effort.
        }
      }
      if (widget.dropboxConnected) {
        updated = await _probeAccess(updated);
      }
      await widget.onWorkspaceChanged(updated);
      if (!mounted) return;
      setState(() {
        _canEditBands = updated.canEditBands;
        _canEditSchedule = updated.canEditSchedule;
        _canEditDescriptions = updated.canEditDescriptions;
        _canEditPointers = updated.canEditPointers;
        _canEditAlerts = updated.canEditAlerts;
        _busy = false;
        _status =
            'Rolled Testing to ${updated.eventYear} '
            '(archived $currentYear on the Testing link). '
            'Production was not changed — Publish to Production when ready.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
        _status = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showPromote) {
      return _PromotePanel(
        workspace: widget.workspace,
        dropboxApi: widget.dropboxApi,
        pointerService: widget.pointerService,
        scheduleService: widget.scheduleService,
        dropboxConnected: widget.dropboxConnected,
        onConnectDropbox: widget.onConnectDropbox,
        onBack: () => widget.onShowPromote(false),
      );
    }

    return SingleChildScrollView(
      child: PortalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status != null) StatusBanner(text: _status!),
            if (_error != null) StatusBanner(text: _error!, isError: true),
            const Text(
              'All files live on Dropbox. Edit against Testing '
              '(Advanced → Testing in the fan app). '
              'Publish to Production updates what most attendees see. '
              'Your app developer may ask you to copy the Testing and Production links below.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FormRow(
              label: 'Festival',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PortalStringDropdown(
                    value: widget.festivalChoices
                            .any((c) => c.id == widget.activeFestivalId)
                        ? widget.activeFestivalId
                        : (widget.festivalChoices.isNotEmpty
                            ? widget.festivalChoices.first.id
                            : null),
                    items: [
                      for (final c in widget.festivalChoices) c.id,
                    ],
                    enabled: !_busy,
                    onChanged: _busy ? null : _switchFestival,
                    labelBuilder: (id) {
                      for (final c in widget.festivalChoices) {
                        if (c.id == id) return c.name;
                      }
                      return id;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Choose festival configuration',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _addFestival,
                        child: const Text('Add New Festival'),
                      ),
                      OutlinedButton(
                        onPressed: _busy || widget.festivalChoices.length <= 1
                            ? null
                            : _deleteActiveFestival,
                        child: const Text('Delete this config'),
                      ),
                    ],
                  ),
                  const HintText(
                    'Each festival has its own Testing/Production links and vocabulary. '
                    'Add New Festival uses existing links by default, or can '
                    'create new Dropbox files. Switching saves the current form first.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Festival name',
              child: TextField(controller: _name),
            ),
            FormRow(
              label: 'Dropbox connection',
              requiredField: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.dropboxConnected
                        ? 'Connected${widget.dropboxLabel.isEmpty ? '' : ': ${widget.dropboxLabel}'}'
                        : 'Not connected — required to save lineup, schedule, and descriptions.',
                    style: const TextStyle(color: AppColors.heading),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (widget.dropboxConnected)
                        OutlinedButton(
                          onPressed: widget.onDisconnectDropbox,
                          child: const Text('Disconnect'),
                        )
                      else
                        FilledButton(
                          onPressed: widget.dropboxConnecting
                              ? null
                              : widget.onConnectDropbox,
                          child: Text(
                            widget.dropboxConnecting
                                ? 'Connecting…'
                                : 'Connect Dropbox',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Testing link',
              requiredField: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _testing,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'https://www.dropbox.com/.../testingPointer.txt?raw=1',
                    ),
                  ),
                  const HintText(
                    'Dropbox pointer file for Testing. From your app developer, '
                    'or create one and send them the link. Used for artists / schedule / descriptions.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Production link',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _production, maxLines: 2),
                  const HintText(
                    'Dropbox pointer file for Production (what most attendees see). '
                    'Also used for venues / dates / days / event types on Load. '
                    'Your app developer may ask for this link.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Alert folder',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _alertFolder,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'https://www.dropbox.com/scl/fo/…/alerts?rlkey=…&dl=0',
                    ),
                  ),
                  const HintText(
                    'Optional Dropbox folder for band-add announcement files '
                    '(paste a folder share link). Save requires Dropbox write access '
                    'when set. Publish to Production queues bandAnnouncements-….pending '
                    'for newly added bands only.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Data files',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadonlyLine('Artists', widget.workspace.bandListUrl),
                  _ReadonlyLine('Schedule', widget.workspace.scheduleUrl),
                  _ReadonlyLine('Description map', widget.workspace.descriptionMapUrl),
                  if (widget.workspace.eventYear.isNotEmpty)
                    _ReadonlyLine('Event year', widget.workspace.eventYear),
                  if (widget.dropboxConnected && _canEditPointers) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy ? null : _addNewYear,
                      child: const Text('Add new year…'),
                    ),
                    const HintText(
                      'Archives Current on the Testing link only and creates '
                      'empty artists / schedule / map files. Production is unchanged '
                      'until you Publish to Production.',
                    ),
                  ],
                ],
              ),
            ),
            FormRow(
              label: 'File access',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Artists'),
                    subtitle: Text(
                      widget.workspace.bandListUrl.trim().isEmpty
                          ? 'No artists URL yet'
                          : (_canEditBands
                              ? 'Write access — Add / Edit / Delete enabled'
                              : 'No write access — view only (Add / Edit / Delete disabled)'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    value: _canEditBands,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _canEditBands = v ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Schedule'),
                    subtitle: Text(
                      widget.workspace.scheduleUrl.trim().isEmpty
                          ? 'No schedule URL yet'
                          : (_canEditSchedule
                              ? 'Write access — Add / Edit / Delete enabled'
                              : 'No write access — view only (Add / Edit / Delete disabled)'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    value: _canEditSchedule,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _canEditSchedule = v ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Descriptions'),
                    subtitle: Text(
                      widget.workspace.descriptionMapUrl.trim().isEmpty
                          ? 'No description map URL yet'
                          : (_canEditDescriptions
                              ? 'Write access — Descriptions section shown'
                              : 'No write access — Descriptions section hidden'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    value: _canEditDescriptions,
                    onChanged: _busy
                        ? null
                        : (v) =>
                            setState(() => _canEditDescriptions = v ?? false),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      widget.workspace.testingPointerUrl.trim().isEmpty
                          ? 'Links: no Testing link yet'
                          : (_canEditPointers
                              ? 'Testing link: write access — Add new year available'
                              : 'Testing link: no write access — Add new year hidden'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                  const HintText(
                    'Detected from Dropbox when you Load festival data or Refresh. '
                    'Uncheck to hide a section; check to show it even if detection is wrong.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _refreshAccess,
                    child: const Text('Refresh file access'),
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Lineup options',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Use city/state fields for artists'),
                    subtitle: const Text(
                      'When enabled, artist entry shows city and state, and Discover '
                      'can populate them from Metal Archives or MusicBrainz. '
                      'Full US state names are stored as two-letter codes.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    value: _useCityStateField,
                    onChanged: _busy
                        ? null
                        : (v) =>
                            setState(() => _useCityStateField = v ?? false),
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Venues',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _venues, maxLines: 5),
                  const HintText(
                    'One per line. Loaded from the Production schedule.',
                  ),
                ],
              ),
            ),
            FormRow(
              label: 'Dates',
              child: TextField(controller: _dates, maxLines: 4),
            ),
            FormRow(
              label: 'Days',
              child: TextField(controller: _days, maxLines: 4),
            ),
            FormRow(
              label: 'Event types',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _eventTypes, maxLines: 4),
                  const HintText(
                    'Always includes Show, Clinic, Meet and Greet, Special Event, '
                    'and Unofficial Event. Add festival-specific types on extra lines.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _loadFromPointer,
                  child: Text(_busy ? 'Working…' : 'Load festival data'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('Save configuration'),
                ),
                if (_canEditBands ||
                    _canEditSchedule ||
                    _canEditDescriptions)
                  OutlinedButton(
                    onPressed: () => widget.onShowPromote(true),
                    child: const Text('Publish to Production…'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadonlyLine extends StatelessWidget {
  const _ReadonlyLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText(
        '$label: ${value.isEmpty ? '(not set)' : value}',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}

class _PromotePanel extends StatefulWidget {
  const _PromotePanel({
    required this.workspace,
    required this.dropboxApi,
    required this.pointerService,
    required this.scheduleService,
    required this.dropboxConnected,
    required this.onConnectDropbox,
    required this.onBack,
  });

  final FestivalWorkspace workspace;
  final DropboxApi dropboxApi;
  final PointerService pointerService;
  final ScheduleService scheduleService;
  final bool dropboxConnected;
  final Future<void> Function() onConnectDropbox;
  final VoidCallback onBack;

  @override
  State<_PromotePanel> createState() => _PromotePanelState();
}

class _PromotePanelState extends State<_PromotePanel> {
  late final PromoteService _promote = PromoteService(
    pointerService: widget.pointerService,
    dropboxApi: widget.dropboxApi,
  );

  PromoteDiff? _diff;
  String? _error;
  String? _status;
  bool _loadingPreview = true;
  bool _promoting = false;
  int _alertsRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant _PromotePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.testingPointerUrl !=
            widget.workspace.testingPointerUrl ||
        oldWidget.workspace.productionPointerUrl !=
            widget.workspace.productionPointerUrl) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview({
    String? keepStatus,
    bool forceRefresh = false,
  }) async {
    setState(() {
      _loadingPreview = true;
      _error = null;
      _status = keepStatus;
      _diff = null;
    });
    try {
      if (widget.workspace.canEditSchedule &&
          widget.workspace.scheduleUrl.trim().isNotEmpty) {
        if (keepStatus == null) {
          setState(() => _status = 'Flushing local schedule to Dropbox…');
        }
        await widget.scheduleService.flushSync(widget.workspace);
      }
      final diff = await _promote.preview(
        widget.workspace,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _diff = diff;
        _status = keepStatus;
        _loadingPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = keepStatus;
        _loadingPreview = false;
      });
    }
  }

  Future<void> _runPromote() async {
    if (!widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PromoteConfirmDialog(
        festivalName: widget.workspace.displayName,
        diff: _diff,
        canEditBands: widget.workspace.canEditBands,
        canEditSchedule: widget.workspace.canEditSchedule,
        canEditDescriptions: widget.workspace.canEditDescriptions,
        alertFolderConfigured:
            widget.workspace.alertFolderUrl.trim().isNotEmpty,
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _promoting = true;
      _error = null;
      _status = 'Flushing local schedule to Dropbox…';
    });
    try {
      if (widget.workspace.canEditSchedule &&
          widget.workspace.scheduleUrl.trim().isNotEmpty) {
        await widget.scheduleService.flushSync(widget.workspace);
      }
      setState(() => _status = 'Publishing…');
      final diff = await _promote.promote(widget.workspace);
      if (!mounted) return;

      final alertQueued = diff.messages.any(
        (m) => m.contains('Queued band announcement'),
      );
      final status = alertQueued
          ? 'Published to Production. Queued push for ${diff.addedBandNames.length} '
              'new band(s) — ALL app users will see that announcement when it sends. '
              'Processing can take up to 10 minutes.'
          : 'Published to Production.';

      setState(() {
        _promoting = false;
        _status = status;
        _alertsRefreshToken++;
      });

      await showDialog<void>(
        context: context,
        builder: (context) => _PublishResultDialog(
          festivalName: widget.workspace.displayName,
          diff: diff,
          alertQueued: alertQueued,
        ),
      );
      if (!mounted) return;

      // Refresh counts so Testing → Production preview reflects the publish.
      await _loadPreview(keepStatus: status);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _promoting = false;
        _error = e.toString();
        _status = null;
      });
    }
  }

  bool get _canPromote {
    final ws = widget.workspace;
    return widget.dropboxConnected &&
        ws.testingPointerUrl.trim().isNotEmpty &&
        ws.productionPointerUrl.trim().isNotEmpty &&
        ws.testingPointerUrl.trim() != ws.productionPointerUrl.trim() &&
        ws.hasAnyEditAccess &&
        !_loadingPreview &&
        !_promoting &&
        _error == null;
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final yearRoll = _diff?.isYearRoll == true;
    final testingYear = _diff?.testingYear.trim() ?? '';
    final productionYear = _diff?.productionYear.trim() ?? '';
    final alertFolder = workspace.alertFolderUrl.trim();

    return SingleChildScrollView(
      child: PortalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              yearRoll
                  ? 'Testing is on a newer event year than Production. Publish '
                      'copies Testing artists, schedule, and description map onto '
                      'the new-year Production files, then updates the Production '
                      'pointer file (archive Current as $productionYear, set Current '
                      'to $testingYear).'
                  : 'Day-to-day edits use Testing. Publish to Production copies '
                      'artists, schedule, and description map onto the Production files '
                      'without breaking Dropbox share links.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            StatusBanner(
              text: yearRoll
                  ? 'Year roll: Testing $testingYear → Production $productionYear. '
                      'CSV data goes into the $testingYear Production files only; '
                      '$productionYear Production files are left as-is. The Production '
                      'pointer file is then updated so Current points at $testingYear.'
                  : 'Verify artists, schedule, and descriptions look correct in '
                      'Testing (fan app: Advanced → Testing) before publishing. '
                      'Production is what most attendees see.',
            ),
            if (workspace.canEditBands && alertFolder.isNotEmpty) ...[
              const SizedBox(height: 12),
              if ((_diff?.addedBandNames.isNotEmpty ?? false))
                StatusBanner(
                  text:
                      'This publish will announce ${_diff!.addedBandNames.length} '
                      'new band(s) to ALL festival app users. Review the list in '
                      'the confirmation dialog before publishing — there is no '
                      'clawing that push back once it is sent.',
                  isError: true,
                )
              else
                const StatusBanner(
                  text:
                      'If this publish adds new bands, a push notification listing those '
                      'bands goes to ALL users of the festival app. There is no clawing '
                      'that message back once it is sent.',
                  isError: true,
                ),
            ],
            const SizedBox(height: 16),
            if (_status != null) StatusBanner(text: _status!),
            if (_error != null) StatusBanner(text: _error!, isError: true),
            if (yearRoll) ...[
              _ReadonlyLine('Testing event year', testingYear),
              _ReadonlyLine('Production event year', productionYear),
            ],
            _ReadonlyLine('Testing link', workspace.testingPointerUrl),
            _ReadonlyLine('Production link', workspace.productionPointerUrl),
            const SizedBox(height: 12),
            if (!widget.dropboxConnected)
              const StatusBanner(
                text: 'Connect Dropbox in Settings before publishing.',
                isError: true,
              ),
            if (workspace.productionPointerUrl.trim().isEmpty)
              const StatusBanner(
                text: 'Set a Production link in Settings before publishing.',
                isError: true,
              ),
            if (_loadingPreview)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              )
            else if (_diff != null) ...[
              const Text(
                'Preview',
                style: TextStyle(
                  color: AppColors.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              for (final line in _diff!.summaryLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $line',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              if (workspace.canEditBands &&
                  alertFolder.isNotEmpty &&
                  _diff!.addedBandNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Bands that will be announced:',
                  style: TextStyle(
                    color: AppColors.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                for (final name in _diff!.addedBandNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $name',
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: _canPromote ? _runPromote : null,
                  child: Text(
                    _promoting
                        ? 'Publishing…'
                        : (yearRoll
                            ? 'Publish year $testingYear → Production'
                            : 'Publish Testing → Production'),
                  ),
                ),
                OutlinedButton(
                  onPressed: _promoting
                      ? null
                      : () => _loadPreview(forceRefresh: true),
                  child: const Text('Refresh preview'),
                ),
                OutlinedButton(
                  onPressed: _promoting ? null : widget.onBack,
                  child: const Text('Back to Settings'),
                ),
              ],
            ),
            if (alertFolder.isNotEmpty) ...[
              const SizedBox(height: 28),
              RecentAlertsList(
                dropboxApi: widget.dropboxApi,
                folderShareUrl: alertFolder,
                dropboxConnected: widget.dropboxConnected,
                refreshToken: _alertsRefreshToken,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PublishResultDialog extends StatelessWidget {
  const _PublishResultDialog({
    required this.festivalName,
    required this.diff,
    required this.alertQueued,
  });

  final String festivalName;
  final PromoteDiff diff;
  final bool alertQueued;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Publish complete'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBanner(
                text: '“$festivalName” Production data was updated successfully.',
              ),
              const Text(
                'What happened:',
                style: TextStyle(
                  color: AppColors.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              for (final line in diff.messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $line',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              if (alertQueued) ...[
                const SizedBox(height: 12),
                StatusBanner(
                  text:
                      'Band announcement queued for ${diff.addedBandNames.length} '
                      'new band(s). ALL app users will receive that push. '
                      'Processing can take up to 10 minutes.',
                  isError: true,
                ),
                const Text(
                  'New bands announced:',
                  style: TextStyle(
                    color: AppColors.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                for (final name in diff.addedBandNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $name',
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _PromoteConfirmDialog extends StatefulWidget {
  const _PromoteConfirmDialog({
    required this.festivalName,
    required this.diff,
    required this.canEditBands,
    required this.canEditSchedule,
    required this.canEditDescriptions,
    required this.alertFolderConfigured,
  });

  final String festivalName;
  final PromoteDiff? diff;
  final bool canEditBands;
  final bool canEditSchedule;
  final bool canEditDescriptions;
  final bool alertFolderConfigured;

  @override
  State<_PromoteConfirmDialog> createState() => _PromoteConfirmDialogState();
}

class _PromoteConfirmDialogState extends State<_PromoteConfirmDialog> {
  bool _verifiedTesting = false;

  List<String> get _willUpdate {
    final items = <String>[];
    final diff = widget.diff;
    if (diff != null && diff.isYearRoll) {
      items.add(
        'Production pointer file (archive Current as ${diff.productionYear}, '
        'set Current to ${diff.testingYear})',
      );
    }
    if (widget.canEditBands) items.add('Artists');
    if (widget.canEditSchedule) items.add('Schedule');
    if (widget.canEditDescriptions) items.add('Description map');
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.diff;
    final yearRoll = diff?.isYearRoll == true;
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: Text(
        yearRoll
            ? 'Confirm publish year ${diff!.testingYear} to Production'
            : 'Confirm publish to Production',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBanner(
                text: yearRoll
                    ? 'This will rewrite the Production pointer file for '
                        '“${widget.festivalName}” (archive ${diff!.productionYear}, '
                        'Current → ${diff.testingYear}) and overwrite the new-year '
                        'Production CSVs. Most attendees see Production. '
                        'This cannot be undone from the admin app.'
                    : 'This will overwrite Production data for '
                        '“${widget.festivalName}”. Most attendees see Production. '
                        'This cannot be undone from the admin app.',
                isError: true,
              ),
              if (widget.canEditBands &&
                  widget.alertFolderConfigured &&
                  (diff?.addedBandNames.isNotEmpty ?? false)) ...[
                const SizedBox(height: 8),
                StatusBanner(
                  text:
                      'This publish will queue a push to ALL festival app users '
                      'announcing ${diff!.addedBandNames.length} new band(s). '
                      'There is no clawing that announcement back once it is sent. '
                      'Cancel now if any name should not go out.',
                  isError: true,
                ),
                const Text(
                  'Bands that will be announced:',
                  style: TextStyle(
                    color: AppColors.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                for (final name in diff.addedBandNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $name',
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ] else if (widget.canEditBands &&
                  widget.alertFolderConfigured) ...[
                const SizedBox(height: 8),
                const StatusBanner(
                  text:
                      'No new bands vs Production — no band announcement push '
                      'will be queued by this publish.',
                ),
              ],
              const Text(
                'Before continuing, confirm you have already checked that '
                'everything looks correct in Testing '
                '(artists, schedule, descriptions).',
                style: TextStyle(color: AppColors.heading, fontSize: 14),
              ),
              const SizedBox(height: 14),
              const Text(
                'Will update:',
                style: TextStyle(
                  color: AppColors.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in _willUpdate)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $item',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              if (diff != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Preview:',
                  style: TextStyle(
                    color: AppColors.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                for (final line in diff.summaryLines.take(yearRoll ? 4 : 3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $line',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _verifiedTesting,
                onChanged: (v) =>
                    setState(() => _verifiedTesting = v ?? false),
                title: Text(
                  yearRoll
                      ? 'I have verified Testing ($testingYearLabel) looks correct '
                          'and want to publish that year to Production'
                      : 'I have verified Testing looks correct and want to publish to Production',
                  style: const TextStyle(color: AppColors.heading, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _verifiedTesting
              ? () => Navigator.pop(context, true)
              : null,
          child: Text(
            yearRoll
                ? 'Publish year ${diff!.testingYear} to Production'
                : 'Publish to Production',
          ),
        ),
      ],
    );
  }

  String get testingYearLabel {
    final y = widget.diff?.testingYear.trim() ?? '';
    return y.isEmpty ? 'Testing' : y;
  }
}

class _AddNewYearResult {
  const _AddNewYearResult({
    required this.newYear,
    required this.folder,
    required this.filePrefix,
  });

  final String newYear;
  final String folder;
  final String filePrefix;
}

class _AddNewYearDialog extends StatefulWidget {
  const _AddNewYearDialog({
    required this.currentYear,
    required this.festivalName,
    required this.initialFolder,
    required this.initialPrefix,
  });

  final String currentYear;
  final String festivalName;
  final String initialFolder;
  final String initialPrefix;

  @override
  State<_AddNewYearDialog> createState() => _AddNewYearDialogState();
}

class _AddNewYearDialogState extends State<_AddNewYearDialog> {
  late final TextEditingController _year;
  late final TextEditingController _prefix;
  late final TextEditingController _folder;
  String? _error;

  @override
  void initState() {
    super.initState();
    _year = TextEditingController(
      text: FestivalYearService.defaultNewYear(widget.currentYear),
    );
    _prefix = TextEditingController(text: widget.initialPrefix);
    _folder = TextEditingController(text: widget.initialFolder);
    _year.addListener(() => setState(() {}));
    _prefix.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _year.dispose();
    _prefix.dispose();
    _folder.dispose();
    super.dispose();
  }

  void _submit() {
    final year = _year.text.trim();
    final prefix = _prefix.text.trim();
    final folder = _folder.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(year)) {
      setState(() => _error = 'Enter a 4-digit year.');
      return;
    }
    if (year == widget.currentYear.trim()) {
      setState(() => _error = 'New year must differ from ${widget.currentYear}.');
      return;
    }
    if (prefix.isEmpty) {
      setState(() => _error = 'File prefix is required.');
      return;
    }
    if (folder.isEmpty) {
      setState(() => _error = 'Dropbox folder path is required.');
      return;
    }
    Navigator.pop(
      context,
      _AddNewYearResult(
        newYear: year,
        folder: folder,
        filePrefix: prefix,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = _year.text.trim().isEmpty
        ? FestivalYearService.defaultNewYear(widget.currentYear)
        : _year.text.trim();
    final prefix = _prefix.text.trim().isEmpty
        ? widget.initialPrefix
        : _prefix.text.trim();
    final files = FestivalYearService.plannedFilenames(
      prefix: prefix,
      newYear: year,
    );

    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Add new year'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                StatusBanner(text: _error!, isError: true),
                const SizedBox(height: 12),
              ],
              Text(
                'Current year ${widget.currentYear} will be archived on the '
                'Testing link only. New empty CSV files will be created for $year. '
                'The Production link is not modified — Publish to Production after verifying Testing.',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _year,
                decoration: const InputDecoration(
                  labelText: 'New event year',
                  hintText: '2027',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prefix,
                decoration: const InputDecoration(
                  labelText: 'File prefix',
                  hintText: 'mdf',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _folder,
                decoration: const InputDecoration(
                  labelText: 'Dropbox folder',
                  hintText: '/FestivalName_Public',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Text(
                'Files to create:\n${files.map((f) => '• $f').join('\n')}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text('Archive ${widget.currentYear} & create $year'),
        ),
      ],
    );
  }
}
