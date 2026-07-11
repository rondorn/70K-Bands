import 'package:flutter/material.dart';
import 'package:promoter_admin/api/workspace_client.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.client});

  final WorkspaceClient client;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Map<String, dynamic>> _events = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await widget.client.listSchedule();
      setState(() {
        _events = events;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                Text(
                  'Schedule entry with special-event descriptions is available in the web UI; '
                  'this list reads testing schedule via GET /api/schedule.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ..._events.map(
                  (e) => ListTile(
                    title: Text(e['Band']?.toString() ?? ''),
                    subtitle: Text(
                      '${e['Type'] ?? ''} · ${e['Location'] ?? ''} · ${e['Date'] ?? ''} ${e['Start Time'] ?? ''}',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
