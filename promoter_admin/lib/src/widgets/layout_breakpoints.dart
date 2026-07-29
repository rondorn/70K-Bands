import 'package:flutter/material.dart';

/// Width below which the admin UI switches to a compact (phone) layout.
const kCompactLayoutWidth = 700.0;

/// True on narrow screens (e.g. iPhone) where the Mac/iPad layout would overflow.
bool isCompactLayout(BuildContext context) {
  return MediaQuery.sizeOf(context).width < kCompactLayoutWidth;
}

/// Padding for list/table panels (Artists, Schedule, Descriptions, etc.).
EdgeInsets listPanelPadding(BuildContext context) {
  return isCompactLayout(context)
      ? const EdgeInsets.fromLTRB(10, 10, 10, 8)
      : const EdgeInsets.fromLTRB(12, 12, 12, 12);
}

/// Standard vertical gap before a table inside a list panel.
double listPanelSectionGap(BuildContext context) {
  return isCompactLayout(context) ? 8 : 12;
}

/// Width for dialog content areas — full width on phone, fixed on Mac/iPad.
double dialogContentWidth(BuildContext context, {double desktop = 480}) {
  return isCompactLayout(context)
      ? MediaQuery.sizeOf(context).width * 0.88
      : desktop;
}

/// Footer refresh control shared by list sections.
class SectionRefreshFooter extends StatelessWidget {
  const SectionRefreshFooter({
    super.key,
    required this.label,
    required this.onRefresh,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onRefresh;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: enabled ? onRefresh : null,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(label),
      ),
    );
  }
}
