import 'package:flutter/material.dart';
import 'package:promoter_admin/api/workspace_client.dart';

class PromoteScreen extends StatefulWidget {
  const PromoteScreen({super.key, required this.client});

  final WorkspaceClient client;

  @override
  State<PromoteScreen> createState() => _PromoteScreenState();
}

class _PromoteScreenState extends State<PromoteScreen> {
  String? _message;
  String? _error;
  bool _busy = false;

  Future<void> _promote() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await widget.client.promote();
      setState(() {
        _message = (result['summary'] as List?)?.join('\n') ??
            (result['messages'] as List?)?.join('\n') ??
            'Promoted.';
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
      appBar: AppBar(title: const Text('Promote')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Copies testing lineup, schedule, and description map onto the '
              'files referenced by the production pointer.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _promote,
              child: Text(_busy ? 'Promoting…' : 'Promote testing → production'),
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
      ),
    );
  }
}
