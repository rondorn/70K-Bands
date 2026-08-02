import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/screens/sections/alerts_section.dart';
import 'package:promoter_admin/src/screens/sections/bands_section.dart';
import 'package:promoter_admin/src/screens/sections/descriptions_section.dart';
import 'package:promoter_admin/src/screens/sections/schedule_section.dart';
import 'package:promoter_admin/src/screens/sections/reports_section.dart';
import 'package:promoter_admin/src/screens/sections/settings_section.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/emergency_local_mode_support.dart';
import 'package:promoter_admin/src/services/local_content_store.dart';
import 'package:promoter_admin/src/services/portal_navigation_store.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/publish_status_service.dart';
import 'package:promoter_admin/src/services/report_discovery_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/csv_staging.dart';
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
    required this.publishStatusService,
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
  final PublishStatusService publishStatusService;
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
  ScheduleTab _scheduleTab = ScheduleTab.view;
  DescriptionsTab _descriptionsTab = DescriptionsTab.list;
  bool _showPromote = false;
  String? _descriptionPrefillLabel;
  bool _bandFormIsEdit = false;
  String _descriptionFormHeading = 'Create Description';
  Future<void> _persistChain = Future<void>.value();

  FestivalWorkspace get _ws => widget.workspace;

  @override
  void initState() {
    super.initState();
    widget.publishStatusService.bind(
      workspace: widget.workspace,
      dropboxConnected: widget.dropboxConnected,
    );
    widget.scheduleService.addSyncListener(_onCsvSyncChanged);
    widget.lineupService.addSyncListener(_onCsvSyncChanged);
    widget.descriptionMapService.addSyncListener(_onCsvSyncChanged);
    widget.publishStatusService.addListener(_onPublishStatusChanged);
    _restoreNavigation();
  }

  @override
  void dispose() {
    widget.scheduleService.removeSyncListener(_onCsvSyncChanged);
    widget.lineupService.removeSyncListener(_onCsvSyncChanged);
    widget.descriptionMapService.removeSyncListener(_onCsvSyncChanged);
    widget.publishStatusService.removeListener(_onPublishStatusChanged);
    super.dispose();
  }

  void _onCsvSyncChanged() {
    final statuses = [
      widget.scheduleService.syncStatus,
      widget.lineupService.syncStatus,
      widget.descriptionMapService.syncStatus,
    ];
    final anySyncing = statuses.any((s) => s.state == CsvSyncState.syncing);
    final anyUnsynced = statuses.any((s) => s.hasUnsynced);
    if (!anyUnsynced && !anySyncing) {
      widget.publishStatusService.notifyTestingDataChanged();
      return;
    }
    widget.publishStatusService.refreshPendingSyncState();
  }

  void _onPublishStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreNavigation() async {
    final saved = await _navStore.loadForFestival(widget.activeFestivalId);
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _section = saved.section;
        // Never reopen data-entry forms after launch / festival switch.
        _scheduleTab = PortalNavigation.listSafeScheduleTab(saved.scheduleTab);
      } else {
        _section = AppSection.settings;
        _scheduleTab = ScheduleTab.view;
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
    // Serialize writes so rapid nav callbacks (section then tab) cannot race
    // and leave an older Entry tab on disk after View was selected.
    final section = _section;
    final scheduleTab = _scheduleTab;
    final festivalId = widget.activeFestivalId;
    _persistChain = _persistChain.then((_) async {
      await _navStore.saveForFestival(
        festivalId,
        PortalNavigation(section: section, scheduleTab: scheduleTab),
      );
    });
    await _persistChain;
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
    widget.publishStatusService.requestCheck();
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
          subheading: _ws.usesEmergencyLocalMode
              ? 'Local File Mode — map paths and save valid CSV files'
              : 'Testing & Production links, Dropbox, venues, and festival vocabulary',
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
          case ScheduleTab.preview:
            return (
              heading: 'Schedule Preview',
              subheading: 'HTML running-order layout for review',
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
                    ? (_ws.usesEmergencyLocalMode
                        ? 'Save description files locally and update the map CSV'
                        : 'Save to Dropbox and update the description map')
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
      case AppSection.reports:
        return (
          heading: 'Stats Reports',
          subheading: 'End-user and full festival dashboards from Production',
        );
    }
  }

  String get _metaLine {
    final parts = <String>[];
    if (_ws.usesEmergencyLocalMode) {
      parts.add('Local File Mode');
    }
    if (_ws.eventYear.isNotEmpty) parts.add('Year ${_ws.eventYear}');
    if (_ws.hasDataSourceYearOverride) {
      parts.add('Demo data ${_ws.dataSourceYearOverride}');
    }
    if (_ws.usesEmergencyLocalMode) {
      if (_ws.hasArtistsLocalPath) parts.add('artists path set');
      if (_ws.hasScheduleLocalPath) parts.add('schedule path set');
      if (_ws.hasDescriptionMapLocalPath) parts.add('map path set');
    } else {
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
    }
    final edit = <String>[];
    if (_ws.effectiveCanEditBands) edit.add('artists');
    if (_ws.effectiveCanEditSchedule) edit.add('schedule');
    if (_ws.effectiveCanEditDescriptions) edit.add('descriptions');
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
    if (_section == AppSection.alerts && !_ws.effectiveCustomAlertsUiEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyNavigation(section: AppSection.settings, showPromote: false);
      });
      return;
    }
    if (_section == AppSection.reports && !_ws.effectiveReportsUiEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyNavigation(section: AppSection.settings, showPromote: false);
      });
      return;
    }
    final denied = _showPromote && !_ws.hasAnyEditAccess;
    if (!denied) {
      if (_section == AppSection.schedule &&
          !_ws.effectiveCanEditSchedule &&
          _scheduleTab == ScheduleTab.entry) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyNavigation(scheduleTab: ScheduleTab.view);
        });
      }
      if (_section == AppSection.bands &&
          !_ws.effectiveCanEditBands &&
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

  @override
  void didUpdateWidget(covariant PortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.id != widget.workspace.id ||
        oldWidget.dropboxConnected != widget.dropboxConnected) {
      widget.publishStatusService.bind(
        workspace: widget.workspace,
        dropboxConnected: widget.dropboxConnected,
      );
    }
    if (oldWidget.activeFestivalId != widget.activeFestivalId) {
      _restoreNavigation();
      return;
    }
    _ensureSectionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    final titles = _titles;
    final publishStatus = widget.publishStatusService.snapshot;
    final shell = AppShell(
      festivalName: _festivalName,
      heading: titles.heading,
      subheading: titles.subheading,
      metaLine: _metaLine,
      publishStatus: publishStatus,
      section: _section,
      settingsPromoteSelected: _showPromote,
      publishNavEnabled:
          !_ws.usesEmergencyLocalMode && publishStatus.canOpenPublish,
      publishNavHighlight:
          !_ws.usesEmergencyLocalMode && publishStatus.canPublish,
      canEditBands: _ws.effectiveCanEditBands,
      canEditSchedule: _ws.effectiveCanEditSchedule,
      canEditDescriptions: _ws.effectiveCanEditDescriptions,
      allowCustomAlerts: _ws.effectiveCustomAlertsUiEnabled,
      reportsUiEnabled: _ws.effectiveReportsUiEnabled,
      onPromoteTap: () =>
          _applyNavigation(section: AppSection.settings, showPromote: true),
      onSectionChanged: (s) => _applyNavigation(
        section: s,
        showPromote: false,
        bandsTab: s == AppSection.bands ? BandsTab.list : null,
        // Opening Schedule via section alone lands on View, never Entry.
        scheduleTab: s == AppSection.schedule ? ScheduleTab.view : null,
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
    return shell;
  }

  Widget _buildBody() {
    final publishStatus = widget.publishStatusService.snapshot;
    switch (_section) {
      case AppSection.settings:
        return SettingsSection(
          workspace: _ws,
          festivalChoices: widget.festivalChoices,
          activeFestivalId: widget.activeFestivalId,
          pointerService: widget.pointerService,
          dropboxApi: widget.dropboxApi,
          scheduleService: widget.scheduleService,
          lineupService: widget.lineupService,
          descriptionMapService: widget.descriptionMapService,
          dropboxConnected: widget.dropboxConnected,
          dropboxLabel: widget.dropboxLabel,
          dropboxConnecting: widget.dropboxConnecting,
          showPromote: _showPromote,
          publishStatus: publishStatus,
          publishStatusService: widget.publishStatusService,
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
          onTestingDataChanged: widget.publishStatusService.notifyRecordSaved,
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
          onTestingDataChanged: widget.publishStatusService.notifyRecordSaved,
        );
      case AppSection.descriptions:
        return DescriptionsSection(
          workspace: _ws,
          descriptionMapService: widget.descriptionMapService,
          lineupService: widget.lineupService,
          dropboxApi: widget.dropboxApi,
          tab: _descriptionsTab,
          onTabChanged: (DescriptionsTab t) =>
              setState(() => _descriptionsTab = t),
          onFormModeChanged: (heading) => setState(() {
            _descriptionFormHeading = heading;
            _descriptionsTab = DescriptionsTab.form;
          }),
          dropboxConnected: widget.dropboxConnected,
          onConnectDropbox: widget.onConnectDropbox,
          currentAccountLabel: widget.dropboxLabel,
          prefillLabel: _descriptionPrefillLabel,
          onPrefillConsumed: () {
            if (_descriptionPrefillLabel != null) {
              setState(() => _descriptionPrefillLabel = null);
            }
          },
          onTestingDataChanged: widget.publishStatusService.notifyRecordSaved,
        );
      case AppSection.alerts:
        return AlertsSection(
          workspace: _ws,
          dropboxApi: widget.dropboxApi,
          dropboxConnected: widget.dropboxConnected,
          onConnectDropbox: widget.onConnectDropbox,
        );
      case AppSection.reports:
        return ReportsSection(
          workspace: _ws,
          dropboxConnected: widget.dropboxConnected,
          onDiscoverReports: widget.dropboxConnected
              ? ({bool forceRefresh = false}) async {
                  final updated = await ReportDiscoveryService.apply(
                    _ws,
                    widget.dropboxApi,
                    forceRefresh: forceRefresh,
                  );
                  await widget.onWorkspaceChanged(updated);
                  return updated;
                }
              : null,
        );
    }
  }
}
