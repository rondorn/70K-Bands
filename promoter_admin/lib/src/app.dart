import 'dart:async';

import 'package:flutter/material.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/screens/onboarding_screen.dart';
import 'package:promoter_admin/src/screens/portal_screen.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/dropbox_auth.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';
import 'package:promoter_admin/src/services/festival_folder_path_cache.dart';
import 'package:promoter_admin/src/services/lineup_service.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/workspace_store.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

class PromoterAdminApp extends StatefulWidget {
  const PromoterAdminApp({super.key});

  @override
  State<PromoterAdminApp> createState() => _PromoterAdminAppState();
}

class _PromoterAdminAppState extends State<PromoterAdminApp> {
  final _store = WorkspaceStore();
  final _pointers = PointerService();
  final _auth = DropboxAuth();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  FestivalRegistry? _registry;
  late final DropboxApi _dropboxApi = DropboxApi(_auth);
  late final LineupService _lineup = LineupService(
    pointerService: _pointers,
    dropboxApi: _dropboxApi,
  );
  late final ScheduleService _schedule = ScheduleService(
    pointerService: _pointers,
    dropboxApi: _dropboxApi,
  );
  late final DescriptionMapService _descriptions = DescriptionMapService(
    pointerService: _pointers,
    dropboxApi: _dropboxApi,
  );

  bool _dropboxConnected = false;
  String _dropboxLabel = '';
  bool _connecting = false;

  /// After first-launch festival create, keep onboarding until Dropbox links.
  bool _pendingDropboxOnboarding = false;

  FestivalWorkspace? get _workspace => _registry?.active;

  bool get _showOnboarding {
    final registry = _registry;
    if (registry == null) return false;
    if (registry.needsFestivalSetup) return true;
    return _pendingDropboxOnboarding && !_dropboxConnected;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var registry = await _store.loadRegistry();
    var active = registry.active;
    if (active.testingPointerUrl.isNotEmpty && active.bandListUrl.isEmpty) {
      try {
        active = active.productionPointerUrl.trim().isEmpty
            ? await _pointers.applyTestingPointer(active)
            : await _pointers.applyPointers(active);
        registry = registry.upsertActive(active);
        await _store.saveRegistry(registry);
      } catch (_) {}
    }
    final connected = await _auth.isConnected;
    final label = connected ? await _auth.accountLabel() : '';
    setState(() {
      _registry = registry;
      _dropboxConnected = connected;
      _dropboxLabel = label;
    });
    if (connected) {
      unawaited(_validateFolderPathCacheInBackground(registry.activeFestivalId));
    }
  }

  bool _workspaceHasFolderUrls(FestivalWorkspace workspace) {
    return workspace.bandListUrl.trim().isNotEmpty ||
        workspace.scheduleUrl.trim().isNotEmpty ||
        workspace.descriptionMapUrl.trim().isNotEmpty ||
        workspace.testingPointerUrl.trim().isNotEmpty ||
        workspace.productionPointerUrl.trim().isNotEmpty ||
        workspace.alertFolderUrl.trim().isNotEmpty;
  }

  /// Validate cached Dropbox folder paths against share URLs without blocking UI.
  ///
  /// On load the cached paths are shown immediately. If this probe finds stale
  /// cache or changed access flags, persisted data is updated and [setState]
  /// refreshes the UI silently (no snackbar).
  Future<void> _validateFolderPathCacheInBackground(String festivalId) async {
    if (!_dropboxConnected) return;
    final snapshot = _registry;
    if (snapshot == null || snapshot.activeFestivalId != festivalId) return;
    final before = snapshot.active;
    if (!_workspaceHasFolderUrls(before)) return;
    try {
      final probed = await FestivalCreateService.probeFullWorkspaceAccess(
        before,
        _dropboxApi,
      );
      if (!mounted) return;
      final current = _registry;
      if (current == null || current.activeFestivalId != festivalId) return;
      if (!FestivalFolderPathCache.backgroundProbeDiffers(before, probed)) {
        return;
      }
      final registry = current.upsertActive(probed);
      if (FestivalFolderPathCache.persistedProbeDiffers(before, probed)) {
        await _store.saveRegistry(registry);
      }
      setState(() => _registry = registry);
    } catch (_) {
      // Keep cached paths; user can Refresh file access later.
    }
  }

  Future<void> _save(FestivalWorkspace workspace) async {
    final registry = (_registry ?? await _store.loadRegistry()).upsertActive(workspace);
    await _store.saveRegistry(registry);
    setState(() => _registry = registry);
  }

  Future<void> _switchFestival(String festivalId) async {
    final current = _workspace;
    // Persist any in-memory identity; settings save handles form fields.
    if (current != null) {
      try {
        if (current.canEditSchedule && current.scheduleUrl.trim().isNotEmpty) {
          await _schedule.flushSync(current);
        }
      } catch (e) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Schedule sync before switch failed: $e')),
        );
      }
      await _store.saveRegistry(
        (_registry ?? await _store.loadRegistry()).upsertActive(current),
      );
    }
    // Trust persisted canEdit* for an immediate switch; refresh probes in the
    // background so Dropbox latency does not block the UI.
    final registry = await _store.switchActive(festivalId);
    setState(() => _registry = registry);
    unawaited(_validateFolderPathCacheInBackground(festivalId));
  }

  /// Re-probe Dropbox write flags for [festivalId] without blocking the UI.
  /// No-ops if the user has already switched away before the probe finishes.
  Future<void> _refreshWriteAccessInBackground(String festivalId) async {
    await _validateFolderPathCacheInBackground(festivalId);
  }

  Future<void> _addFestival(FestivalWorkspace workspace) async {
    final registry = await _store.addFestival(seed: workspace);
    setState(() => _registry = registry);
  }

  /// First-launch create replaces the blank placeholder instead of adding a second festival.
  Future<void> _createFestivalFromOnboarding(FestivalWorkspace workspace) async {
    final current = _registry ?? await _store.loadRegistry();
    if (current.festivals.length == 1 && !current.active.isConfigured) {
      final id = current.activeFestivalId;
      final registry = current.upsertActive(workspace.copyWith(id: id));
      await _store.saveRegistry(registry);
      setState(() {
        _registry = registry;
        _pendingDropboxOnboarding = !_dropboxConnected;
      });
      return;
    }
    final registry = await _store.addFestival(seed: workspace);
    setState(() {
      _registry = registry;
      _pendingDropboxOnboarding = !_dropboxConnected;
    });
  }

  Future<void> _deleteFestival(String festivalId) async {
    try {
      final registry = await _store.deleteFestival(festivalId);
      setState(() => _registry = registry);
    } catch (e) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _connectDropbox() async {
    setState(() => _connecting = true);
    try {
      final label = await _auth.connectInteractive();
      final finishingOnboarding = _pendingDropboxOnboarding;
      setState(() {
        _dropboxConnected = true;
        _dropboxLabel = label;
        _pendingDropboxOnboarding = false;
      });
      final active = _workspace;
      if (active != null && _workspaceHasFolderUrls(active)) {
        final festivalId = _registry?.activeFestivalId ?? active.id;
        if (festivalId.isNotEmpty) {
          unawaited(_validateFolderPathCacheInBackground(festivalId));
        }
      }
      if (!finishingOnboarding) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Connected to Dropbox${label.isEmpty ? '' : ': $label'}',
            ),
          ),
        );
      }
    } catch (e) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Dropbox: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnectDropbox() async {
    await _auth.disconnect();
    setState(() {
      _dropboxConnected = false;
      _dropboxLabel = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _workspace;
    final registry = _registry;
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: buildPromoterTheme(),
      home: workspace == null || registry == null
          ? DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.bgTop, AppColors.bgBottom],
                ),
              ),
              child: const Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
            )
          : _showOnboarding
              ? OnboardingScreen(
                  pointerService: _pointers,
                  dropboxApi: _dropboxApi,
                  dropboxConnected: _dropboxConnected,
                  dropboxLabel: _dropboxLabel,
                  dropboxConnecting: _connecting,
                  onCreateFestival: _createFestivalFromOnboarding,
                  onConnectDropbox: _connectDropbox,
                )
              : PortalScreen(
                  key: ValueKey(workspace.id),
                  workspace: workspace,
                  festivalChoices: registry.choices,
                  activeFestivalId: registry.activeFestivalId,
                  pointerService: _pointers,
                  dropboxApi: _dropboxApi,
                  lineupService: _lineup,
                  scheduleService: _schedule,
                  descriptionMapService: _descriptions,
                  dropboxConnected: _dropboxConnected,
                  dropboxLabel: _dropboxLabel,
                  dropboxConnecting: _connecting,
                  onWorkspaceChanged: _save,
                  onSwitchFestival: _switchFestival,
                  onAddFestival: _addFestival,
                  onDeleteFestival: _deleteFestival,
                  onConnectDropbox: _connectDropbox,
                  onDisconnectDropbox: _disconnectDropbox,
                ),
    );
  }
}
