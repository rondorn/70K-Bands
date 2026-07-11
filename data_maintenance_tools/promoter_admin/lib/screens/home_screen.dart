import 'package:flutter/material.dart';
import 'package:promoter_admin/api/workspace_client.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.client});

  final WorkspaceClient client;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _workspace;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.client.getWorkspace();
      setState(() {
        _workspace = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _workspace?['festival_name']?.toString().isNotEmpty == true
        ? _workspace!['festival_name'].toString()
        : 'Festival Promoter Admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Cannot reach API at ${widget.client.baseUrl}\n$_error\n\n'
                        'Start the Flask server (run.sh / run.bat) first.',
                      ),
                    ),
                  ),
                if (_workspace != null) ...[
                  Text('Testing pointer',
                      _workspace!['testing_pointer_url']?.toString() ?? ''),
                  Text('Production pointer',
                      _workspace!['production_pointer_url']?.toString() ?? ''),
                  Text('Event year',
                      _workspace!['event_year']?.toString() ?? ''),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/bands'),
                  child: const Text('Bands'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => Navigator.pushNamed(context, '/schedule'),
                  child: const Text('Schedule'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => Navigator.pushNamed(context, '/promote'),
                  child: const Text('Promote to production'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/create'),
                  child: const Text('Create festival on Dropbox'),
                ),
              ],
            ),
    );
  }
}
