import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:promoter_admin/src/services/artists_export/logo_fetcher.dart';
import 'package:promoter_admin/src/services/http_fetch.dart';
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

/// Makes near-black pixels transparent for preview display.
///
/// Metal Archives logos often use pure/near black as a background (or letter
/// fill) that blends into MA's black page; knocking it out lets the admin panel
/// background show through. Non-black artwork is unchanged. Preview-only.
///
/// [blackTolerance] is the fraction of full scale (0–1) allowed above 0 on
/// each RGB channel. Default 2% → channels ≤ 5 count as black.
Uint8List? knockoutPureBlackPreview(
  Uint8List bytes, {
  double blackTolerance = 0.02,
}) {
  final img.Image decoded;
  try {
    final result = img.decodeImage(bytes);
    if (result == null) return null;
    decoded = result;
  } catch (_) {
    return null;
  }
  final threshold = (255 * blackTolerance).round().clamp(0, 255);
  final rgba = decoded.numChannels < 4
      ? decoded.convert(numChannels: 4)
      : decoded;
  var changed = false;
  for (final pixel in rgba) {
    if (pixel.r <= threshold &&
        pixel.g <= threshold &&
        pixel.b <= threshold &&
        pixel.a != 0) {
      pixel.a = 0;
      changed = true;
    }
  }
  if (!changed && identical(rgba, decoded) && decoded.numChannels >= 4) {
    // Already has alpha and nothing to knock out — keep original bytes.
    return bytes;
  }
  return Uint8List.fromList(img.encodePng(rgba));
}

/// Compact live preview for a graphic/logo URL field.
///
/// Renders nothing while the URL is empty so data-entry layouts stay stable.
/// Debounces typing so the network is not hit on every keystroke.
/// Pure-black pixels are made transparent so MA-style logos read on dark UI.
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
  Uint8List? _previewBytes;
  bool _loading = false;
  bool _failed = false;
  int _loadGen = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _resolved = resolvePreviewImageUrl(widget.controller.text);
    if (_resolved.isNotEmpty) {
      _loadPreview(_resolved);
    }
  }

  @override
  void didUpdateWidget(covariant UrlImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _timer?.cancel();
      _applyResolved(resolvePreviewImageUrl(widget.controller.text));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _loadGen++;
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      _applyResolved(resolvePreviewImageUrl(widget.controller.text));
    });
  }

  void _applyResolved(String next) {
    if (next == _resolved) return;
    setState(() {
      _resolved = next;
      _previewBytes = null;
      _failed = false;
      _loading = next.isNotEmpty;
    });
    if (next.isNotEmpty) {
      _loadPreview(next);
    } else {
      _loadGen++;
    }
  }

  Future<void> _loadPreview(String url) async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final raw = await LogoFetcher.fetchBytes(url);
    if (!mounted || gen != _loadGen) return;
    if (raw == null) {
      setState(() {
        _loading = false;
        _failed = true;
        _previewBytes = null;
      });
      return;
    }
    final processed = knockoutPureBlackPreview(raw) ?? raw;
    if (!mounted || gen != _loadGen) return;
    setState(() {
      _loading = false;
      _failed = false;
      _previewBytes = processed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_resolved.isEmpty) return const SizedBox.shrink();

    Widget child;
    if (_loading && _previewBytes == null) {
      child = SizedBox(
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
    } else if (_failed || _previewBytes == null) {
      child = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          "Couldn't load preview",
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    } else {
      child = Image.memory(
        _previewBytes!,
        key: ValueKey(_resolved),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    }

    return Padding(
      padding: widget.padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.maxHeight,
            maxWidth: widget.maxWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}
