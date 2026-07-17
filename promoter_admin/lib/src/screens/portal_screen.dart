import 'dart:async';

import 'package:flutter/material.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/screens/sections/alerts_section.dart';
import 'package:promoter_admin/src/screens/sections/bands_section.dart';
import 'package:promoter_admin/src/screens/sections/descriptions_section.dart';
import 'package:promoter_admin/src/screens/sections/schedule_section.dart';
import 'package:promoter_admin/src/screens/sections/settings_section.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/portal_navigation_store.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/export_schedule_dialog.dart';

class PortalScreen extends StatefulWidget {
  const PortalScreen({
    super.key,
    required this.workspace,
    required this.festivalChoices,
    required this.activeFestivalId,
    required this.pointerService,
    required this.dropboxApi,
    required this.lineupService,
    required this.scheduleService,
    required this.descriptionMapService,
    required this.dropboxConnected,
    required this.dropboxLabel,
    required this.dropboxConnecting,
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
  final LineupService lineupService;
  final ScheduleService scheduleService;
  final DescriptionMapService descriptionMapService;
  final bool dropboxConnected;
  final String dropboxLabel;
  final bool dropboxConnecting;
  final Future<void> Function(FestivalWorkspace) onWorkspaceChanged;
  final Future<void> Function(String festivalId) onSwitchFestival;
  final Future<void> Function(FestivalWorkspace workspace) onAddFestival;
  final Future<void> Function(String festivalId) onDeleteFestival;
  final Future<void> Function() onConnectDropbox;
  final Future<void> Function() onDisconnectDropbox;

  @override
  State<PortalScreen> createState() => _PortalScreenState();
}

class _PortalScreenState extends State<PortalScreen> {
  final _navStore = PortalNavigationStore();

  AppSection _section = AppSection.settings;
  BandsTab _bandsTab = BandsTab.list;
  ScheduleTab _scheduleTab = ScheduleTab.entry;
  DescriptionsTab _descriptionsTab = DescriptionsTab.list;
  bool _showPromote = false;
  String? _descriptionPrefillLabel;
  bool _bandFormIsEdit = false;
  String _descriptionFormHeading = 'Create Description';

  FestivalWorkspace get _ws => widget.workspace;

  @override
  void initState() {
    super.initState();
    _restoreNavigation();
  }

  Future<void> _restoreNavigation() async {
    final saved = await _navStore.loadForFestival(widget.activeFestivalId);
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _section = saved.section;
        _scheduleTab = saved.scheduleTab;
      } else {
        _section = AppSection.settings;
        _scheduleTab = ScheduleTab.entry;
      }
      _bandsTab = BandsTab.list;
      _descriptionsTab = DescriptionsTab.list;
      _showPromote = false;
      _bandFormIsEdit = false;
      _descriptionPrefillLabel = null;
    });
    _ensureSectionAllowed();
  }

  Future<void> _persistNavigation() async {
    await _navStore.saveForFestival(
      widget.activeFestivalId,
      PortalNavigation(section: _section, scheduleTab: _scheduleTab),
    );
  }

  void _applyNavigation({
    AppSection? section,
    BandsTab? bandsTab,
    ScheduleTab? scheduleTab,
    DescriptionsTab? descriptionsTab,
    bool? showPromote,
    bool resetBandForm = false,
    bool clearDescriptionPrefill = false,
  }) {
    setState(() {
      if (section != null) _section = section;
      if (bandsTab != null) {
        _bandsTab = bandsTab;
        if (bandsTab == BandsTab.list) _bandFormIsEdit = false;
      }
      if (scheduleTab != null) _scheduleTab = scheduleTab;
      if (descriptionsTab != null) {
        _descriptionsTab = descriptionsTab;
        if (descriptionsTab == DescriptionsTab.list) {
          _descriptionPrefillLabel = null;
        }
      }
      if (showPromote != null) _showPromote = showPromote;
      if (resetBandForm) _bandFormIsEdit = false;
      if (clearDescriptionPrefill) _descriptionPrefillLabel = null;
    });
    _persistNavigation();
  }

  String get _festivalName => _ws.festivalName.trim();

  ({String heading, String subheading}) get _titles {
    switch (_section) {
      case AppSection.settings:
        if (_showPromote) {
          return (
            heading: 'Publish to Production',
            subheading:
                'Copy Testing artists, schedule, and descriptions to Production',
          );
        }
        return (
          heading: 'Festival Configuration',
          subheading:
              'Testing & Production links, Dropbox, venues, and festival vocabulary',
        );
      case AppSection.bands:
        return _bandsTab == BandsTab.add
            ? (
                heading: _bandFormIsEdit ? 'Edit Artist' : 'Add Artist',
                subheading:
                    'Prefer MA/MB URLs; name search only when the match is unique',
              )
            : (
                heading: 'Artists',
                subheading:
                    'Testing lineup (what Advanced → Testing shows in the app)',
              );
      case AppSection.schedule:
        switch (_scheduleTab) {
          case ScheduleTab.view:
            return (
              heading: 'Schedule View',
              subheading: 'Events on the Testing schedule',
            );
          case ScheduleTab.stats:
            return (
              heading: 'Show Stats',
              subheading: 'Counts per artist and event type',
            );
          case ScheduleTab.entry:
            return (
              heading: 'Schedule Entry',
              subheading: 'Add events to the Testing schedule',
            );
        }
      case AppSection.descriptions:
        return _descriptionsTab == DescriptionsTab.form
            ? (
                heading: _descriptionFormHeading,
                subheading: _ws.canEditDescriptions
                    ? 'Save to Dropbox and update the description map'
                    : 'Save a Dropbox file and share the link with the description admin',
              )
            : (
                heading: 'Descriptions',
                subheading: 'Artists with and without description map entries',
              );
      case AppSection.alerts:
        return (
          heading: 'Send Alert',
          subheading: 'Queue a push notification for all festival app users',
        );
    }
  }

  String get _metaLine {
    final parts = <String>[];
    if (_ws.eventYear.isNotEmpty) parts.add('Year ${_ws.eventYear}');
    if (widget.dropboxConnected) {
      parts.add(
        widget.dropboxLabel.isEmpty
            ? 'Dropbox connected'
            : 'Dropbox: ${widget.dropboxLabel}',
      );
    } else {
      parts.add('Dropbox not connected');
    }
    if (_ws.testingPointerUrl.isNotEmpty) {
      parts.add('Testing link set');
    }
    final edit = <String>[];
    if (_ws.canEditBands) edit.add('artists');
    if (_ws.canEditSchedule) edit.add('schedule');
    if (_ws.canEditDescriptions) edit.add('descriptions');
    if (edit.isEmpty) {
      parts.add('View only (no write access)');
    } else if (edit.length < 3) {
      parts.add('Edit: ${edit.join(', ')}');
    }
    return parts.join(' · ');
  }

  void _ensureSectionAllowed() {
    // Artists / Schedule / Descriptions stay visible without write —
    // mutation controls are disabled or narrowed inside each section.
    if (_section == AppSection.alerts && !_ws.customAlertsUiEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyNavigation(section: AppSection.settings, showPromote: false);
      });
      return;
    }
    final denied = _showPromote && !_ws.hasAnyEditAccess;
    if (!denied) {
      if (_section == AppSection.schedule &&
          !_ws.canEditSchedule &&
          _scheduleTab == ScheduleTab.entry) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyNavigation(scheduleTab: ScheduleTab.view);
        });
      }
      if (_section == AppSection.bands &&
          !_ws.canEditBands &&
          _bandsTab == BandsTab.add) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _bandsTab = BandsTab.list;
            _bandFormIsEdit = false;
          });
        });
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyNavigation(section: AppSection.settings, showPromote: false);
    });
  }

  Future<void> _openScheduleExport(ScheduleExportFormat format) async {
    try {
      final events = await widget.scheduleService.load(_ws);
      if (!mounted) return;
      if (events.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('There are no schedule events to export.'),
          ),
        );
        return;
      }
      await showScheduleExportDialog(
        context,
        workspace: _ws,
        events: events,
        initialFormat: format,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load the schedule: $error')),
      );
    }
  }

  @override
  void didUpdateWidget(covariant PortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeFestivalId != widget.activeFestivalId) {
      _restoreNavigation();
      return;
    }
    _ensureSectionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    final titles = _titles;
    final shell = AppShell(
      festivalName: _festivalName,
      heading: titles.heading,
      subheading: titles.subheading,
      metaLine: _metaLine,
      section: _section,
      settingsPromoteSelected: _showPromote,
      canEditBands: _ws.canEditBands,
      canEditSchedule: _ws.canEditSchedule,
      canEditDescriptions: _ws.canEditDescriptions,
      allowCustomAlerts: _ws.customAlertsUiEnabled,
      onPromoteTap: () =>
          _applyNavigation(section: AppSection.settings, showPromote: true),
      onSectionChanged: (s) => _applyNavigation(
        section: s,
        showPromote: false,
        bandsTab: s == AppSection.bands ? BandsTab.list : null,
        descriptionsTab: s == AppSection.descriptions
            ? DescriptionsTab.list
            : null,
        resetBandForm: s == AppSection.bands,
        clearDescriptionPrefill: s == AppSection.descriptions,
      ),
      bandsTab: _bandsTab,
      onBandsTabChanged: (t) => _applyNavigation(
        section: AppSection.bands,
        bandsTab: t,
        showPromote: false,
        resetBandForm: t == BandsTab.list,
      ),
      scheduleTab: _scheduleTab,
      onScheduleTabChanged: (t) => _applyNavigation(
        section: AppSection.schedule,
        scheduleTab: t,
        showPromote: false,
      ),
      onDescriptionsTabChanged: (t) => _applyNavigation(
        section: AppSection.descriptions,
        descriptionsTab: t,
        showPromote: false,
        clearDescriptionPrefill: t == DescriptionsTab.list,
      ),
      child: _buildBody(),
    );
    return PlatformMenuBar(
      menus: [
        const PlatformMenu(
          label: AppBrand.name,
          menus: [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.servicesSubmenu,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hideOtherApplications,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.showAllApplications,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Save Schedule as PDF…',
              onSelected: () =>
                  unawaited(_openScheduleExport(ScheduleExportFormat.pdf)),
            ),
            PlatformMenuItem(
              label: 'Save Schedule as HTML…',
              onSelected: () =>
                  unawaited(_openScheduleExport(ScheduleExportFormat.html)),
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Undo',
              onSelectedIntent: UndoTextIntent(SelectionChangedCause.keyboard),
            ),
            PlatformMenuItem(
              label: 'Redo',
              onSelectedIntent: RedoTextIntent(SelectionChangedCause.keyboard),
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Cut',
                  onSelectedIntent: CopySelectionTextIntent.cut(
                    SelectionChangedCause.toolbar,
                  ),
                ),
                PlatformMenuItem(
                  label: 'Copy',
                  onSelectedIntent: CopySelectionTextIntent.copy,
                ),
                PlatformMenuItem(
                  label: 'Paste',
                  onSelectedIntent: PasteTextIntent(
                    SelectionChangedCause.toolbar,
                  ),
                ),
                PlatformMenuItem(
                  label: 'Select All',
                  onSelectedIntent: SelectAllTextIntent(
                    SelectionChangedCause.toolbar,
                  ),
                ),
              ],
            ),
          ],
        ),
        const PlatformMenu(
          label: 'View',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Window',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.arrangeWindowsInFront,
                ),
              ],
            ),
          ],
        ),
      ],
      child: shell,
    );
  }

  Widget _buildBody() {
    switch (_section) {
      case AppSection.settings:
        return SettingsSection(
          workspace: _ws,
          festivalChoices: widget.festivalChoices,
          activeFestivalId: widget.activeFestivalId,
          pointerService: widget.pointerService,
          dropboxApi: widget.dropboxApi,
          scheduleService: widget.scheduleService,
          dropboxConnected: widget.dropboxConnected,
          dropboxLabel: widget.dropboxLabel,
          dropboxConnecting: widget.dropboxConnecting,
          showPromote: _showPromote,
          onShowPromote: (v) => setState(() => _showPromote = v),
          onWorkspaceChanged: widget.onWorkspaceChanged,
          onSwitchFestival: widget.onSwitchFestival,
          onAddFestival: widget.onAddFestival,
          onDeleteFestival: widget.onDeleteFestival,
          onConnectDropbox: widget.onConnectDropbox,
          onDisconnectDropbox: widget.onDisconnectDropbox,
        );
      case AppSection.bands:
        return BandsSection(
          workspace: _ws,
          lineupService: widget.lineupService,
          descriptionMapService: widget.descriptionMapService,
          dropboxApi: widget.dropboxApi,
          tab: _bandsTab,
          onTabChanged: (t) => setState(() {
            _bandsTab = t;
            if (t == BandsTab.list) _bandFormIsEdit = false;
          }),
          onFormModeChanged: (editing) => setState(() {
            _bandFormIsEdit = editing;
            _bandsTab = BandsTab.add;
          }),
          dropboxConnected: widget.dropboxConnected,
          onConnectDropbox: widget.onConnectDropbox,
        );
      case AppSection.schedule:
        return ScheduleSection(
          key: ValueKey(
            'schedule-vocab|'
            '${_ws.venues.join('\n')}|'
            '${_ws.days.join('\n')}|'
            '${_ws.dates.join('\n')}|'
            '${_ws.eventTypes.join('\n')}|'
            '${_ws.dateRolloverTime}',
          ),
          workspace: _ws,
          scheduleService: widget.scheduleService,
          lineupService: widget.lineupService,
          descriptionMapService: widget.descriptionMapService,
          dropboxApi: widget.dropboxApi,
          tab: _scheduleTab,
          onTabChanged: (t) => _applyNavigation(
            section: AppSection.schedule,
            scheduleTab: t,
            showPromote: false,
          ),
          dropboxConnected: widget.dropboxConnected,
          onConnectDropbox: widget.onConnectDropbox,
          onWorkspaceChanged: widget.onWorkspaceChanged,
        );
      case AppSection.descriptions:
        return DescriptionsSection(
          workspace: _ws,
          descriptionMapService: widget.descriptionMapService,
          lineupService: widget.lineupService,
          dropboxApi: widget.dropboxApi,
          tab: _descriptionsTab,
          onTabChanged: (t) => setState(() => _descriptionsTab = t),
          onFormModeChanged: (heading) => setState(() {
            _descriptionFormHeading = heading;
            _descriptionsTab = DescriptionsTab.form;
          }),
          dropboxConnected: widget.dropboxConnected,
          onConnectDropbox: widget.onConnectDropbox,
          prefillLabel: _descriptionPrefillLabel,
          onPrefillConsumed: () {
            if (_descriptionPrefillLabel != null) {
              setState(() => _descriptionPrefillLabel = null);
            }
          },
        );
      case AppSection.alerts:
        return AlertsSection(
          workspace: _ws,
          dropboxApi: widget.dropboxApi,
          dropboxConnected: widget.dropboxConnected,
          onConnectDropbox: widget.onConnectDropbox,
        );
    }
  }
}
