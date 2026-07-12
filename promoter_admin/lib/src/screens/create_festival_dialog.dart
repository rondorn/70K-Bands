import 'package:flutter/material.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

class CreateFestivalResult {
  const CreateFestivalResult({
    required this.name,
    required this.createPointerFiles,
    this.eventYear = '',
    this.folder = '',
    this.filePrefix = '',
    this.testingPointerUrl = '',
    this.productionPointerUrl = '',
  });

  final String name;

  /// When true, bootstrap Dropbox files + pointers. When false, use provided URLs.
  final bool createPointerFiles;
  final String eventYear;
  final String folder;
  final String filePrefix;
  final String testingPointerUrl;
  final String productionPointerUrl;
}

Future<CreateFestivalResult?> showCreateFestivalDialog({
  required BuildContext context,
  required bool dropboxConnected,
  bool allowCancel = true,
}) {
  return showDialog<CreateFestivalResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Create festival'),
      content: SizedBox(
        width: 520,
        child: CreateFestivalForm(
          dropboxConnected: dropboxConnected,
          onSubmit: (result) => Navigator.pop(context, result),
          onCancel: allowCancel ? () => Navigator.pop(context) : null,
          compactActions: true,
        ),
      ),
    ),
  );
}

/// Shared create-festival fields used by Settings and first-launch onboarding.
class CreateFestivalForm extends StatefulWidget {
  const CreateFestivalForm({
    super.key,
    required this.dropboxConnected,
    required this.onSubmit,
    this.onCancel,
    this.onConnectDropbox,
    this.dropboxConnecting = false,
    this.compactActions = false,
    this.submitLabel,
  });

  final bool dropboxConnected;
  final ValueChanged<CreateFestivalResult> onSubmit;
  final VoidCallback? onCancel;
  final Future<void> Function()? onConnectDropbox;
  final bool dropboxConnecting;
  final bool compactActions;
  final String? submitLabel;

  @override
  State<CreateFestivalForm> createState() => _CreateFestivalFormState();
}

class _CreateFestivalFormState extends State<CreateFestivalForm> {
  late final TextEditingController _name;
  late final TextEditingController _year;
  late final TextEditingController _prefix;
  late final TextEditingController _folder;
  late final TextEditingController _testingPointer;
  late final TextEditingController _productionPointer;

  /// Default false = provide existing pointers.
  bool _createPointerFiles = false;
  String? _error;
  bool _folderTouched = false;
  bool _prefixTouched = false;
  String _lastAutoFolder = '';
  String _lastAutoPrefix = '';

  @override
  void initState() {
    super.initState();
    final year = DateTime.now().year.toString();
    _name = TextEditingController();
    _year = TextEditingController(text: year);
    _prefix = TextEditingController(text: 'fest');
    _folder = TextEditingController(
      text: FestivalCreateService.defaultFolderForName('Festival'),
    );
    _testingPointer = TextEditingController();
    _productionPointer = TextEditingController();
    _lastAutoFolder = _folder.text;
    _lastAutoPrefix = _prefix.text;
    _name.addListener(_onNameChanged);
    _year.addListener(() => setState(() {}));
    _prefix.addListener(() => setState(() {}));
  }

  void _onNameChanged() {
    if (!_prefixTouched) {
      final nextPrefix = FestivalCreateService.defaultFilePrefix(_name.text);
      if (_prefix.text == _lastAutoPrefix || _prefix.text.trim().isEmpty) {
        _prefix.text = nextPrefix;
        _lastAutoPrefix = nextPrefix;
      }
    }
    if (!_folderTouched) {
      final next = FestivalCreateService.defaultFolderForName(_name.text);
      if (_folder.text == _lastAutoFolder || _folder.text.trim().isEmpty) {
        _folder.text = next;
        _lastAutoFolder = next;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    _year.dispose();
    _prefix.dispose();
    _folder.dispose();
    _testingPointer.dispose();
    _productionPointer.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Festival name is required.');
      return;
    }

    if (_createPointerFiles) {
      if (!widget.dropboxConnected) {
        setState(() => _error = 'Connect Dropbox first to create new files.');
        return;
      }
      final year = _year.text.trim();
      final folder = _folder.text.trim();
      final prefix = _prefix.text.trim();
      if (year.isEmpty) {
        setState(() => _error = 'Event year is required.');
        return;
      }
      if (prefix.isEmpty) {
        setState(() => _error = 'File prefix is required.');
        return;
      }
      if (folder.isEmpty) {
        setState(() => _error = 'Dropbox folder path is required.');
        return;
      }
      widget.onSubmit(
        CreateFestivalResult(
          name: name,
          createPointerFiles: true,
          eventYear: year,
          folder: folder,
          filePrefix: prefix,
        ),
      );
      return;
    }

    final testing = _testingPointer.text.trim();
    if (testing.isEmpty) {
      setState(() => _error = 'Testing pointer URL is required.');
      return;
    }
    widget.onSubmit(
      CreateFestivalResult(
        name: name,
        createPointerFiles: false,
        testingPointerUrl: testing,
        productionPointerUrl: _productionPointer.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = _year.text.trim().isEmpty ? '2027' : _year.text.trim();
    final prefix = FestivalCreateService.sanitizeFilePrefix(
      _prefix.text.trim().isEmpty ? 'fest' : _prefix.text,
    );
    final sampleArtists =
        FestivalCreateService.artistLineupName(prefix, year, testing: true);
    final sampleSchedule =
        FestivalCreateService.scheduleName(prefix, year, testing: true);
    final sampleMap =
        FestivalCreateService.descriptionMapName(prefix, year, testing: true);
    final submitLabel = widget.submitLabel ??
        (_createPointerFiles ? 'Create festival files' : 'Add festival');

    final fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Add a festival configuration. By default, paste existing '
          'pointer URLs. Check the box only when you need new Dropbox '
          'files created from scratch.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          StatusBanner(text: _error!, isError: true),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Festival name',
            hintText: 'Maryland Deathfest',
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _createPointerFiles,
          onChanged: (v) => setState(() {
            _createPointerFiles = v ?? false;
            _error = null;
          }),
          title: const Text(
            'Create new pointer files',
            style: TextStyle(color: AppColors.heading, fontSize: 15),
          ),
          subtitle: const Text(
            'Also creates header-only artists / schedule / description map '
            'CSVs (testing + production) on Dropbox.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        if (!_createPointerFiles) ...[
          TextField(
            controller: _testingPointer,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Testing pointer URL',
              hintText:
                  'https://www.dropbox.com/.../productionPointer_test.txt?raw=1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _productionPointer,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Production pointer URL',
              hintText:
                  'https://www.dropbox.com/.../productionPointer.txt?raw=1',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Production pointer is used for venues / dates / event types. '
            'Optional if you only have a testing pointer.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ] else ...[
          if (!widget.dropboxConnected) ...[
            const StatusBanner(
              text: 'Connect Dropbox before creating new festival files.',
              isError: true,
            ),
            if (widget.onConnectDropbox != null) ...[
              const SizedBox(height: 10),
              FilledButton(
                onPressed: widget.dropboxConnecting
                    ? null
                    : () async {
                        setState(() => _error = null);
                        await widget.onConnectDropbox!();
                      },
                child: Text(
                  widget.dropboxConnecting
                      ? 'Connecting…'
                      : 'Connect Dropbox',
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _year,
            decoration: const InputDecoration(
              labelText: 'Event year',
              hintText: '2027',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prefix,
            decoration: const InputDecoration(
              labelText: 'File prefix',
              hintText: 'mdf',
            ),
            onChanged: (_) {
              _prefixTouched = true;
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 6),
          Text(
            'Filenames: $sampleArtists, $sampleSchedule, $sampleMap '
            '(+ production copies without _test).',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _folder,
            decoration: const InputDecoration(
              labelText: 'Dropbox folder',
              hintText: '/FestivalName_Public',
            ),
            onChanged: (_) {
              _folderTouched = true;
            },
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 6),
          const Text(
            'Defaults to /{Festival name}_Public.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 20),
        if (widget.compactActions)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              FilledButton(
                onPressed: _submit,
                child: Text(submitLabel),
              ),
            ],
          )
        else ...[
          FilledButton(
            onPressed: _submit,
            child: Text(submitLabel),
          ),
          if (widget.onCancel != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ],
      ],
    );

    if (widget.compactActions) {
      return SingleChildScrollView(child: fields);
    }
    return fields;
  }
}
