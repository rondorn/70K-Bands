import 'package:flutter/material.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/screens/create_festival_dialog.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

enum _OnboardingStep { createFestival, connectDropbox }

/// First-launch gate: create a festival, then connect Dropbox, before the portal.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.pointerService,
    required this.dropboxApi,
    required this.dropboxConnected,
    required this.dropboxLabel,
    required this.dropboxConnecting,
    required this.onCreateFestival,
    required this.onConnectDropbox,
  });

  final PointerService pointerService;
  final DropboxApi dropboxApi;
  final bool dropboxConnected;
  final String dropboxLabel;
  final bool dropboxConnecting;
  final Future<void> Function(FestivalWorkspace workspace) onCreateFestival;
  final Future<void> Function() onConnectDropbox;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  _OnboardingStep _step = _OnboardingStep.createFestival;
  bool _busy = false;
  String? _error;
  String? _status;

  @override
  void didUpdateWidget(covariant OnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_step == _OnboardingStep.connectDropbox &&
        !oldWidget.dropboxConnected &&
        widget.dropboxConnected) {
      // Parent will swap to the portal once both gates pass.
    }
  }

  Future<void> _handleCreate(CreateFestivalResult result) async {
    if (result.createPointerFiles && !widget.dropboxConnected) {
      setState(() {
        _error = 'Connect Dropbox before creating new festival links and data files.';
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
      await widget.onCreateFestival(created);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _step = _OnboardingStep.connectDropbox;
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

  Future<void> _connectDropbox() async {
    setState(() {
      _error = null;
      _status = null;
    });
    try {
      await widget.onConnectDropbox();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgTop, AppColors.bgBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                children: [
                  Image.asset(
                    AppBrand.logoAsset,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppBrand.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set up Testing and Production links, then connect Dropbox.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  _StepHeader(
                    step: 1,
                    title: 'Create festival',
                    active: _step == _OnboardingStep.createFestival,
                    done: _step == _OnboardingStep.connectDropbox,
                  ),
                  const SizedBox(height: 10),
                  _StepHeader(
                    step: 2,
                    title: 'Connect Dropbox',
                    active: _step == _OnboardingStep.connectDropbox,
                    done: false,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    StatusBanner(text: _error!, isError: true),
                    const SizedBox(height: 12),
                  ],
                  if (_status != null) ...[
                    StatusBanner(text: _status!),
                    const SizedBox(height: 12),
                  ],
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.panelBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                          : _step == _OnboardingStep.createFestival
                              ? CreateFestivalForm(
                                  dropboxConnected: widget.dropboxConnected,
                                  dropboxConnecting: widget.dropboxConnecting,
                                  onConnectDropbox: widget.onConnectDropbox,
                                  submitLabel: 'Continue',
                                  onSubmit: _handleCreate,
                                )
                              : _DropboxStep(
                                  connected: widget.dropboxConnected,
                                  label: widget.dropboxLabel,
                                  connecting: widget.dropboxConnecting,
                                  onConnect: _connectDropbox,
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.active,
    required this.done,
  });

  final int step;
  final String title;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? AppColors.successText
        : active
            ? AppColors.accent
            : AppColors.muted;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? color.withValues(alpha: 0.2) : AppColors.inputBg,
            border: Border.all(color: color),
          ),
          child: Text(
            done ? '✓' : '$step',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: active || done ? AppColors.heading : AppColors.muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _DropboxStep extends StatelessWidget {
  const _DropboxStep({
    required this.connected,
    required this.label,
    required this.connecting,
    required this.onConnect,
  });

  final bool connected;
  final String label;
  final bool connecting;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Dropbox is required to load and save lineup, schedule, and '
          'description files.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Text(
          connected
              ? 'Connected${label.isEmpty ? '' : ': $label'}'
              : 'Not connected',
          style: const TextStyle(color: AppColors.heading, fontSize: 15),
        ),
        const SizedBox(height: 16),
        if (!connected)
          FilledButton(
            onPressed: connecting ? null : () => onConnect(),
            child: Text(connecting ? 'Connecting…' : 'Connect Dropbox'),
          )
        else
          const StatusBanner(
            text: 'Dropbox connected — opening the festival workspace…',
          ),
      ],
    );
  }
}
