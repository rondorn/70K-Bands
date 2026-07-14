import 'dart:async';

import 'package:flutter/material.dart';
import 'package:promoter_admin/src/services/dropbox_api.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

enum AlertQueueStatus { pending, completed, failed, other }

enum AlertQueueKind { bandAnnouncement, custom, other }

class AlertQueueItem {
  const AlertQueueItem({
    required this.fileName,
    required this.path,
    required this.status,
    required this.kind,
    this.modified,
  });

  final String fileName;
  final String path;
  final AlertQueueStatus status;
  final AlertQueueKind kind;
  final DateTime? modified;

  bool get canDelete =>
      status == AlertQueueStatus.pending;

  String get statusLabel {
    switch (status) {
      case AlertQueueStatus.pending:
        return 'Pending';
      case AlertQueueStatus.completed:
        return 'Completed';
      case AlertQueueStatus.failed:
        return 'Failed';
      case AlertQueueStatus.other:
        return 'Unknown';
    }
  }

  String get kindLabel {
    switch (kind) {
      case AlertQueueKind.bandAnnouncement:
        return 'Band add';
      case AlertQueueKind.custom:
        return 'Custom';
      case AlertQueueKind.other:
        return 'Other';
    }
  }

  static AlertQueueItem? tryParse(DropboxListedFile file) {
    final name = file.name.trim();
    final lower = name.toLowerCase();
    if (!lower.endsWith('.pending') &&
        !lower.endsWith('.completed') &&
        !lower.endsWith('.failed') &&
        !lower.endsWith('.error') &&
        !lower.endsWith('.processing')) {
      return null;
    }
    // Ignore Dropbox write probes.
    if (lower.startsWith('.omf_write_probe')) return null;

    late final AlertQueueStatus status;
    if (lower.endsWith('.pending') || lower.endsWith('.processing')) {
      status = AlertQueueStatus.pending;
    } else if (lower.endsWith('.completed')) {
      status = AlertQueueStatus.completed;
    } else if (lower.endsWith('.failed') || lower.endsWith('.error')) {
      status = AlertQueueStatus.failed;
    } else {
      status = AlertQueueStatus.other;
    }

    late final AlertQueueKind kind;
    if (lower.startsWith('bandannouncements-')) {
      kind = AlertQueueKind.bandAnnouncement;
    } else if (lower.startsWith('customalert-')) {
      kind = AlertQueueKind.custom;
    } else {
      kind = AlertQueueKind.other;
    }

    return AlertQueueItem(
      fileName: name,
      path: file.path,
      status: status,
      kind: kind,
      modified: file.serverModified,
    );
  }

  /// Newest first; keep at most [limit] alert files.
  static List<AlertQueueItem> fromListedFiles(
    List<DropboxListedFile> files, {
    int limit = 20,
  }) {
    final items = <AlertQueueItem>[];
    for (final file in files) {
      final item = tryParse(file);
      if (item != null) items.add(item);
    }
    items.sort((a, b) {
      final am = a.modified;
      final bm = b.modified;
      if (am != null && bm != null) return bm.compareTo(am);
      if (am != null) return -1;
      if (bm != null) return 1;
      return b.fileName.toLowerCase().compareTo(a.fileName.toLowerCase());
    });
    if (items.length <= limit) return items;
    return items.sublist(0, limit);
  }
}

/// Last-20 alert queue files with optional auto-refresh while pending.
class RecentAlertsList extends StatefulWidget {
  const RecentAlertsList({
    super.key,
    required this.dropboxApi,
    required this.folderShareUrl,
    required this.dropboxConnected,
    this.refreshToken = 0,
  });

  final DropboxApi dropboxApi;
  final String folderShareUrl;
  final bool dropboxConnected;

  /// Bump to force an immediate reload (e.g. after publish).
  final int refreshToken;

  @override
  State<RecentAlertsList> createState() => _RecentAlertsListState();
}

class _RecentAlertsListState extends State<RecentAlertsList> {
  List<AlertQueueItem> _history = const [];
  String? _listError;
  bool _listLoading = false;
  bool _listRefreshing = false;
  Timer? _pollTimer;
  int _historyLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant RecentAlertsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final folderChanged =
        oldWidget.folderShareUrl.trim() != widget.folderShareUrl.trim();
    final connectedChanged =
        oldWidget.dropboxConnected != widget.dropboxConnected;
    final tokenChanged = oldWidget.refreshToken != widget.refreshToken;
    if (folderChanged || connectedChanged || tokenChanged) {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _hasPending =>
      _history.any((i) => i.status == AlertQueueStatus.pending);

  void _syncPolling() {
    if (!mounted) return;
    final shouldPoll = widget.dropboxConnected &&
        widget.folderShareUrl.trim().isNotEmpty &&
        _hasPending;
    if (shouldPoll) {
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) => _loadHistory(silent: true),
      );
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _loadHistory({bool silent = false}) async {
    final folder = widget.folderShareUrl.trim();
    if (!widget.dropboxConnected || folder.isEmpty) {
      _pollTimer?.cancel();
      _pollTimer = null;
      if (!silent && mounted) {
        setState(() {
          _history = const [];
          _listError = null;
          _listLoading = false;
          _listRefreshing = false;
        });
      }
      return;
    }

    final token = ++_historyLoadToken;
    if (!silent && mounted) {
      setState(() {
        _listLoading = _history.isEmpty;
        _listRefreshing = _history.isNotEmpty;
        _listError = null;
      });
    } else if (silent && mounted && !_listRefreshing) {
      setState(() => _listRefreshing = true);
    }

    try {
      final files = await widget.dropboxApi.listFilesInShareFolder(folder);
      if (!mounted || token != _historyLoadToken) return;
      setState(() {
        _history = AlertQueueItem.fromListedFiles(files);
        _listError = null;
        _listLoading = false;
        _listRefreshing = false;
      });
      _syncPolling();
    } catch (e) {
      if (!mounted || token != _historyLoadToken) return;
      setState(() {
        _listLoading = false;
        _listRefreshing = false;
        if (!silent || _history.isEmpty) {
          _listError = e.toString();
        }
      });
      _syncPolling();
    }
  }

  Future<void> _openAlert(AlertQueueItem item) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (context) => _AlertTextDialog(
        item: item,
        dropboxApi: widget.dropboxApi,
      ),
    );
    if (deleted == true && mounted) {
      await _loadHistory();
    }
  }

  String _formatWhen(DateTime? when) {
    if (when == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${when.year}-${two(when.month)}-${two(when.day)} '
        '${two(when.hour)}:${two(when.minute)}';
  }

  Color _statusColor(AlertQueueStatus status) {
    switch (status) {
      case AlertQueueStatus.pending:
        return AppColors.accent;
      case AlertQueueStatus.completed:
        return AppColors.successText;
      case AlertQueueStatus.failed:
        return AppColors.errorText;
      case AlertQueueStatus.other:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFolder = widget.folderShareUrl.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent alerts',
                style: TextStyle(
                  color: AppColors.label,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            if (_listRefreshing)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
            OutlinedButton(
              onPressed: (!widget.dropboxConnected || !hasFolder)
                  ? null
                  : () => _loadHistory(),
              child: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const HintText(
          'Showing the last 20 alert files. Tap a file to read the message text. '
          'Pending alerts can take up to 10 minutes to process (and can be deleted '
          'from the text view). This list refreshes every 10 seconds while any '
          'pending alerts remain.',
        ),
        if (_listError != null) ...[
          const SizedBox(height: 8),
          StatusBanner(text: _listError!, isError: true),
        ],
        if (_listLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          )
        else if (_history.isEmpty &&
            widget.dropboxConnected &&
            hasFolder &&
            _listError == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No alert files in this folder yet.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          )
        else if (_history.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final item in _history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppColors.bgBottom,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openAlert(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.navBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.fileName,
                                style: const TextStyle(
                                  color: AppColors.heading,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  item.kindLabel,
                                  if (_formatWhen(item.modified).isNotEmpty)
                                    _formatWhen(item.modified),
                                  'Tap to view',
                                ].join(' · '),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.statusLabel,
                          style: TextStyle(
                            color: _statusColor(item.status),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _AlertTextDialog extends StatefulWidget {
  const _AlertTextDialog({
    required this.item,
    required this.dropboxApi,
  });

  final AlertQueueItem item;
  final DropboxApi dropboxApi;

  @override
  State<_AlertTextDialog> createState() => _AlertTextDialogState();
}

class _AlertTextDialogState extends State<_AlertTextDialog> {
  String? _text;
  String? _error;
  bool _loading = true;
  bool _deleting = false;

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
      final text = await widget.dropboxApi.downloadTextAtPath(widget.item.path);
      if (!mounted) return;
      setState(() {
        _text = text;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deletePending() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Delete pending alert?'),
        content: Text(
          'Remove “${widget.item.fileName}” from the queue so it is not sent. '
          'This cannot be undone.',
          style: const TextStyle(color: AppColors.heading, fontSize: 14),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.dropboxApi.deletePath(widget.item.path);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: Text(item.fileName),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${item.kindLabel} · ${item.statusLabel}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                )
              else if (_error != null)
                StatusBanner(text: _error!, isError: true)
              else ...[
                const Text(
                  'Message text:',
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
                    (_text ?? '').trim().isEmpty
                        ? '(empty file)'
                        : _text!.trimRight(),
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (item.canDelete) ...[
                  const SizedBox(height: 12),
                  const HintText(
                    'This alert is still pending. Delete it to cancel the push '
                    'before it is processed.',
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (item.canDelete && !_loading)
          OutlinedButton(
            onPressed: _deleting ? null : _deletePending,
            child: Text(_deleting ? 'Deleting…' : 'Delete pending'),
          ),
        FilledButton(
          onPressed: _deleting ? null : () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
