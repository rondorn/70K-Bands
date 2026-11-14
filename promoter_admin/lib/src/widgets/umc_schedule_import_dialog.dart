import 'package:flutter/material.dart';
import 'package:promoter_admin/src/services/umc_schedule_import.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/layout_breakpoints.dart';

/// Preview of an UMC schedule import. Returns true when the user confirms.
Future<bool> showUmcScheduleImportDialog({
  required BuildContext context,
  required UmcImportPlan plan,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _UmcScheduleImportDialog(plan: plan),
  );
  return result == true;
}

class _UmcScheduleImportDialog extends StatelessWidget {
  const _UmcScheduleImportDialog({required this.plan});

  final UmcImportPlan plan;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('UMC import'),
      content: SizedBox(
        width: dialogContentWidth(context, desktop: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in _summaryLines(plan))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              if (plan.adds.isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text(
                  'Add',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                ..._sample(plan.adds.map((row) => row.label)),
              ],
              if (plan.deletes.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Remove extra shows',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                ..._sample(plan.deletes.map((row) => row.label)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(plan.canApply ? 'Cancel' : 'Close'),
        ),
        if (plan.canApply)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
      ],
    );
  }
}

List<String> _summaryLines(UmcImportPlan plan) {
  if (plan.blockingErrors.isNotEmpty) {
    return [
      'The feed could not be imported. Nothing was changed.',
      ...plan.blockingErrors,
    ];
  }
  if (plan.emptyFeed) {
    return const ['The feed has no shows. Existing shows were left in place.'];
  }
  final lines = <String>[
    'Add ${plan.adds.length} show${plan.adds.length == 1 ? '' : 's'}.',
    'Remove ${plan.deletes.length} extra show${plan.deletes.length == 1 ? '' : 's'}.',
    'Already in the schedule: ${plan.alreadyPresent}.',
  ];
  if (plan.bandsWithoutPair > 0) {
    lines.add(
      '${plan.bandsWithoutPair} band${plan.bandsWithoutPair == 1 ? '' : 's'} '
      'in the feed do not have 2 shows. Their existing shows were left in place.',
    );
  }
  if (plan.skipped.isNotEmpty) {
    lines.add('Skipped:');
    lines.addAll(plan.skipped);
  }
  if (!plan.canApply) {
    lines.add('Nothing to change.');
  }
  return lines;
}

List<Widget> _sample(Iterable<String> labels) {
  final all = labels.toList();
  final shown = all.take(8);
  return [
    for (final label in shown)
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
    if (all.length > 8)
      Text(
        '… and ${all.length - 8} more',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
  ];
}
