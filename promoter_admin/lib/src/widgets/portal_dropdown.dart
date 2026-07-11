import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

/// Shared empty-first dropdown helpers for schedule / description forms.
class DropdownOptions {
  /// Sentinel for the blank choice (shown as — by default).
  static const empty = '';

  /// Put a blank option first; drop duplicate blanks; keep non-empty order.
  static List<String> withEmpty(Iterable<String> items) {
    final out = <String>[empty];
    final seen = <String>{empty};
    for (final raw in items) {
      final value = raw.trim().isEmpty ? empty : raw;
      if (seen.add(value)) out.add(value);
    }
    return out;
  }

  /// Prefer [preferred] when it exists in [options]; otherwise the empty choice.
  static String pick(String? preferred, List<String> options) {
    final raw = preferred ?? empty;
    final value = raw.trim().isEmpty ? empty : raw;
    if (options.contains(value)) return value;
    return options.contains(empty)
        ? empty
        : (options.isEmpty ? empty : options.first);
  }

  static String label(String value, {String emptyLabel = '—'}) =>
      value.trim().isEmpty ? emptyLabel : value;
}

/// Simple browser-style `<select>`: closed field + list, type-to-jump by prefix.
class PortalStringDropdown extends StatefulWidget {
  const PortalStringDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.decoration,
    this.emptyLabel = '—',
    this.labelBuilder,
    this.enabled = true,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;
  final InputDecoration? decoration;
  final String emptyLabel;
  final String Function(String value)? labelBuilder;
  final bool enabled;

  @override
  State<PortalStringDropdown> createState() => _PortalStringDropdownState();
}

class _PortalStringDropdownState extends State<PortalStringDropdown> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  final _scrollController = ScrollController();

  OverlayEntry? _overlay;
  int _highlight = 0;
  bool _open = false;
  String _typeBuffer = '';
  DateTime? _lastTypeAt;

  List<String> get _options =>
      widget.items.isEmpty ? DropdownOptions.withEmpty(const []) : widget.items;

  String _labelOf(String value) =>
      widget.labelBuilder?.call(value) ??
      DropdownOptions.label(value, emptyLabel: widget.emptyLabel);

  String get _selected => DropdownOptions.pick(widget.value, _options);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _closeMenu();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _open) {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted || _focusNode.hasFocus) return;
        _closeMenu();
      });
    }
  }

  void _openMenu() {
    if (!widget.enabled) return;
    final opts = _options;
    _highlight = opts.indexOf(_selected).clamp(0, opts.isEmpty ? 0 : opts.length - 1);
    _typeBuffer = '';
    if (_open) {
      _overlay?.markNeedsBuild();
    } else {
      _open = true;
      _overlay = OverlayEntry(builder: _buildOverlay);
      Overlay.of(context).insert(_overlay!);
      setState(() {});
    }
    _focusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureHighlightVisible());
  }

  void _closeMenu() {
    _overlay?.remove();
    _overlay = null;
    _typeBuffer = '';
    if (_open) {
      _open = false;
      if (mounted) setState(() {});
    }
  }

  void _toggleMenu() {
    if (_open) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _selectIndex(int index) {
    final opts = _options;
    if (opts.isEmpty) return;
    final i = index.clamp(0, opts.length - 1);
    widget.onChanged?.call(opts[i]);
    _closeMenu();
  }

  void _moveHighlight(int delta) {
    final opts = _options;
    if (opts.isEmpty) return;
    if (!_open) {
      _openMenu();
      return;
    }
    _highlight = (_highlight + delta).clamp(0, opts.length - 1);
    _overlay?.markNeedsBuild();
    _ensureHighlightVisible();
  }

  /// Browser `<select>` type-ahead: accumulate keys briefly, jump to prefix match.
  void _typeToJump(String character) {
    final now = DateTime.now();
    if (_lastTypeAt == null ||
        now.difference(_lastTypeAt!) > const Duration(milliseconds: 800)) {
      _typeBuffer = '';
    }
    _lastTypeAt = now;
    _typeBuffer += character.toLowerCase();

    final opts = _options;
    if (opts.isEmpty) return;

    final wasOpen = _open;
    final start = wasOpen ? ((_highlight + 1) % opts.length) : 0;
    int? match;
    for (var n = 0; n < opts.length; n++) {
      final i = (start + n) % opts.length;
      if (_labelOf(opts[i]).toLowerCase().startsWith(_typeBuffer)) {
        match = i;
        break;
      }
    }
    if (match == null && _typeBuffer.length == 1) {
      for (var n = 0; n < opts.length; n++) {
        final i = (start + n) % opts.length;
        if (_labelOf(opts[i]).toLowerCase().startsWith(_typeBuffer)) {
          match = i;
          break;
        }
      }
    }
    if (match == null) return;

    _highlight = match;
    if (wasOpen) {
      _overlay?.markNeedsBuild();
      _ensureHighlightVisible();
    } else {
      // Closed + focused: commit like a native browser <select>.
      widget.onChanged?.call(opts[match]);
      setState(() {});
    }
  }

  void _ensureHighlightVisible() {
    if (!_scrollController.hasClients || _options.isEmpty) return;
    const itemExtent = 40.0;
    final target = _highlight * itemExtent;
    final view = _scrollController.position;
    if (target < view.pixels) {
      _scrollController.jumpTo(target);
    } else if (target + itemExtent > view.pixels + view.viewportDimension) {
      _scrollController.jumpTo(target + itemExtent - view.viewportDimension);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_open) {
        _closeMenu();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (_open) {
        _selectIndex(_highlight);
      } else {
        _openMenu();
      }
      return KeyEventResult.handled;
    }

    final chars = event.character;
    if (chars != null && chars.isNotEmpty && !_isControlChar(chars)) {
      _typeToJump(chars);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _isControlChar(String s) {
    if (s.length != 1) return true;
    final code = s.codeUnitAt(0);
    return code < 0x20 || code == 0x7f;
  }

  Widget _buildOverlay(BuildContext context) {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 280;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final offset =
        box?.localToGlobal(Offset.zero, ancestor: overlayBox) ?? Offset.zero;
    final spaceBelow =
        (overlayBox?.size.height ?? 800) - offset.dy - (box?.size.height ?? 40);
    final maxHeight = spaceBelow.clamp(120.0, 320.0);
    final opts = _options;

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, (box?.size.height ?? 40) + 4),
        child: Material(
          elevation: 8,
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: opts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No options',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemExtent: 40,
                    itemCount: opts.length,
                    itemBuilder: (context, index) {
                      final item = opts[index];
                      final selected = item == _selected;
                      final highlighted = index == _highlight;
                      return InkWell(
                        onTap: () => _selectIndex(index),
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          color: highlighted
                              ? AppColors.accent.withValues(alpha: 0.22)
                              : (selected
                                  ? AppColors.inputBg
                                  : Colors.transparent),
                          child: Text(
                            _labelOf(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.heading,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseDecoration = widget.decoration ?? const InputDecoration();
    final label = _labelOf(_selected);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: widget.enabled ? _toggleMenu : null,
            child: InputDecorator(
              key: _fieldKey,
              isFocused: _focusNode.hasFocus || _open,
              isEmpty: label.isEmpty,
              decoration: baseDecoration.copyWith(
                suffixIcon: Icon(
                  _open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: AppColors.muted,
                ),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.enabled ? AppColors.heading : AppColors.muted,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
