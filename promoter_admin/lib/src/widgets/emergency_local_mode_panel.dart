import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/emergency_local_paths.dart';
import 'package:promoter_admin/src/services/local_content_store.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/centered_when_wrapped.dart';

/// Path map shown only while Local File Mode is active.
class EmergencyLocalModePanel extends StatefulWidget {
  const EmergencyLocalModePanel({
    super.key,
    required this.paths,
    required this.onChanged,
    this.enabled = true,
  });

  final EmergencyLocalPaths paths;
  final ValueChanged<EmergencyLocalPaths> onChanged;
  final bool enabled;

  @override
  State<EmergencyLocalModePanel> createState() => _EmergencyLocalModePanelState();
}

class _EmergencyLocalModePanelState extends State<EmergencyLocalModePanel> {
  late final TextEditingController _artists;
  late final TextEditingController _schedule;
  late final TextEditingController _descriptionMap;
  late final TextEditingController _descriptionsDir;
  late final TextEditingController _alertsDir;
  final Map<String, String?> _checkSummaries = {};

  @override
  void initState() {
    super.initState();
    _artists = _controller(widget.paths.artistsCsv, _emit);
    _schedule = _controller(widget.paths.scheduleCsv, _emit);
    _descriptionMap = _controller(widget.paths.descriptionMapCsv, _emit);
    _descriptionsDir = _controller(widget.paths.descriptionsDir, _emit);
    _alertsDir = _controller(widget.paths.alertsDir, _emit);
  }

  TextEditingController _controller(String value, VoidCallback onEdit) {
    final c = TextEditingController(text: value);
    c.addListener(onEdit);
    return c;
  }

  @override
  void didUpdateWidget(covariant EmergencyLocalModePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paths != widget.paths) {
      _syncController(_artists, widget.paths.artistsCsv);
      _syncController(_schedule, widget.paths.scheduleCsv);
      _syncController(_descriptionMap, widget.paths.descriptionMapCsv);
      _syncController(_descriptionsDir, widget.paths.descriptionsDir);
      _syncController(_alertsDir, widget.paths.alertsDir);
    }
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.text = value;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _artists,
      _schedule,
      _descriptionMap,
      _descriptionsDir,
      _alertsDir,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      EmergencyLocalPaths(
        artistsCsv: _artists.text.trim(),
        scheduleCsv: _schedule.text.trim(),
        descriptionMapCsv: _descriptionMap.text.trim(),
        descriptionsDir: _descriptionsDir.text.trim(),
        alertsDir: _alertsDir.text.trim(),
      ),
    );
  }

  Future<void> _pickFile(TextEditingController controller) async {
    if (!widget.enabled) return;
    final picked = await LocalContentStore.pickFile();
    if (picked == null || !mounted) return;
    controller.text = picked;
  }

  Future<void> _pickDirectory(TextEditingController controller) async {
    if (!widget.enabled) return;
    final picked = await LocalContentStore.pickDirectory();
    if (picked == null || !mounted) return;
    controller.text = picked;
  }

  Future<void> _checkPath(
    String key,
    String rawPath, {
    required bool directory,
  }) async {
    final check = await LocalContentStore.checkPath(
      rawPath,
      directory: directory,
    );
    if (!mounted) return;
    setState(() => _checkSummaries[key] = check.summary);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StatusBanner(
          text:
              'Local File Mode is active — not recommended for normal use. '
              'Map each file or folder below. Getting these files to fan apps '
              'is your responsibility outside this app. Turn off Local File Mode '
              'when you switch back to Dropbox.',
          isError: true,
        ),
        const SizedBox(height: 12),
        _PathRow(
          label: 'Artists CSV',
          hint: '/path/to/artistLineup.csv',
          controller: _artists,
          enabled: widget.enabled,
          checkSummary: _checkSummaries['artists'],
          onBrowse: () => _pickFile(_artists),
          onCheck: () => _checkPath('artists', _artists.text, directory: false),
        ),
        _PathRow(
          label: 'Schedule CSV',
          hint: '/path/to/artistSchedule.csv',
          controller: _schedule,
          enabled: widget.enabled,
          checkSummary: _checkSummaries['schedule'],
          onBrowse: () => _pickFile(_schedule),
          onCheck: () => _checkPath('schedule', _schedule.text, directory: false),
        ),
        _PathRow(
          label: 'Description map CSV',
          hint: '/path/to/descriptionMap.csv',
          controller: _descriptionMap,
          enabled: widget.enabled,
          checkSummary: _checkSummaries['map'],
          onBrowse: () => _pickFile(_descriptionMap),
          onCheck: () =>
              _checkPath('map', _descriptionMap.text, directory: false),
        ),
        _PathRow(
          label: 'Descriptions folder',
          hint: '/path/to/description/files',
          controller: _descriptionsDir,
          enabled: widget.enabled,
          checkSummary: _checkSummaries['descriptions'],
          onBrowse: () => _pickDirectory(_descriptionsDir),
          onCheck: () => _checkPath(
            'descriptions',
            _descriptionsDir.text,
            directory: true,
          ),
          pickDirectory: true,
        ),
        _PathRow(
          label: 'Alerts folder (optional)',
          hint: '/path/to/alert/files',
          controller: _alertsDir,
          enabled: widget.enabled,
          checkSummary: _checkSummaries['alerts'],
          onBrowse: () => _pickDirectory(_alertsDir),
          onCheck: () => _checkPath('alerts', _alertsDir.text, directory: true),
          pickDirectory: true,
        ),
      ],
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.enabled,
    required this.onBrowse,
    required this.onCheck,
    this.checkSummary,
    this.pickDirectory = false,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onBrowse;
  final VoidCallback onCheck;
  final String? checkSummary;
  final bool pickDirectory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.label,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            maxLines: 2,
            decoration: InputDecoration(hintText: hint),
          ),
          const SizedBox(height: 6),
          CenteredWhenWrapped(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: enabled ? onBrowse : null,
                child: Text(pickDirectory ? 'Browse folder' : 'Browse file'),
              ),
              OutlinedButton(
                onPressed: enabled ? onCheck : null,
                child: const Text('Check path'),
              ),
            ],
          ),
          if (checkSummary != null) ...[
            const SizedBox(height: 4),
            Text(
              checkSummary!,
              style: TextStyle(
                color: checkSummary!.contains('OK') ||
                        checkSummary!.contains('writable')
                    ? AppColors.muted
                    : AppColors.accent,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact toggle for Local File Mode (Settings action row).
class EmergencyLocalModeToggleButton extends StatelessWidget {
  const EmergencyLocalModeToggleButton({
    super.key,
    required this.emergencyLocalMode,
    required this.enabled,
    required this.onToggleEmergencyMode,
  });

  final bool emergencyLocalMode;
  final bool enabled;
  final Future<void> Function(bool enable) onToggleEmergencyMode;

  static ButtonStyle _compactStyle({required bool active}) {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 12, height: 1.2),
      foregroundColor: active ? AppColors.accent : AppColors.muted,
      side: BorderSide(
        color: active ? AppColors.accent : AppColors.muted.withValues(alpha: 0.6),
      ),
    );
  }

  Future<void> _onPressed(BuildContext context) async {
    if (!enabled) return;
    if (!emergencyLocalMode) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Enable Local File Mode?'),
          content: const Text(
            'Local File Mode is not recommended for normal use. Only enable it '
            'if your festival chooses not to use Dropbox or can no longer use Dropbox.\n\n'
            'You must map each CSV file and folder yourself. This app will write '
            'valid files to those paths only. Getting those files to fan apps is '
            'your responsibility outside this app.\n\n'
            'Turn off Local File Mode if you switch back to Dropbox.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I understand — enable'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await onToggleEmergencyMode(true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Return to Dropbox mode?'),
        content: const Text(
          'Local File Mode will turn off. Dropbox URLs and connection '
          'settings will be used again. Your mapped local paths are kept but hidden '
          'until you turn on Local File Mode again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Turn off Local File Mode'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await onToggleEmergencyMode(false);
  }

  @override
  Widget build(BuildContext context) {
    final label = emergencyLocalMode
        ? 'Local File Mode on'
        : 'Local File Mode';
    return OutlinedButton(
      style: _compactStyle(active: emergencyLocalMode),
      onPressed: enabled ? () => _onPressed(context) : null,
      child: Text(label),
    );
  }
}
