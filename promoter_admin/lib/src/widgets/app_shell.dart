import 'package:flutter/material.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';

enum AppSection { settings, bands, schedule, descriptions }

enum BandsTab { list, add }
enum ScheduleTab { entry, view, stats }
enum DescriptionsTab { write, map }

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.festivalName,
    required this.heading,
    required this.subheading,
    required this.metaLine,
    required this.section,
    required this.onSectionChanged,
    required this.child,
    this.settingsPromoteSelected = false,
    this.onPromoteTap,
    this.canEditBands = true,
    this.canEditSchedule = true,
    this.canEditDescriptions = true,
    this.bandsTab = BandsTab.list,
    this.onBandsTabChanged,
    this.scheduleTab = ScheduleTab.entry,
    this.onScheduleTabChanged,
    this.descriptionsTab = DescriptionsTab.write,
    this.onDescriptionsTabChanged,
  });

  final String festivalName;
  final String heading;
  final String subheading;
  final String metaLine;
  final AppSection section;
  final ValueChanged<AppSection> onSectionChanged;
  final Widget child;
  final bool settingsPromoteSelected;
  final VoidCallback? onPromoteTap;
  final bool canEditBands;
  final bool canEditSchedule;
  final bool canEditDescriptions;
  final BandsTab bandsTab;
  final ValueChanged<BandsTab>? onBandsTabChanged;
  final ScheduleTab scheduleTab;
  final ValueChanged<ScheduleTab>? onScheduleTabChanged;
  final DescriptionsTab descriptionsTab;
  final ValueChanged<DescriptionsTab>? onDescriptionsTabChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgTop, AppColors.bgBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    festivalName: festivalName,
                    heading: heading,
                    subheading: subheading,
                    metaLine: metaLine,
                  ),
                  const SizedBox(height: 12),
                  _NavBar(
                    section: section,
                    onSectionChanged: onSectionChanged,
                    settingsPromoteSelected: settingsPromoteSelected,
                    onPromoteTap: onPromoteTap,
                    canEditBands: canEditBands,
                    canEditSchedule: canEditSchedule,
                    canEditDescriptions: canEditDescriptions,
                    bandsTab: bandsTab,
                    onBandsTabChanged: onBandsTabChanged,
                    scheduleTab: scheduleTab,
                    onScheduleTabChanged: onScheduleTabChanged,
                    descriptionsTab: descriptionsTab,
                    onDescriptionsTabChanged: onDescriptionsTabChanged,
                  ),
                  const SizedBox(height: 14),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.festivalName,
    required this.heading,
    required this.subheading,
    required this.metaLine,
  });

  final String festivalName;
  final String heading;
  final String subheading;
  final String metaLine;

  @override
  Widget build(BuildContext context) {
    final hasFestival = festivalName.trim().isNotEmpty &&
        festivalName.trim() != AppBrand.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              AppBrand.logoAsset,
              width: 112,
              height: 112,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppBrand.name,
                  style: const TextStyle(
                    color: AppColors.brandSteel,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasFestival ? festivalName : heading,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasFestival) ...[
                  const SizedBox(height: 2),
                  Text(
                    heading,
                    style: const TextStyle(
                      color: AppColors.heading,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  subheading,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                if (metaLine.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    metaLine,
                    style: const TextStyle(color: Color(0xFF7A7A7A), fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.section,
    required this.onSectionChanged,
    required this.settingsPromoteSelected,
    required this.onPromoteTap,
    required this.canEditBands,
    required this.canEditSchedule,
    required this.canEditDescriptions,
    required this.bandsTab,
    required this.onBandsTabChanged,
    required this.scheduleTab,
    required this.onScheduleTabChanged,
    required this.descriptionsTab,
    required this.onDescriptionsTabChanged,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionChanged;
  final bool settingsPromoteSelected;
  final VoidCallback? onPromoteTap;
  final bool canEditBands;
  final bool canEditSchedule;
  final bool canEditDescriptions;
  final BandsTab bandsTab;
  final ValueChanged<BandsTab>? onBandsTabChanged;
  final ScheduleTab scheduleTab;
  final ValueChanged<ScheduleTab>? onScheduleTabChanged;
  final DescriptionsTab descriptionsTab;
  final ValueChanged<DescriptionsTab>? onDescriptionsTabChanged;

  @override
  Widget build(BuildContext context) {
    final showPromote =
        canEditBands || canEditSchedule || canEditDescriptions;
    final sections = <Widget>[
      _NavSection(
        label: 'Config',
        children: [
          _NavLink(
            label: 'Settings',
            selected: section == AppSection.settings && !settingsPromoteSelected,
            onTap: () => onSectionChanged(AppSection.settings),
          ),
          if (showPromote)
            _NavLink(
              label: 'Publish',
              secondary: true,
              selected:
                  section == AppSection.settings && settingsPromoteSelected,
              onTap: () {
                onSectionChanged(AppSection.settings);
                onPromoteTap?.call();
              },
            ),
        ],
      ),
      if (canEditBands)
        _NavSection(
          label: 'Artists',
          children: [
            _NavLink(
              label: 'Artists',
              selected: section == AppSection.bands,
              onTap: () {
                onSectionChanged(AppSection.bands);
                onBandsTabChanged?.call(BandsTab.list);
              },
            ),
          ],
        ),
      if (canEditDescriptions)
        _NavSection(
          label: 'Descriptions',
          children: [
            _NavLink(
              label: 'Write',
              selected:
                  section == AppSection.descriptions &&
                  descriptionsTab == DescriptionsTab.write,
              onTap: () {
                onSectionChanged(AppSection.descriptions);
                onDescriptionsTabChanged?.call(DescriptionsTab.write);
              },
            ),
            _NavLink(
              label: 'Map',
              secondary: true,
              selected:
                  section == AppSection.descriptions &&
                  descriptionsTab == DescriptionsTab.map,
              onTap: () {
                onSectionChanged(AppSection.descriptions);
                onDescriptionsTabChanged?.call(DescriptionsTab.map);
              },
            ),
          ],
        ),
      if (canEditSchedule)
        _NavSection(
          label: 'Schedule',
          children: [
            _NavLink(
              label: 'Entry',
              selected: section == AppSection.schedule &&
                  scheduleTab == ScheduleTab.entry,
              onTap: () {
                onSectionChanged(AppSection.schedule);
                onScheduleTabChanged?.call(ScheduleTab.entry);
              },
            ),
            _NavLink(
              label: 'View',
              secondary: true,
              selected: section == AppSection.schedule &&
                  scheduleTab == ScheduleTab.view,
              onTap: () {
                onSectionChanged(AppSection.schedule);
                onScheduleTabChanged?.call(ScheduleTab.view);
              },
            ),
            _NavLink(
              label: 'Stats',
              secondary: true,
              selected: section == AppSection.schedule &&
                  scheduleTab == ScheduleTab.stats,
              onTap: () {
                onSectionChanged(AppSection.schedule);
                onScheduleTabChanged?.call(ScheduleTab.stats);
              },
            ),
          ],
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: sections,
          ),
        );
      },
    );
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.navBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.secondary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.accentHover
        : (secondary ? AppColors.secondaryBtn : AppColors.accent);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class PortalPanel extends StatelessWidget {
  const PortalPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(28, 24, 28, 24),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.panelBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 24,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.label,
    required this.child,
    this.requiredField = false,
  });

  final String label;
  final Widget child;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: AppColors.label,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  children: [
                    TextSpan(text: label),
                    if (requiredField)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: Color(0xFFFF3333)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class HintText extends StatelessWidget {
  const HintText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.text,
    this.isError = false,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? AppColors.errorBorder : AppColors.successBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? AppColors.errorText : AppColors.successText,
        ),
      ),
    );
  }
}
