import 'package:flutter/material.dart';
import 'package:promoter_admin/src/branding.dart';
import 'package:promoter_admin/src/models/publish_status.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/app_navigation.dart';

enum _NavCategory { config, artists, descriptions, schedule, reports, alerts }

/// Minimal header for iPhone — one bar, details in info sheet.
class PhoneShellHeader extends StatelessWidget {
  const PhoneShellHeader({
    super.key,
    required this.festivalName,
    required this.heading,
    required this.subheading,
    required this.metaLine,
    required this.publishStatus,
  });

  final String festivalName;
  final String heading;
  final String subheading;
  final String metaLine;
  final PublishStatusSnapshot publishStatus;

  @override
  Widget build(BuildContext context) {
    final hasFestival = festivalName.trim().isNotEmpty &&
        festivalName.trim() != AppBrand.name;
    final title = hasFestival ? festivalName : heading;
    final breadcrumb = hasFestival ? '$title › $heading' : heading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.navBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              breadcrumb,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.heading,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (publishStatus.headline.isNotEmpty) ...[
            const SizedBox(width: 6),
            _PublishStatusDot(
              status: publishStatus,
              onTap: () => _showPublishSheet(context),
            ),
          ],
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Details',
            onPressed: () => _showInfoSheet(context),
            icon: const Icon(Icons.info_outline, size: 20, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  void _showPublishSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              publishStatus.headline,
              style: const TextStyle(
                color: AppColors.heading,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (publishStatus.detail != null &&
                publishStatus.detail!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                publishStatus.detail!,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppBrand.name,
              style: const TextStyle(
                color: AppColors.brandSteel,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            if (subheading.trim().isNotEmpty) ...[
              Text(
                subheading,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 8),
            ],
            if (metaLine.trim().isNotEmpty)
              Text(
                metaLine,
                style: const TextStyle(
                  color: Color(0xFF7A7A7A),
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PublishStatusDot extends StatelessWidget {
  const _PublishStatusDot({required this.status, required this.onTap});

  final PublishStatusSnapshot status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.kind) {
      PublishStatusKind.readyToPublish ||
      PublishStatusKind.yearRollReady =>
        AppColors.accent,
      PublishStatusKind.upToDate => AppColors.successText,
      PublishStatusKind.error || PublishStatusKind.blocked => AppColors.errorText,
      _ => AppColors.muted,
    };
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: status.headline,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}

/// Accordion nav: category chips + expandable button row. iPhone only.
class PhoneAccordionNav extends StatefulWidget {
  const PhoneAccordionNav({
    super.key,
    required this.section,
    required this.onSectionChanged,
    required this.settingsPromoteSelected,
    required this.publishNavEnabled,
    required this.publishNavHighlight,
    required this.onPromoteTap,
    required this.canEditSchedule,
    required this.allowCustomAlerts,
    this.reportsUiEnabled = false,
    required this.bandsTab,
    required this.onBandsTabChanged,
    required this.scheduleTab,
    required this.onScheduleTabChanged,
    required this.onDescriptionsTabChanged,
    this.canEditBands = true,
    this.canEditDescriptions = true,
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

  @override
  State<PhoneAccordionNav> createState() => _PhoneAccordionNavState();
}

class _PhoneAccordionNavState extends State<PhoneAccordionNav> {
  _NavCategory? _expanded;

  bool get _showPromote =>
      widget.canEditBands ||
      widget.canEditSchedule ||
      widget.canEditDescriptions;

  _NavCategory _categoryForSection(AppSection section) {
    return switch (section) {
      AppSection.settings => _NavCategory.config,
      AppSection.bands => _NavCategory.artists,
      AppSection.descriptions => _NavCategory.descriptions,
      AppSection.schedule => _NavCategory.schedule,
      AppSection.reports => _NavCategory.reports,
      AppSection.alerts => _NavCategory.alerts,
    };
  }

  bool _categoryVisible(_NavCategory category) {
    return switch (category) {
      _NavCategory.reports => widget.reportsUiEnabled,
      _NavCategory.alerts => widget.allowCustomAlerts,
      _ => true,
    };
  }

  String _categoryLabel(_NavCategory category) {
    return switch (category) {
      _NavCategory.config => 'Config',
      _NavCategory.artists => 'Artists',
      _NavCategory.descriptions => 'Descriptions',
      _NavCategory.schedule => 'Schedule',
      _NavCategory.reports => 'Reports',
      _NavCategory.alerts => 'Alerts',
    };
  }

  bool _categoryIsActive(_NavCategory category) {
    return _categoryForSection(widget.section) == category;
  }

  void _toggleCategory(_NavCategory category) {
    setState(() {
      _expanded = _expanded == category ? null : category;
    });
  }

  void _navigate(VoidCallback action) {
    action();
    setState(() => _expanded = null);
  }

  List<Widget> _buttonsFor(_NavCategory category) {
    return switch (category) {
      _NavCategory.config => [
          _PhoneNavButton(
            label: 'Settings',
            selected:
                widget.section == AppSection.settings && !widget.settingsPromoteSelected,
            onTap: () => _navigate(
              () => widget.onSectionChanged(AppSection.settings),
            ),
          ),
          if (_showPromote)
            _PhoneNavButton(
              label: 'Publish',
              selected: widget.section == AppSection.settings &&
                  widget.settingsPromoteSelected,
              emphasized: widget.publishNavHighlight,
              enabled: widget.publishNavEnabled,
              secondary: true,
              onTap: () => _navigate(() {
                widget.onSectionChanged(AppSection.settings);
                widget.onPromoteTap?.call();
              }),
            ),
        ],
      _NavCategory.artists => [
          _PhoneNavButton(
            label: 'Artists',
            selected: widget.section == AppSection.bands,
            onTap: () => _navigate(() {
              widget.onSectionChanged(AppSection.bands);
              widget.onBandsTabChanged?.call(BandsTab.list);
            }),
          ),
        ],
      _NavCategory.descriptions => [
          _PhoneNavButton(
            label: 'Descriptions',
            selected: widget.section == AppSection.descriptions,
            onTap: () => _navigate(() {
              widget.onSectionChanged(AppSection.descriptions);
              widget.onDescriptionsTabChanged?.call(DescriptionsTab.list);
            }),
          ),
        ],
      _NavCategory.schedule => [
          if (widget.canEditSchedule)
            _PhoneNavButton(
              label: 'Entry',
              selected: widget.section == AppSection.schedule &&
                  widget.scheduleTab == ScheduleTab.entry,
              onTap: () => _navigate(() {
                widget.onSectionChanged(AppSection.schedule);
                widget.onScheduleTabChanged?.call(ScheduleTab.entry);
              }),
            ),
          _PhoneNavButton(
            label: 'View',
            selected: widget.section == AppSection.schedule &&
                widget.scheduleTab == ScheduleTab.view,
            secondary: widget.canEditSchedule,
            onTap: () => _navigate(() {
              widget.onSectionChanged(AppSection.schedule);
              widget.onScheduleTabChanged?.call(ScheduleTab.view);
            }),
          ),
          _PhoneNavButton(
            label: 'Stats',
            selected: widget.section == AppSection.schedule &&
                widget.scheduleTab == ScheduleTab.stats,
            secondary: true,
            onTap: () => _navigate(() {
              widget.onSectionChanged(AppSection.schedule);
              widget.onScheduleTabChanged?.call(ScheduleTab.stats);
            }),
          ),
          _PhoneNavButton(
            label: 'Preview',
            selected: widget.section == AppSection.schedule &&
                widget.scheduleTab == ScheduleTab.preview,
            secondary: true,
            onTap: () => _navigate(() {
              widget.onSectionChanged(AppSection.schedule);
              widget.onScheduleTabChanged?.call(ScheduleTab.preview);
            }),
          ),
        ],
      _NavCategory.reports => [
          _PhoneNavButton(
            label: 'View',
            selected: widget.section == AppSection.reports,
            onTap: () => _navigate(
              () => widget.onSectionChanged(AppSection.reports),
            ),
          ),
        ],
      _NavCategory.alerts => [
          _PhoneNavButton(
            label: 'Send Alert',
            selected: widget.section == AppSection.alerts,
            onTap: () => _navigate(
              () => widget.onSectionChanged(AppSection.alerts),
            ),
          ),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        _NavCategory.values.where(_categoryVisible).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.navBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _CategoryChip(
                    label: _categoryLabel(categories[i]),
                    active: _categoryIsActive(categories[i]),
                    expanded: _expanded == categories[i],
                    onTap: () => _toggleCategory(categories[i]),
                  ),
                ],
              ],
            ),
          ),
          if (_expanded != null) ...[
            Divider(
              height: 1,
              color: AppColors.navBorder.withValues(alpha: 0.85),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _buttonsFor(_expanded!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = expanded
        ? AppColors.accentHover
        : active
            ? AppColors.accent.withValues(alpha: 0.35)
            : AppColors.secondaryBtn;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: expanded || active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.9),
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneNavButton extends StatelessWidget {
  const _PhoneNavButton({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.secondary = false,
    this.emphasized = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool secondary;
  final bool emphasized;
  final bool enabled;

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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: enabled ? 1 : 0.55),
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
