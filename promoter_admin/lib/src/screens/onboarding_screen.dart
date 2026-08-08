import 'package:flutter/material.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/screens/create_festival_dialog.dart';
import 'package:promoter_admin/src/screens/festival_setup_choice.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/emergency_local_mode_support.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';
import 'package:promoter_admin/src/services/festival_setup_service.dart';
import 'package:promoter_admin/src/services/pointer_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/layout_breakpoints.dart';

enum _OnboardingStep { connectDropbox, choosePath, configure }

/// First-launch gate: connect Dropbox, then choose how to set up a festival.
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
  late _OnboardingStep _step;
  FestivalSetupPath? _path;
  bool _busy = false;
  String? _error;
  String? _status;

  FestivalSetupService get _setup => FestivalSetupService(
        pointerService: widget.pointerService,
        dropboxApi: widget.dropboxApi,
      );

  @override
  void initState() {
    super.initState();
    _step = widget.dropboxConnected
        ? _OnboardingStep.choosePath
        : _OnboardingStep.connectDropbox;
  }

  @override
  void didUpdateWidget(covariant OnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.dropboxConnected &&
        widget.dropboxConnected &&
        _step == _OnboardingStep.connectDropbox) {
      setState(() {
        _step = _OnboardingStep.choosePath;
        _error = null;
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

  Future<void> _useLocalFileMode() async {
    final nameController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Use files on this computer only?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Local File Mode is not recommended for normal use. Only enable '
              'it if your festival chooses not to use Dropbox or can no longer '
              'use Dropbox.\n\n'
              'You will map CSV files and folders yourself in Settings.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Festival name',
                hintText: 'Maryland Deathfest',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I understand — continue'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    nameController.dispose();
    if (ok != true || !mounted) return;
    if (name.isEmpty) {
      setState(() => _error = 'Festival name is required for Local File Mode.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Starting Local File Mode…';
    });
    try {
      await widget.onCreateFestival(
        FestivalWorkspace(
          festivalName: name,
          emergencyLocalMode: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
        _status = null;
      });
    }
  }

  void _choosePath(FestivalSetupPath path) {
    setState(() {
      _path = path;
      _step = _OnboardingStep.configure;
      _error = null;
      _status = null;
    });
  }

  void _backToChoices() {
    setState(() {
      _path = null;
      _step = _OnboardingStep.choosePath;
      _error = null;
      _status = null;
    });
  }

  Future<void> _joinWithSetupLink(String url) async {
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Loading festival setup…';
    });
    try {
      final created = await _setup.importFromUrl(
        url,
        dropboxConnected: widget.dropboxConnected,
      );
      await widget.onCreateFestival(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
        _status = null;
      });
    }
  }

  Future<void> _handleCreate(CreateFestivalResult result) async {
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
      late final FestivalWorkspace created;
      if (result.createPointerFiles) {
        created = await FestivalCreateService(widget.dropboxApi).createFestival(
          festivalName: result.name,
          eventYear: result.eventYear,
          filePrefix: result.filePrefix,
        );
      } else {
        created = await _setup.materializeManualLinks(
          festivalName: result.name,
          testingPointerUrl: result.testingPointerUrl,
          productionPointerUrl: result.productionPointerUrl,
          reportsFolderUrl: result.reportsFolderUrl,
          alertFolderUrl: result.alertFolderUrl,
          dropboxConnected: widget.dropboxConnected,
        );
      }
      await widget.onCreateFestival(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
        _status = null;
      });
    }
  }

  String get _subtitle {
    switch (_step) {
      case _OnboardingStep.connectDropbox:
        return 'Connect Dropbox to get started.';
      case _OnboardingStep.choosePath:
        return 'Choose how to set up your festival.';
      case _OnboardingStep.configure:
        switch (_path) {
          case FestivalSetupPath.joinWithSetupLink:
            return 'Join with a setup link.';
          case FestivalSetupPath.pasteLinks:
            return 'Enter your festival links.';
          case FestivalSetupPath.createNew:
            return 'Create a brand-new festival.';
          case null:
            return 'Set up your festival.';
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);
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
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 24,
                  vertical: compact ? 16 : 32,
                ),
                children: [
                  Image.asset(
                    AppBrand.logoAsset,
                    height: compact ? 56 : 72,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: compact ? 12 : 16),
                  Text(
                    AppBrand.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.heading,
                      fontSize: compact ? 20 : 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: compact ? 13 : 14,
                    ),
                  ),
                  SizedBox(height: compact ? 20 : 28),
                  _StepHeader(
                    step: 1,
                    title: 'Connect Dropbox',
                    active: _step == _OnboardingStep.connectDropbox,
                    done: _step != _OnboardingStep.connectDropbox,
                  ),
                  const SizedBox(height: 10),
                  _StepHeader(
                    step: 2,
                    title: 'Set up festival',
                    active: _step != _OnboardingStep.connectDropbox,
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
                      padding: EdgeInsets.all(compact ? 14 : 20),
                      child: _busy
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accent,
                                ),
                              ),
                            )
                          : switch (_step) {
                              _OnboardingStep.connectDropbox => _DropboxStep(
                                  connected: widget.dropboxConnected,
                                  label: widget.dropboxLabel,
                                  connecting: widget.dropboxConnecting,
                                  onConnect: _connectDropbox,
                                  onUseLocalFileMode:
                                      emergencyLocalFileModeSupported
                                          ? _useLocalFileMode
                                          : null,
                                ),
                              _OnboardingStep.choosePath =>
                                FestivalSetupChoiceList(
                                  onChosen: _choosePath,
                                ),
                              _OnboardingStep.configure =>
                                _buildConfigureBody(),
                            },
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

  Widget _buildConfigureBody() {
    switch (_path) {
      case FestivalSetupPath.joinWithSetupLink:
        return JoinFestivalSetupForm(
          onSubmit: _joinWithSetupLink,
          onBack: _backToChoices,
        );
      case FestivalSetupPath.pasteLinks:
        return CreateFestivalForm(
          dropboxConnected: widget.dropboxConnected,
          mode: CreateFestivalMode.pasteLinks,
          submitLabel: 'Continue',
          onSubmit: _handleCreate,
          onCancel: _backToChoices,
        );
      case FestivalSetupPath.createNew:
        return CreateFestivalForm(
          dropboxConnected: widget.dropboxConnected,
          mode: CreateFestivalMode.createNew,
          submitLabel: 'Create festival files',
          onSubmit: _handleCreate,
          onCancel: _backToChoices,
        );
      case null:
        return FestivalSetupChoiceList(onChosen: _choosePath);
    }
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
    this.onUseLocalFileMode,
  });

  final bool connected;
  final String label;
  final bool connecting;
  final Future<void> Function() onConnect;
  final Future<void> Function()? onUseLocalFileMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Connect your Dropbox account',
          style: TextStyle(
            color: AppColors.heading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Use a Dropbox account you own and can sign into. This account can '
          'be granted write access to all needed files by the primary festival '
          'administrator with your Dropbox login email.',
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
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
            text: 'Dropbox connected — continue to festival setup…',
          ),
        if (!connected) ...[
          if (onUseLocalFileMode != null) ...[
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: connecting ? null : () => onUseLocalFileMode!(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.muted,
                  ),
                ),
                child: const Text('Use files on this computer only'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Local File Mode is available on Mac and Windows. '
              'It is not available on iPad or iPhone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            const Text(
              'Local File Mode (files on this computer only) is available on '
              'Mac and Windows. It is not available on iPad or iPhone — '
              'use Dropbox on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
