import 'package:flutter/material.dart';
import 'package:promoter_admin/api/workspace_client.dart';

class BandsScreen extends StatefulWidget {
  const BandsScreen({super.key, required this.client});

  final WorkspaceClient client;

  @override
  State<BandsScreen> createState() => _BandsScreenState();
}

class _BandsScreenState extends State<BandsScreen> {
  List<Map<String, dynamic>> _bands = [];
  String? _error;
  bool _loading = true;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _siteCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _siteCtrl.dispose();
    _imageCtrl.dispose();
    _youtubeCtrl.dispose();
    _genreCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bands = await widget.client.listBands();
      setState(() {
        _bands = bands;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addBand() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final result = await widget.client.upsertBand(
        band: {
          'bandName': name,
          'officalSite': _siteCtrl.text.trim().isEmpty
              ? ' '
              : _siteCtrl.text.trim(),
          'imageUrl': _imageCtrl.text.trim().isEmpty
              ? ' '
              : _imageCtrl.text.trim(),
          'youtube': _youtubeCtrl.text.trim().isEmpty
              ? ' '
              : _youtubeCtrl.text.trim(),
          'wikipedia': ' ',
          'metalArchives': '',
          'country': _countryCtrl.text.trim(),
          'genre': _genreCtrl.text.trim(),
          'noteworthy': ' ',
          'priorYears': '',
        },
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Saved')),
      );
      _nameCtrl.clear();
      _descCtrl.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bands'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                Text('Add band', style: Theme.of(context).textTheme.titleMedium),
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Band name *')),
                TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)'), maxLines: 4),
                TextField(controller: _siteCtrl, decoration: const InputDecoration(labelText: 'Official site')),
                TextField(controller: _imageCtrl, decoration: const InputDecoration(labelText: 'Image URL')),
                TextField(controller: _youtubeCtrl, decoration: const InputDecoration(labelText: 'YouTube')),
                TextField(controller: _genreCtrl, decoration: const InputDecoration(labelText: 'Genre')),
                TextField(controller: _countryCtrl, decoration: const InputDecoration(labelText: 'Country')),
                const SizedBox(height: 8),
                FilledButton(onPressed: _addBand, child: const Text('Save band')),
                const Divider(height: 32),
                Text('Lineup (${_bands.length})', style: Theme.of(context).textTheme.titleMedium),
                ..._bands.map(
                  (b) => ListTile(
                    title: Text(b['bandName']?.toString() ?? ''),
                    subtitle: Text(b['genre']?.toString() ?? ''),
                  ),
                ),
              ],
            ),
    );
  }
}
