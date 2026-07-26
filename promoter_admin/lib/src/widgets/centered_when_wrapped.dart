import 'package:flutter/material.dart';

/// [Wrap] that stays start-aligned on a single row and centers when wrapped.
///
/// Preserves left-justified layout when every child fits on one line; when a
/// second run is needed, switches to [WrapAlignment.center] so continuation
/// rows are centered.
class CenteredWhenWrapped extends StatefulWidget {
  const CenteredWhenWrapped({
    super.key,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 8,
    this.crossAxisAlignment = WrapCrossAlignment.center,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final WrapCrossAlignment crossAxisAlignment;

  @override
  State<CenteredWhenWrapped> createState() => _CenteredWhenWrappedState();
}

class _CenteredWhenWrappedState extends State<CenteredWhenWrapped> {
  final _wrapKey = GlobalKey();
  bool _wrapped = false;
  double? _singleRunHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measureWrap);
  }

  @override
  void didUpdateWidget(covariant CenteredWhenWrapped oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.children, widget.children) ||
        oldWidget.spacing != widget.spacing ||
        oldWidget.runSpacing != widget.runSpacing) {
      _singleRunHeight = null;
      WidgetsBinding.instance.addPostFrameCallback(_measureWrap);
    }
  }

  void _measureWrap([_]) {
    if (!mounted) return;
    final context = _wrapKey.currentContext;
    if (context == null) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final height = renderObject.size.height;
    _singleRunHeight ??= height;

    final wrapped = height > _singleRunHeight! + widget.runSpacing + 0.5;
    if (wrapped != _wrapped) {
      setState(() => _wrapped = wrapped);
      WidgetsBinding.instance.addPostFrameCallback(_measureWrap);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: _wrapKey,
      spacing: widget.spacing,
      runSpacing: widget.runSpacing,
      alignment: _wrapped ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: widget.children,
    );
  }
}
