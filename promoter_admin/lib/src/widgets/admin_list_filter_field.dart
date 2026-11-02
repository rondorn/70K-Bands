import 'package:flutter/material.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

/// Case-insensitive substring match across [fields]. Empty/whitespace query
/// matches everything.
bool adminListQueryMatches(String query, Iterable<String> fields) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  for (final field in fields) {
    if (field.toLowerCase().contains(needle)) return true;
  }
  return false;
}

/// Dense search field sized to match themed [OutlinedButton] / [FilledButton]
/// height so it can sit on the same toolbar row without growing header chrome
/// (especially on phone).
class AdminListFilterField extends StatelessWidget {
  const AdminListFilterField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.maxWidth = 320,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final double maxWidth;

  static double heightFor(BuildContext context) {
    final padded = Theme.of(context).materialTapTargetSize ==
        MaterialTapTargetSize.padded;
    return padded ? 48 : 32;
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.isNotEmpty;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        height: heightFor(context),
        child: TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 14,
            height: 1.2,
            color: AppColors.heading,
          ),
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: AppColors.muted,
            ),
            prefixIconConstraints: const BoxConstraints.tightFor(
              width: 32,
              height: 24,
            ),
            suffixIcon: hasQuery
                ? IconButton(
                    tooltip: 'Clear filter',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                    },
                    icon: const Icon(Icons.close, size: 16),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints.tightFor(
              width: 24,
              height: 24,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
    );
  }
}
