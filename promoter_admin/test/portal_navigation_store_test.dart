import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/portal_navigation_store.dart';
import 'package:promoter_admin/src/widgets/app_shell.dart';

void main() {
  group('PortalNavigation', () {
    test('round-trips section and schedule tab', () {
      const nav = PortalNavigation(
        section: AppSection.schedule,
        scheduleTab: ScheduleTab.view,
      );
      final restored = PortalNavigation.fromJson(nav.toJson());
      expect(restored, isNotNull);
      expect(restored!.section, AppSection.schedule);
      expect(restored.scheduleTab, ScheduleTab.view);
    });

    test('defaults schedule tab when missing', () {
      final restored = PortalNavigation.fromJson({'section': 'bands'});
      expect(restored, isNotNull);
      expect(restored!.section, AppSection.bands);
      expect(restored.scheduleTab, ScheduleTab.entry);
    });

    test('rejects unknown section', () {
      expect(PortalNavigation.fromJson({'section': 'not-a-section'}), isNull);
    });
  });
}
