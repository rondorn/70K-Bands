import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/dropbox_folder_access.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/dropbox_folder_access_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

Future<void> showGrantFolderAccessDialog({
  required BuildContext context,
  required DropboxFolderAccessService accessService,
  required FestivalWorkspace workspace,
  required FestivalAccessFolderKind kind,
}) async {
  final emailController = TextEditingController();
  var busy = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> submit() async {
          final email = emailController.text.trim();
          if (email.isEmpty) {
            setState(() => error = 'Email is required.');
            return;
          }
          setState(() {
            busy = true;
            error = null;
          });
          try {
            await accessService.grantEditorAccess(
              workspace: workspace,
              kind: kind,
              email: email,
            );
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Dropbox invited $email to ${kind.settingsLabel} files.',
                  ),
                ),
              );
            }
          } catch (e) {
            setState(() {
              busy = false;
              error = e.toString();
            });
          }
        }

        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text(kind.grantButtonLabel),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Dropbox will email an invitation. The recipient must accept '
                  'before they can edit ${kind.settingsLabel.toLowerCase()} files.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (error != null) ...[
                  StatusBanner(text: error!, isError: true),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Collaborator email',
                    hintText: 'editor@example.com',
                  ),
                  onSubmitted: (_) {
                    if (!busy) submit();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(busy ? 'Sending…' : 'Send invite'),
            ),
          ],
        );
      },
    ),
  );
  emailController.dispose();
}

Future<void> showFolderMembersDialog({
  required BuildContext context,
  required DropboxFolderAccessService accessService,
  required FestivalWorkspace workspace,
  required FestivalAccessFolderKind kind,
}) async {
  var loading = true;
  var busy = false;
  String? error;
  List<DropboxFolderMember> members = const [];
  var started = false;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> load() async {
          setState(() {
            loading = true;
            error = null;
          });
          try {
            final list = await accessService.listMembers(
              workspace: workspace,
              kind: kind,
            );
            setState(() {
              members = list;
              loading = false;
            });
          } catch (e) {
            setState(() {
              loading = false;
              error = e.toString();
            });
          }
        }

        if (!started) {
          started = true;
          load();
        }

        Future<void> revoke(DropboxFolderMember member) async {
          final name = member.displayName.isNotEmpty
              ? member.displayName
              : member.email;
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.panel,
              title: const Text('Revoke access?'),
              content: Text(
                'Remove $name from ${kind.settingsLabel} files? '
                'They will lose Dropbox edit access to that folder.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Revoke'),
                ),
              ],
            ),
          );
          if (ok != true) return;
          setState(() {
            busy = true;
            error = null;
          });
          try {
            await accessService.revokeMember(
              workspace: workspace,
              kind: kind,
              member: member,
            );
            await load();
            setState(() => busy = false);
          } catch (e) {
            setState(() {
              busy = false;
              error = e.toString();
            });
          }
        }

        return AlertDialog(
          backgroundColor: AppColors.panel,
          title: Text('${kind.settingsLabel} folder access'),
          content: SizedBox(
            width: 480,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (error != null) ...[
                        StatusBanner(text: error!, isError: true),
                        const SizedBox(height: 12),
                      ],
                      if (members.isEmpty)
                        const Text(
                          'No members returned for this folder. '
                          'Try Refresh, or reconnect Dropbox if access was granted outside the app.',
                          style: TextStyle(color: AppColors.muted),
                        )
                      else
                        ...members.map(
                          (m) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              m.displayName.isNotEmpty
                                  ? m.displayName
                                  : m.email,
                            ),
                            subtitle: Text(
                              [
                                if (m.email.isNotEmpty) m.email,
                                m.isOwner ? 'Owner' : m.accessLevel,
                              ].join(' · '),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            trailing: m.isOwner || busy
                                ? null
                                : TextButton(
                                    onPressed: () => revoke(m),
                                    child: const Text('Revoke'),
                                  ),
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (!loading)
              TextButton(
                onPressed: busy ? null : load,
                child: const Text('Refresh'),
              ),
          ],
        );
      },
    ),
  );
}
