import 'package:flutter/material.dart';
import 'package:promoter_admin/src/services/description_link_markup.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

/// Multiline description editor.
///
/// Shows web addresses as plain `https://` text. Saved files still use the
/// `!!!!https://` marker the iOS and Android apps look for.
class DescriptionBodyField extends StatefulWidget {
  const DescriptionBodyField({
    super.key,
    required this.controller,
    this.minLines = 8,
    this.maxLines = 12,
    this.hintText = 'Description text…',
  });

  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final String hintText;

  @override
  State<DescriptionBodyField> createState() => _DescriptionBodyFieldState();
}

class _DescriptionBodyFieldState extends State<DescriptionBodyField> {
  @override
  void initState() {
    super.initState();
    _stripMarkup();
  }

  @override
  void didUpdateWidget(DescriptionBodyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _stripMarkup();
    }
  }

  void _stripMarkup() {
    final next = descriptionEditingValue(widget.controller.value);
    if (next == widget.controller.value) return;
    widget.controller.value = next;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final urls = descriptionLinkUrls(value.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widget.controller,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => _stripMarkup(),
              decoration: InputDecoration(hintText: widget.hintText),
            ),
            const HintText(
              'Web addresses are saved as links for the iOS and Android apps.',
            ),
            if (urls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final url in urls)
                      Text(
                        url,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
