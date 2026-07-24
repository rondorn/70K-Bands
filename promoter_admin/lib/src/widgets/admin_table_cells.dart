import 'package:flutter/material.dart';

/// Sizes to [Edit] + [Delete] side by side without stretching the column.
const adminTableActionsColumn = IntrinsicColumnWidth();

/// Descriptions rows with Create Description / Attach Link.
const adminTableWideActionsColumn = IntrinsicColumnWidth();

const adminTableIntrinsicColumn = IntrinsicColumnWidth();
const adminTableFlexColumn = FlexColumnWidth(1);
const adminTableWideFlexColumn = FlexColumnWidth(2);

/// Constrains width so long values wrap instead of pushing action buttons off screen.
/// Omit [maxWidth] so the cell uses the full column width (for flex columns).
Widget adminTableText(
  String text, {
  double? maxWidth,
  TextStyle? style,
}) {
  if (text.isEmpty) {
    return Text('—', style: style ?? const TextStyle(color: Colors.grey));
  }
  final textWidget = Text(
    text,
    style: style,
    softWrap: true,
  );
  if (maxWidth == null) {
    return textWidget;
  }
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: textWidget,
  );
}

/// Action buttons in a single horizontal row (never stacked vertically).
Widget adminTableActions(List<Widget> children) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        children[i],
      ],
    ],
  );
}

Widget adminTableActionsHeading({
  String label = 'Actions',
}) {
  return Center(child: Text(label));
}

Widget adminTableActionsCell(
  List<Widget> children,
) {
  return Center(child: adminTableActions(children));
}

/// Lets [DataTable] rows grow when cell text wraps.
const adminTableRowHeight = double.infinity;
