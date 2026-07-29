import 'package:flutter/material.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/models/publish_status.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_navigation.dart';
import 'package:promoter_admin/src/widgets/layout_breakpoints.dart';
import 'package:promoter_admin/src/widgets/phone_shell_chrome.dart';

export 'app_navigation.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.festivalName,
    required this.heading,
    required this.subheading,
    required this.metaLine,
    this.publishStatus = PublishStatusSnapshot.initial,
    required this.section,
    required this.onSectionChanged,
    required this.child,
    this.settingsPromoteSelected = false,
    this.publishNavEnabled = true,
    this.publishNavHighlight = false,
    this.onPromoteTap,
    this.canEditBands = true,
    this.canEditSchedule = true,
    this.canEditDescriptions = true,
    this.allowCustomAlerts = false,
    this.reportsUiEnabled = false,
    this.bandsTab = BandsTab.list,
    this.onBandsTabChanged,
    this.scheduleTab = ScheduleTab.view,
    this.onScheduleTabChanged,
    this.onDescriptionsTabChanged,
  });

  final String festivalName;
  final String heading;
  final String subheading;
  final String metaLine;
  final PublishStatusSnapshot publishStatus;
  final AppSection section;
  final ValueChanged<AppSection> onSectionChanged;
  final Widget child;
  final bool settingsPromoteSelected;
  final bool publishNavEnabled;
  final bool publishNavHighlight;
  final VoidCallback? onPromoteTap;
  final bool canEditBands;
  final bool canEditSchedule;
  final bool canEditDescriptions;
  final bool allowCustomAlerts;
  final bool reportsUiEnabled;
  final BandsTab bandsTab;
  final ValueChanged<BandsTab>? onBandsTabChanged;
  final ScheduleTab scheduleTab;
  final ValueChanged<ScheduleTab>? onScheduleTabChanged;
  final ValueChanged<DescriptionsTab>? onDescriptionsTabChanged;

  @override
  Widget build(BuildContext context) {
    final phone = isPhoneDevice(context);
    final compact = isCompactLayout(context) && !phone;
    final outerPadding = phone
        ? const EdgeInsets.fromLTRB(8, 4, 8, 8)
        : compact
            ? const EdgeInsets.fromLTRB(10, 6, 10, 10)
            : const EdgeInsets.fromLTRB(24, 16, 24, 28);
    final chromeSpacing = phone ? 6.0 : (compact ? 8.0 : 12.0);
    final bodySpacing = phone ? 6.0 : (compact ? 8.0 : 14.0);

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
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: Padding(
                padding: outerPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (phone)
                      PhoneShellHeader(
                        festivalName: festivalName,
                        heading: heading,
                        subheading: subheading,
                        metaLine: metaLine,
                        publishStatus: publishStatus,
                      )
                    else
                      _Header(
                        festivalName: festivalName,
                        heading: heading,
                        subheading: subheading,
                        metaLine: metaLine,
                        publishStatus: publishStatus,
                        compact: compact,
                      ),
                    SizedBox(height: chromeSpacing),
                    if (phone)
                      PhoneAccordionNav(
                        section: section,
                        onSectionChanged: onSectionChanged,
                        settingsPromoteSelected: settingsPromoteSelected,
                        publishNavEnabled: publishNavEnabled,
                        publishNavHighlight: publishNavHighlight,
                        onPromoteTap: onPromoteTap,
                        canEditBands: canEditBands,
                        canEditSchedule: canEditSchedule,
                        canEditDescriptions: canEditDescriptions,
                        allowCustomAlerts: allowCustomAlerts,
                        reportsUiEnabled: reportsUiEnabled,
                        bandsTab: bandsTab,
                        onBandsTabChanged: onBandsTabChanged,
                        scheduleTab: scheduleTab,
                        onScheduleTabChanged: onScheduleTabChanged,
                        onDescriptionsTabChanged: onDescriptionsTabChanged,
                      )
                    else
                      _NavBar(
                        section: section,
                        onSectionChanged: onSectionChanged,
                        settingsPromoteSelected: settingsPromoteSelected,
                        publishNavEnabled: publishNavEnabled,
                        publishNavHighlight: publishNavHighlight,
                        onPromoteTap: onPromoteTap,
                        canEditBands: canEditBands,
                        canEditSchedule: canEditSchedule,
                        canEditDescriptions: canEditDescriptions,
                        allowCustomAlerts: allowCustomAlerts,
                        reportsUiEnabled: reportsUiEnabled,
                        bandsTab: bandsTab,
                        onBandsTabChanged: onBandsTabChanged,
                        scheduleTab: scheduleTab,
                        onScheduleTabChanged: onScheduleTabChanged,
                        onDescriptionsTabChanged: onDescriptionsTabChanged,
                        compact: compact,
                      ),
                    SizedBox(height: bodySpacing),
                    Expanded(child: child),
                  ],
                ),
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
    required this.publishStatus,
    this.compact = false,
  });

  final String festivalName;
  final String heading;
  final String subheading;
  final String metaLine;
  final PublishStatusSnapshot publishStatus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasFestival = festivalName.trim().isNotEmpty &&
        festivalName.trim() != AppBrand.name;
    final logoSize = compact ? 56.0 : 112.0;
    final panelPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 14);
    final titleSize = compact ? 20.0 : 24.0;
    final sectionTitleSize = compact ? 15.0 : 17.0;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppBrand.name,
          style: TextStyle(
            color: AppColors.brandSteel,
            fontSize: compact ? 11 : 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          hasFestival ? festivalName : heading,
          style: TextStyle(
            color: AppColors.accent,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (hasFestival) ...[
          const SizedBox(height: 2),
          Text(
            heading,
            style: TextStyle(
              color: AppColors.heading,
              fontSize: sectionTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        SizedBox(height: compact ? 2 : 4),
        Text(
          subheading,
          style: TextStyle(
            color: AppColors.muted,
            fontSize: compact ? 12 : 14,
          ),
        ),
        if (metaLine.isNotEmpty) ...[
          SizedBox(height: compact ? 4 : 8),
          Text(
            metaLine,
            maxLines: compact ? 3 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: TextStyle(
              color: const Color(0xFF7A7A7A),
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ],
    );

    final badge = publishStatus.headline.isNotEmpty
        ? _PublishStatusBadge(status: publishStatus, compact: compact)
        : null;

    return Container(
      padding: panelPadding,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.navBorder),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        AppBrand.logoAsset,
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: titleBlock),
                  ],
                ),
                if (badge != null) ...[
                  const SizedBox(height: 8),
                  badge,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    AppBrand.logoAsset,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(flex: 3, child: titleBlock),
                if (badge != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: badge,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PublishStatusBadge extends StatelessWidget {
  const _PublishStatusBadge({required this.status, this.compact = false});

  final PublishStatusSnapshot status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(status.kind);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            status.headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (status.detail != null && status.detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              status.detail!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.detail,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({Color background, Color border, Color text, Color detail}) _colorsFor(
    PublishStatusKind kind,
  ) {
    switch (kind) {
      case PublishStatusKind.readyToPublish:
      case PublishStatusKind.yearRollReady:
        return (
          background: AppColors.accent.withValues(alpha: 0.12),
          border: AppColors.accent.withValues(alpha: 0.55),
          text: AppColors.accent,
          detail: AppColors.muted,
        );
      case PublishStatusKind.upToDate:
        return (
          background: AppColors.successBg,
          border: AppColors.successBorder.withValues(alpha: 0.6),
          text: AppColors.successText,
          detail: AppColors.muted,
        );
      case PublishStatusKind.error:
      case PublishStatusKind.blocked:
        return (
          background: AppColors.errorBg,
          border: AppColors.errorBorder.withValues(alpha: 0.6),
          text: AppColors.errorText,
          detail: AppColors.muted,
        );
      case PublishStatusKind.checking:
      case PublishStatusKind.scheduleSaving:
      case PublishStatusKind.unknown:
      case PublishStatusKind.notConfigured:
        return (
          background: AppColors.navPanel,
          border: AppColors.navBorder,
          text: AppColors.label,
          detail: AppColors.muted,
        );
    }
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.section,
    required this.onSectionChanged,
    required this.settingsPromoteSelected,
    required this.publishNavEnabled,
    required this.publishNavHighlight,
    required this.onPromoteTap,
    required this.canEditBands,
    required this.canEditSchedule,
    required this.canEditDescriptions,
    required this.allowCustomAlerts,
    this.reportsUiEnabled = false,
    required this.bandsTab,
    required this.onBandsTabChanged,
    required this.scheduleTab,
    required this.onScheduleTabChanged,
    required this.onDescriptionsTabChanged,
    this.compact = false,
  });

  final AppSection section;
  final ValueChanged<AppSection> onSectionChanged;
  final bool settingsPromoteSelected;
  final bool publishNavEnabled;
  final bool publishNavHighlight;
  final VoidCallback? onPromoteTap;
  final bool canEditBands;
  final bool canEditSchedule;
  final bool canEditDescriptions;
  final bool allowCustomAlerts;
  final bool reportsUiEnabled;
  final BandsTab bandsTab;
  final ValueChanged<BandsTab>? onBandsTabChanged;
  final ScheduleTab scheduleTab;
  final ValueChanged<ScheduleTab>? onScheduleTabChanged;
  final ValueChanged<DescriptionsTab>? onDescriptionsTabChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showPromote =
        canEditBands || canEditSchedule || canEditDescriptions;
    final sections = <Widget>[
      _NavSection(
        label: 'Config',
        compact: compact,
        children: [
          _NavLink(
            label: 'Settings',
            compact: compact,
            selected: section == AppSection.settings && !settingsPromoteSelected,
            onTap: () => onSectionChanged(AppSection.settings),
          ),
          if (showPromote)
            _NavLink(
              label: 'Publish',
              compact: compact,
              secondary: true,
              selected:
                  section == AppSection.settings && settingsPromoteSelected,
              emphasized: publishNavHighlight,
              enabled: publishNavEnabled,
              onTap: () {
                onSectionChanged(AppSection.settings);
                onPromoteTap?.call();
              },
            ),
        ],
      ),
      _NavSection(
        label: 'Artists',
        compact: compact,
        children: [
          _NavLink(
            label: 'Artists',
            compact: compact,
            selected: section == AppSection.bands,
            onTap: () {
              onSectionChanged(AppSection.bands);
              onBandsTabChanged?.call(BandsTab.list);
            },
          ),
        ],
      ),
      _NavSection(
        label: 'Descriptions',
        compact: compact,
        children: [
          _NavLink(
            label: 'Descriptions',
            compact: compact,
            selected: section == AppSection.descriptions,
            onTap: () {
              onSectionChanged(AppSection.descriptions);
              onDescriptionsTabChanged?.call(DescriptionsTab.list);
            },
          ),
        ],
      ),
      _NavSection(
        label: 'Schedule',
        compact: compact,
        children: [
          if (canEditSchedule)
            _NavLink(
              label: 'Entry',
              compact: compact,
              selected: section == AppSection.schedule &&
                  scheduleTab == ScheduleTab.entry,
              onTap: () {
                onSectionChanged(AppSection.schedule);
                onScheduleTabChanged?.call(ScheduleTab.entry);
              },
            ),
          _NavLink(
            label: 'View',
            compact: compact,
            secondary: canEditSchedule,
            selected: section == AppSection.schedule &&
                scheduleTab == ScheduleTab.view,
            onTap: () {
              onSectionChanged(AppSection.schedule);
              onScheduleTabChanged?.call(ScheduleTab.view);
            },
          ),
          _NavLink(
            label: 'Stats',
            compact: compact,
            secondary: true,
            selected: section == AppSection.schedule &&
                scheduleTab == ScheduleTab.stats,
            onTap: () {
              onSectionChanged(AppSection.schedule);
              onScheduleTabChanged?.call(ScheduleTab.stats);
            },
          ),
          _NavLink(
            label: 'Preview',
            compact: compact,
            secondary: true,
            selected: section == AppSection.schedule &&
                scheduleTab == ScheduleTab.preview,
            onTap: () {
              onSectionChanged(AppSection.schedule);
              onScheduleTabChanged?.call(ScheduleTab.preview);
            },
          ),
        ],
      ),
      if (reportsUiEnabled)
        _NavSection(
          label: 'Reports',
          compact: compact,
          children: [
            _NavLink(
              label: 'View',
              compact: compact,
              selected: section == AppSection.reports,
              onTap: () => onSectionChanged(AppSection.reports),
            ),
          ],
        ),
      if (allowCustomAlerts)
        _NavSection(
          label: 'Alerts',
          compact: compact,
          children: [
            _NavLink(
              label: 'Send Alert',
              compact: compact,
              selected: section == AppSection.alerts,
              onTap: () => onSectionChanged(AppSection.alerts),
            ),
          ],
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: compact ? 6 : 8,
            runSpacing: compact ? 6 : 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: sections,
          ),
        );
      },
    );
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection({
    required this.label,
    required this.children,
    this.compact = false,
  });

  final String label;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        compact ? 6 : 8,
        compact ? 8 : 10,
        compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.navPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.navBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.accent,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: compact ? 4 : 6),
                children[i],
              ],
            ],
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
    this.emphasized = false,
    this.enabled = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool secondary;
  final bool emphasized;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = !enabled
        ? AppColors.secondaryBtn.withValues(alpha: 0.45)
        : selected
            ? AppColors.accentHover
            : emphasized
                ? AppColors.accent
                : (secondary ? AppColors.secondaryBtn : AppColors.accent);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 5 : 7,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: enabled ? 1 : 0.55),
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              fontSize: compact ? 12 : 14,
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
    final compact = isCompactLayout(context);
    return Container(
      width: double.infinity,
      padding: padding ??
          (compact
              ? const EdgeInsets.fromLTRB(14, 14, 14, 12)
              : const EdgeInsets.fromLTRB(28, 24, 28, 24)),
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
    this.onLabelTap,
  });

  final String label;
  final Widget child;
  final bool requiredField;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final compact = isCompactLayout(context);
    Widget labelWidget = RichText(
      text: TextSpan(
        style: TextStyle(
          color: AppColors.label,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 14 : 15,
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
    );
    if (onLabelTap != null) {
      labelWidget = GestureDetector(
        onTap: onLabelTap,
        behavior: HitTestBehavior.opaque,
        child: labelWidget,
      );
    }

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: labelWidget,
            ),
            child,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: labelWidget,
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
