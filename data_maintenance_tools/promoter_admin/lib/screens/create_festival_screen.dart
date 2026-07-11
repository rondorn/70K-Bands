import 'package:flutter/material.dart';
import 'package:promoter_admin/api/workspace_client.dart';

class CreateFestivalScreen extends StatefulWidget {
  const CreateFestivalScreen({super.key, required this.client});

  final WorkspaceClient client;

  @override
  State<CreateFestivalScreen> createState() => _CreateFestivalScreenState();
}

class _CreateFestivalScreenState extends State<CreateFestivalScreen> {
  final _nameCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _folderCtrl = TextEditingController();
  String? _message;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yearCtrl.dispose();
    _folderCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await widget.client.createFestival(
        festivalName: _nameCtrl.text.trim(),
        eventYear: _yearCtrl.text.trim(),
        dropboxFolder: _folderCtrl.text.trim(),
      );
      setState(() {
        _message =
            'Created.\nTesting: ${result['testing_pointer_url']}\n'
            'Production: ${result['production_pointer_url']}';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create festival')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Requires Dropbox connected in the Flask Config UI. '
            'Creates empty CSVs, descriptions folder, and dual pointers.',
          ),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Festival name'),
          ),
          TextField(
            controller: _yearCtrl,
            decoration: const InputDecoration(labelText: 'Event year'),
          ),
          TextField(
            controller: _folderCtrl,
            decoration: const InputDecoration(
              labelText: 'Dropbox folder API path',
              hintText: '/Festivals/MyFest/2027',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: Text(_busy ? 'Creating…' : 'Create on Dropbox'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
