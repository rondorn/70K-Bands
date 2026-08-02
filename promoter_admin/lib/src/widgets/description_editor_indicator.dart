import 'package:flutter/material.dart';
import 'package:promoter_admin/src/services/description_map_service.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

enum DescriptionEditorKind { mine, other, unknown }

/// Whether [updatedBy] matches the signed-in Dropbox account.
DescriptionEditorKind descriptionEditorKind({
  required String? updatedBy,
  required String currentAccount,
}) {
  final editor = DescriptionMapService.normalizeUpdatedBy(updatedBy);
  final me = currentAccount.trim();
  if (editor.isEmpty) return DescriptionEditorKind.unknown;
  if (me.isEmpty) return DescriptionEditorKind.other;
  if (editor.toLowerCase() == me.toLowerCase()) {
    return DescriptionEditorKind.mine;
  }
  return DescriptionEditorKind.other;
}

Color descriptionEditorColor(DescriptionEditorKind kind) {
  switch (kind) {
    case DescriptionEditorKind.mine:
      return AppColors.successBorder;
    case DescriptionEditorKind.other:
      return AppColors.accent;
    case DescriptionEditorKind.unknown:
      return AppColors.muted;
  }
}

String emailLocalPart(String email) {
  final editor = email.trim();
  if (editor.isEmpty) return '';
  final at = editor.indexOf('@');
  if (at > 0) return editor.substring(0, at);
  if (editor.length <= 24) return editor;
  return '${editor.substring(0, 21)}…';
}

String descriptionEditorShortLabel(String? updatedBy) {
  final editor = DescriptionMapService.normalizeUpdatedBy(updatedBy);
  if (editor.isEmpty) return 'Unknown';
  return emailLocalPart(editor);
}

class DescriptionEditorIndicator extends StatelessWidget {
  const DescriptionEditorIndicator({
    super.key,
    required this.updatedBy,
    required this.currentAccount,
    this.showLabel = true,
    this.compact = false,
  });

  final String? updatedBy;
  final String currentAccount;
  final bool showLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final kind = descriptionEditorKind(
      updatedBy: updatedBy,
      currentAccount: currentAccount,
    );
    final color = descriptionEditorColor(kind);
    final label = descriptionEditorShortLabel(updatedBy);
    final dotSize = compact ? 7.0 : 8.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        if (showLabel) ...[
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kind == DescriptionEditorKind.mine
                    ? AppColors.successText
                    : AppColors.label,
                fontSize: compact ? 12 : 13,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class DescriptionEditorLegend extends StatelessWidget {
  const DescriptionEditorLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _legendItem(AppColors.successBorder, 'Saved by you'),
        _legendItem(AppColors.accent, 'Saved by someone else'),
        _legendItem(AppColors.muted, 'Not set (automated)'),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
