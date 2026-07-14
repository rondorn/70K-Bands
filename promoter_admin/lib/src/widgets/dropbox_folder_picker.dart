import 'package:flutter/material.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

/// Browse Dropbox folders and return the selected API path (or null if cancelled).
Future<String?> showDropboxFolderPicker({
  required BuildContext context,
  required DropboxApi dropboxApi,
  String title = 'Choose Dropbox folder',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _DropboxFolderPickerDialog(
      dropboxApi: dropboxApi,
      title: title,
    ),
  );
}

class _DropboxFolderPickerDialog extends StatefulWidget {
  const _DropboxFolderPickerDialog({
    required this.dropboxApi,
    required this.title,
  });

  final DropboxApi dropboxApi;
  final String title;

  @override
  State<_DropboxFolderPickerDialog> createState() =>
      _DropboxFolderPickerDialogState();
}

class _DropboxFolderPickerDialogState extends State<_DropboxFolderPickerDialog> {
  String _path = '';
  List<DropboxFolderEntry> _folders = [];
  bool _loading = true;
  String? _error;
  final _newFolder = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newFolder.dispose();
    super.dispose();
  }

  String get _displayPath => _path.isEmpty ? '/' : _path;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folders = await widget.dropboxApi.listFolder(_path);
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _open(DropboxFolderEntry folder) {
    setState(() => _path = folder.path);
    _load();
  }

  void _goUp() {
    if (_path.isEmpty) return;
    final idx = _path.lastIndexOf('/');
    setState(() {
      _path = idx <= 0 ? '' : _path.substring(0, idx);
    });
    _load();
  }

  Future<void> _createSubfolder() async {
    final name = _newFolder.text.trim();
    if (name.isEmpty) return;
    final parent = _path.isEmpty ? '' : _path;
    final full = parent.isEmpty ? '/$name' : '$parent/$name';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.dropboxApi.ensureFolder(full);
      _newFolder.clear();
      setState(() => _path = full);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Descriptions will be saved here for this account on this device.',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Up',
                  onPressed: _path.isEmpty || _loading ? null : _goUp,
                  icon: const Icon(Icons.arrow_upward),
                ),
                Expanded(
                  child: Text(
                    _displayPath,
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.errorText)),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.panelBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      )
                    : _folders.isEmpty
                        ? const Center(
                            child: Text(
                              'No subfolders here.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _folders.length,
                            itemBuilder: (context, i) {
                              final f = _folders[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.folder_outlined),
                                title: Text(f.name),
                                onTap: () => _open(f),
                              );
                            },
                          ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newFolder,
                    decoration: const InputDecoration(
                      hintText: 'New subfolder name',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loading ? null : _createSubfolder,
                  child: const Text('Create'),
                ),
              ],
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
          onPressed: _loading
              ? null
              : () {
                  final selected = _path.isEmpty ? '/' : _path;
                  Navigator.pop(context, selected);
                },
          child: const Text('Use this folder'),
        ),
      ],
    );
  }
}
