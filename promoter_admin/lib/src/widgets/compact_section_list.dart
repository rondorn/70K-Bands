import 'package:flutter/material.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

/// One row in a phone-friendly list: primary text plus trailing action buttons.
class CompactSectionListRow extends StatelessWidget {
  const CompactSectionListRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.actions,
    this.titleStyle,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final TextStyle? titleStyle;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle ??
                        const TextStyle(
                          color: AppColors.heading,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Vertical list wrapper for compact phone sections.
class CompactSectionList extends StatelessWidget {
  const CompactSectionList({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: children.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: AppColors.panelBorder.withValues(alpha: 0.85),
      ),
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Matches [OutlinedButton] sizing used in admin DataTable action cells.
ButtonStyle compactListActionStyle() {
  return OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}
