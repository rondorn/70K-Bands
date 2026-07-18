import 'dart:async';

import 'package:flutter/material.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
import 'package:promoter_admin/src/services/platform_http.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

/// Turns a form image URL into a fetchable absolute URL.
///
/// Handles scheme-stripped lineup values (`www.example.com/a.png`) and
/// Dropbox `dl=0` → `raw=1` normalization.
String resolvePreviewImageUrl(String raw) {
  var value = raw.trim();
  if (value.isEmpty || value == ' ') return '';
  final lower = value.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    value = 'https://$value';
  }
  return normalizeDropboxUrl(value);
}

/// Compact live preview for a graphic/logo URL field.
///
/// Renders nothing while the URL is empty so data-entry layouts stay stable.
/// Debounces typing so the network is not hit on every keystroke.
class UrlImagePreview extends StatefulWidget {
  const UrlImagePreview({
    super.key,
    required this.controller,
    this.maxHeight = 88,
    this.maxWidth = 260,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final TextEditingController controller;
  final double maxHeight;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  State<UrlImagePreview> createState() => _UrlImagePreviewState();
}

class _UrlImagePreviewState extends State<UrlImagePreview> {
  static const _debounce = Duration(milliseconds: 400);

  String _resolved = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _resolved = resolvePreviewImageUrl(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant UrlImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _timer?.cancel();
      _resolved = resolvePreviewImageUrl(widget.controller.text);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      final next = resolvePreviewImageUrl(widget.controller.text);
      if (next == _resolved) return;
      setState(() => _resolved = next);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolved.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: widget.padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.maxHeight,
            maxWidth: widget.maxWidth,
          ),
          child: Image.network(
            _resolved,
            key: ValueKey(_resolved),
            fit: BoxFit.contain,
            headers: const {'User-Agent': kSafariUserAgent},
            filterQuality: FilterQuality.medium,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                height: widget.maxHeight,
                width: 120,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Text(
                  "Couldn't load preview",
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
