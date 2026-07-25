import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

/// Small version line for Settings (reads iOS/macOS bundle metadata).
class AppVersionFooter extends StatefulWidget {
  const AppVersionFooter({super.key});

  @override
  State<AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<AppVersionFooter> {
  late final Future<String> _label = _loadLabel();

  static Future<String> _loadLabel() async {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final build = info.buildNumber.trim();
    final versionText = build.isEmpty ? version : '$version ($build)';
    return '${AppBrand.name} · Version $versionText';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _label,
      builder: (context, snapshot) {
        final text = snapshot.data;
        if (text == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SelectableText(
            text,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
}
