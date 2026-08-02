import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/services/emergency_local_mode_support.dart';
import 'package:promoter_admin/src/services/local_content_store.dart';
import 'package:promoter_admin/src/services/promote_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';
import 'package:promoter_admin/src/widgets/centered_when_wrapped.dart';
import 'package:promoter_admin/src/widgets/layout_breakpoints.dart';
import 'package:promoter_admin/src/widgets/recent_alerts_list.dart';

/// Freeform push alert composer.
///
/// Nav visibility: [FestivalWorkspace.customAlertsUiEnabled]
/// (`allowCustomAlerts` flag or pointer write access).
/// Send requires alert-folder write ([FestivalWorkspace.canEditAlerts]).
class AlertsSection extends StatefulWidget {
  const AlertsSection({
    super.key,
    required this.workspace,
    required this.dropboxApi,
    required this.dropboxConnected,
    required this.onConnectDropbox,
  });

  final FestivalWorkspace workspace;
  final DropboxApi dropboxApi;
  final bool dropboxConnected;
  final Future<void> Function() onConnectDropbox;

  @override
  State<AlertsSection> createState() => _AlertsSectionState();
}

class _AlertsSectionState extends State<AlertsSection> {
  final _message = TextEditingController();
  String? _status;
  String? _error;
  bool _busy = false;
  int _alertsRefreshToken = 0;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() {
        _error = 'Enter the exact notification text to send.';
        _status = null;
      });
      return;
    }

    if (!widget.workspace.usesEmergencyLocalMode && !widget.dropboxConnected) {
      await widget.onConnectDropbox();
      return;
    }

    if (widget.workspace.usesEmergencyLocalMode) {
      final dir = widget.workspace.emergencyLocalPaths.alertsDir.trim();
      if (dir.isEmpty) {
        setState(() {
          _error = 'Set an Alerts folder path in Settings and Save.';
          _status = null;
        });
        return;
      }
    } else {
      final folder = widget.workspace.alertFolderUrl.trim();
      if (folder.isEmpty) {
        setState(() {
          _error =
              'Set an Alert folder URL in Settings and Save (write access required).';
          _status = null;
        });
        return;
      }
    }
    if (!widget.workspace.effectiveCanEditAlerts) {
      setState(() {
        _error =
            'No write access to the alert folder. Fix access in Settings, then Save.';
        _status = null;
      });
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CustomAlertConfirmDialog(
        festivalName: widget.workspace.displayName,
        message: text,
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _status = 'Queuing alert…';
    });
    try {
      final fileName =
          PromoteService.customAlertPendingFileName(DateTime.now());
      if (widget.workspace.usesEmergencyLocalMode) {
        await LocalContentStore.writeAlertPendingFile(
          alertsDir: widget.workspace.emergencyLocalPaths.alertsDir,
          fileName: fileName,
          text: '$text\n',
        );
      } else {
        await widget.dropboxApi.uploadTextInFolder(
          folderShareUrl: widget.workspace.alertFolderUrl.trim(),
          fileName: fileName,
          text: '$text\n',
        );
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status =
            'Queued $fileName. All app users will receive this text once it is sent. '
            'Processing can take up to 10 minutes.';
        _message.clear();
        _alertsRefreshToken++;
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
    final emergency = widget.workspace.usesEmergencyLocalMode;
    final hasFolder = emergency
        ? widget.workspace.emergencyLocalPaths.alertsDir.trim().isNotEmpty
        : widget.workspace.alertFolderUrl.trim().isNotEmpty;
    final canWrite = widget.workspace.effectiveCanEditAlerts;

    return SingleChildScrollView(
      child: PortalPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_status != null) StatusBanner(text: _status!),
            if (_error != null) StatusBanner(text: _error!, isError: true),
            const StatusBanner(
              text:
                  'This message will be pushed to ALL users of the festival app. '
                  'Spell-check carefully and confirm facts — once it goes out, '
                  'there is no way to claw it back.',
              isError: true,
            ),
            const Text(
              'The text below is sent exactly as written (plain text). '
              'Queueing writes a pending file to your alert folder; '
              'delivery happens on the push machine shortly after.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            if (!emergency && !widget.dropboxConnected)
              const StatusBanner(
                text: 'Connect Dropbox in Settings before sending an alert.',
                isError: true,
              ),
            if (!hasFolder)
              StatusBanner(
                text: emergency
                    ? 'Set Alerts folder path in Settings and Save before sending alerts.'
                    : 'Set Alert folder in Settings and Save before sending alerts.',
                isError: true,
              )
            else if (!canWrite)
              StatusBanner(
                text: emergency
                    ? 'Alerts folder path is set but was not verified as writable. Save configuration in Settings.'
                    : 'Alert folder is set but write access was not verified. '
                        'Connect Dropbox and Save configuration in Settings.',
                isError: true,
              ),
            FormRow(
              label: 'Message',
              requiredField: true,
              child: TextField(
                controller: _message,
                maxLines: 8,
                enabled: !_busy,
                decoration: const InputDecoration(
                  hintText: 'Exact text every user will see…',
                ),
              ),
            ),
            const SizedBox(height: 8),
            CenteredWhenWrapped(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: _busy ||
                          (!emergency && !widget.dropboxConnected) ||
                          !hasFolder ||
                          !canWrite
                      ? null
                      : _send,
                  child: Text(_busy ? 'Queuing…' : 'Queue alert for all users'),
                ),
              ],
            ),
            if (hasFolder && !emergency) ...[
              const SizedBox(height: 28),
              RecentAlertsList(
                dropboxApi: widget.dropboxApi,
                folderShareUrl: widget.workspace.alertFolderUrl,
                dropboxConnected: widget.dropboxConnected,
                refreshToken: _alertsRefreshToken,
              ),
            ] else if (hasFolder && emergency) ...[
              const SizedBox(height: 28),
              const Text(
                'Recent alerts are not listed in Local File Mode. '
                'Check pending files in your mapped alerts folder.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomAlertConfirmDialog extends StatefulWidget {
  const _CustomAlertConfirmDialog({
    required this.festivalName,
    required this.message,
  });

  final String festivalName;
  final String message;

  @override
  State<_CustomAlertConfirmDialog> createState() =>
      _CustomAlertConfirmDialogState();
}

class _CustomAlertConfirmDialogState extends State<_CustomAlertConfirmDialog> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Confirm push to all users'),
      content: SizedBox(
        width: dialogContentWidth(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusBanner(
                text:
                    'ALL users of “${widget.festivalName}” will see this message. '
                    'Spell-check and proofread first — there is no clawing it back '
                    'after it is sent.',
                isError: true,
              ),
              const Text(
                'Message to send:',
                style: TextStyle(
                  color: AppColors.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgBottom,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.navBorder),
                ),
                child: SelectableText(
                  widget.message,
                  style: const TextStyle(
                    color: AppColors.heading,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                title: const Text(
                  'I have spell-checked this text and understand every user will see it',
                  style: TextStyle(color: AppColors.heading, fontSize: 14),
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
          onPressed: _confirmed ? () => Navigator.pop(context, true) : null,
          child: const Text('Queue alert'),
        ),
      ],
    );
  }
}
