import 'package:flutter/material.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

class ImportDescriptionsFolderRequest {
  const ImportDescriptionsFolderRequest({
    required this.folderUrl,
    required this.overrideExisting,
  });

  final String folderUrl;
  final bool overrideExisting;
}

Future<ImportDescriptionsFolderRequest?> showImportDescriptionsFolderDialog({
  required BuildContext context,
}) {
  return showDialog<ImportDescriptionsFolderRequest>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _ImportDescriptionsFolderDialog(),
  );
}

class _ImportDescriptionsFolderDialog extends StatefulWidget {
  const _ImportDescriptionsFolderDialog();

  @override
  State<_ImportDescriptionsFolderDialog> createState() =>
      _ImportDescriptionsFolderDialogState();
}

class _ImportDescriptionsFolderDialogState
    extends State<_ImportDescriptionsFolderDialog> {
  final _url = TextEditingController();
  bool _overrideExisting = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final folderUrl = _url.text.trim();
    if (folderUrl.isEmpty) {
      setState(() => _error = 'A Dropbox folder URL is required.');
      return;
    }
    Navigator.pop(
      context,
      ImportDescriptionsFolderRequest(
        folderUrl: folderUrl,
        overrideExisting: _overrideExisting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Import from Dropbox folder'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HintText(
              'Paste a Dropbox folder link. Each .txt file is matched to the '
              'Testing lineup by name (lathe.txt → Lathe). Files that do not '
              'match a lineup band are ignored. Existing map links are kept '
              'unless you override.',
            ),
            const SizedBox(height: 12),
            if (_error != null) StatusBanner(text: _error!, isError: true),
            FormRow(
              label: 'Folder URL',
              requiredField: true,
              child: TextField(
                controller: _url,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'https://www.dropbox.com/scl/fo/...',
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            CheckboxListTile(
              value: _overrideExisting,
              onChanged: (value) {
                setState(() => _overrideExisting = value ?? false);
              },
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.accent,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Override existing',
                style: TextStyle(color: AppColors.heading, fontSize: 15),
              ),
              subtitle: const Text(
                'Off (default): keep current map links. On: replace them '
                'with these files.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Import'),
        ),
      ],
    );
  }
}
