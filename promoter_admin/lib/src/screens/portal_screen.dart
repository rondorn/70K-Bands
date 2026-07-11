import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/screens/sections/bands_section.dart';
import 'package:promoter_admin/src/screens/sections/descriptions_section.dart';
import 'package:promoter_admin/src/screens/sections/schedule_section.dart';
import 'package:promoter_admin/src/screens/sections/settings_section.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

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
  AppSection _section = AppSection.settings;
  BandsTab _bandsTab = BandsTab.list;
  ScheduleTab _scheduleTab = ScheduleTab.entry;
  DescriptionsTab _descriptionsTab = DescriptionsTab.write;
  bool _showPromote = false;
  String? _descriptionPrefillLabel;
  bool _bandFormIsEdit = false;

  FestivalWorkspace get _ws => widget.workspace;

  String get _festivalName => _ws.festivalName.trim();

  ({String heading, String subheading}) get _titles {
    switch (_section) {
      case AppSection.settings:
        if (_showPromote) {
          return (
            heading: 'Promote to Production',
            subheading: 'Copy testing data onto production files in place',
          );
        }
        return (
          heading: 'Festival Configuration',
          subheading: 'Pointers, Dropbox, venues, and festival vocabulary',
        );
      case AppSection.bands:
        return _bandsTab == BandsTab.add
            ? (
                heading: _bandFormIsEdit ? 'Edit Band' : 'Add Band',
                subheading: 'Discover from Metal Archives or MusicBrainz',
              )
            : (
                heading: 'Band Lineup',
                subheading: 'Testing lineup from Current::artistUrl',
              );
      case AppSection.schedule:
        switch (_scheduleTab) {
          case ScheduleTab.view:
            return (
              heading: 'Schedule View',
              subheading: 'Events on the testing schedule',
            );
          case ScheduleTab.stats:
            return (
              heading: 'Show Stats',
              subheading: 'Counts per band and event type',
            );
          case ScheduleTab.entry:
            return (
              heading: 'Schedule Data Entry',
              subheading: 'Add events to the festival schedule',
            );
        }
      case AppSection.descriptions:
        return _descriptionsTab == DescriptionsTab.map
            ? (
                heading: 'Description Map',
                subheading: 'Link band and event names to Dropbox description files',
              )
            : (
                heading: 'Write Description',
                subheading: 'Save plain-text description files for bands and events',
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
      parts.add('Testing pointer set');
    }
    final access = <String>[];
    if (_ws.canEditBands) access.add('bands');
    if (_ws.canEditSchedule) access.add('schedule');
    if (_ws.canEditDescriptions) access.add('descriptions');
    if (access.isEmpty) {
      parts.add('No writable data files');
    } else if (access.length < 3) {
      parts.add('Edit: ${access.join(', ')}');
    }
    return parts.join(' · ');
  }

  void _ensureSectionAllowed() {
    final denied = (_section == AppSection.bands && !_ws.canEditBands) ||
        (_section == AppSection.schedule && !_ws.canEditSchedule) ||
        (_section == AppSection.descriptions && !_ws.canEditDescriptions) ||
        (_showPromote && !_ws.hasAnyEditAccess);
    if (!denied) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _section = AppSection.settings;
        _showPromote = false;
      });
    });
  }

  @override
  void didUpdateWidget(covariant PortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureSectionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    final titles = _titles;
    return AppShell(
      festivalName: _festivalName,
      heading: titles.heading,
      subheading: titles.subheading,
      metaLine: _metaLine,
      section: _section,
      settingsPromoteSelected: _showPromote,
      canEditBands: _ws.canEditBands,
      canEditSchedule: _ws.canEditSchedule,
      canEditDescriptions: _ws.canEditDescriptions,
      onPromoteTap: () => setState(() {
        _section = AppSection.settings;
        _showPromote = true;
      }),
      onSectionChanged: (s) {
        setState(() {
          _section = s;
          _showPromote = false;
        });
      },
      bandsTab: _bandsTab,
      onBandsTabChanged: (t) => setState(() {
        _bandsTab = t;
        _section = AppSection.bands;
        _showPromote = false;
        if (t == BandsTab.list) _bandFormIsEdit = false;
      }),
      scheduleTab: _scheduleTab,
      onScheduleTabChanged: (t) => setState(() {
        _scheduleTab = t;
        _section = AppSection.schedule;
        _showPromote = false;
      }),
      descriptionsTab: _descriptionsTab,
      onDescriptionsTabChanged: (t) => setState(() {
        _descriptionsTab = t;
        _section = AppSection.descriptions;
        _showPromote = false;
        _descriptionPrefillLabel = null;
      }),
      child: _buildBody(),
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
          workspace: _ws,
          scheduleService: widget.scheduleService,
          lineupService: widget.lineupService,
          descriptionMapService: widget.descriptionMapService,
          tab: _scheduleTab,
          onTabChanged: (t) => setState(() => _scheduleTab = t),
          dropboxConnected: widget.dropboxConnected,
          onConnectDropbox: widget.onConnectDropbox,
          onWorkspaceChanged: widget.onWorkspaceChanged,
        );
      case AppSection.descriptions:
        return DescriptionsSection(
          workspace: _ws,
          descriptionMapService: widget.descriptionMapService,
          lineupService: widget.lineupService,
          scheduleService: widget.scheduleService,
          tab: _descriptionsTab,
          onTabChanged: (t) => setState(() => _descriptionsTab = t),
          dropboxConnected: widget.dropboxConnected,
          onConnectDropbox: widget.onConnectDropbox,
          prefillLabel: _descriptionPrefillLabel,
          onPrefillConsumed: () {
            if (_descriptionPrefillLabel != null) {
              setState(() => _descriptionPrefillLabel = null);
            }
          },
        );
    }
  }
}
