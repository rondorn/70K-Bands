import 'package:flutter/material.dart';
import 'package:promoter_admin/src/screens/create_festival_dialog.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/layout_breakpoints.dart';

/// How the user wants to configure a festival (first launch or Add festival).
enum FestivalSetupPath {
  /// Paste a single Dropbox setup-link from Export festival setup.
  joinWithSetupLink,

  /// Paste Testing / Production (and optional reports/alerts) by hand.
  pasteLinks,

  /// Bootstrap new Dropbox folders and pointer files.
  createNew,
}

/// Result of the Settings “Add festival” chooser + follow-up form.
sealed class AddFestivalSetupResult {
  const AddFestivalSetupResult();
}

class AddFestivalFromSetupLink extends AddFestivalSetupResult {
  const AddFestivalFromSetupLink(this.setupUrl);
  final String setupUrl;
}

class AddFestivalFromCreateForm extends AddFestivalSetupResult {
  const AddFestivalFromCreateForm(this.result);
  final CreateFestivalResult result;
}

/// Multi-step dialog: choose path, then collect details.
Future<AddFestivalSetupResult?> showAddFestivalSetupDialog({
  required BuildContext context,
  required bool dropboxConnected,
}) async {
  final path = await showDialog<FestivalSetupPath>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text('Add festival'),
      content: SizedBox(
        width: dialogContentWidth(context, desktop: 520),
        child: FestivalSetupChoiceList(
          onChosen: (chosen) => Navigator.pop(context, chosen),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (path == null || !context.mounted) return null;

  switch (path) {
    case FestivalSetupPath.joinWithSetupLink:
      final url = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.panel,
          title: const Text('Join an existing festival'),
          content: SizedBox(
            width: dialogContentWidth(context, desktop: 520),
            child: JoinFestivalSetupForm(
              submitLabel: 'Add festival',
              onSubmit: (u) => Navigator.pop(context, u),
              onBack: () => Navigator.pop(context),
            ),
          ),
        ),
      );
      if (url == null || url.trim().isEmpty) return null;
      return AddFestivalFromSetupLink(url.trim());
    case FestivalSetupPath.pasteLinks:
      final result = await showCreateFestivalDialog(
        context: context,
        dropboxConnected: dropboxConnected,
        mode: CreateFestivalMode.pasteLinks,
      );
      if (result == null) return null;
      return AddFestivalFromCreateForm(result);
    case FestivalSetupPath.createNew:
      final result = await showCreateFestivalDialog(
        context: context,
        dropboxConnected: dropboxConnected,
        mode: CreateFestivalMode.createNew,
      );
      if (result == null) return null;
      return AddFestivalFromCreateForm(result);
  }
}

/// Three clear choices for non-technical users.
class FestivalSetupChoiceList extends StatelessWidget {
  const FestivalSetupChoiceList({
    super.key,
    required this.onChosen,
    this.enabled = true,
  });

  final ValueChanged<FestivalSetupPath> onChosen;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'How do you want to get started?',
          style: TextStyle(
            color: AppColors.heading,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _ChoiceCard(
          title: 'Join an existing festival',
          subtitle:
              'Paste a setup link someone sent you. We’ll configure the festival for you.',
          onTap: enabled
              ? () => onChosen(FestivalSetupPath.joinWithSetupLink)
              : null,
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'Set up with festival links',
          subtitle:
              'Enter the Testing and Production links you were given. '
              'Reports and Alerts links are optional.',
          onTap:
              enabled ? () => onChosen(FestivalSetupPath.pasteLinks) : null,
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          title: 'Create a brand-new festival',
          subtitle:
              'Build Testing and Production folders and links from scratch. '
              'Use this when releasing a new festival app.',
          onTap: enabled ? () => onChosen(FestivalSetupPath.createNew) : null,
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.heading,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: onTap == null ? AppColors.muted : AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single-field import of an exported festival setup Dropbox link.
class JoinFestivalSetupForm extends StatefulWidget {
  const JoinFestivalSetupForm({
    super.key,
    required this.onSubmit,
    this.onBack,
    this.submitLabel = 'Join festival',
  });

  final ValueChanged<String> onSubmit;
  final VoidCallback? onBack;
  final String submitLabel;

  @override
  State<JoinFestivalSetupForm> createState() => _JoinFestivalSetupFormState();
}

class _JoinFestivalSetupFormState extends State<JoinFestivalSetupForm> {
  late final TextEditingController _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController();
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _url.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Paste the setup link you were sent.');
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Paste the single setup link from your festival contact '
          '(a Dropbox link to an exported setup file).',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: AppColors.errorText, fontSize: 13),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _url,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Festival setup link',
            hintText:
                'https://www.dropbox.com/.../festival-admin-setup.json?raw=1',
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
        if (widget.onBack != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onBack,
            child: const Text('Back'),
          ),
        ],
      ],
    );
  }
}
