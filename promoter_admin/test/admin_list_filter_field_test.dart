import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/admin_list_filter_field.dart';

void main() {
  group('adminListQueryMatches', () {
    test('empty query matches everything', () {
      expect(adminListQueryMatches('', ['Iron Maiden']), isTrue);
      expect(adminListQueryMatches('   ', ['Iron Maiden']), isTrue);
    });

    test('matches any field case-insensitively', () {
      expect(
        adminListQueryMatches('maid', ['Iron Maiden', 'UK']),
        isTrue,
      );
      expect(
        adminListQueryMatches('uk', ['Iron Maiden', 'UK']),
        isTrue,
      );
      expect(
        adminListQueryMatches('thrash', ['Iron Maiden', 'UK']),
        isFalse,
      );
    });
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    testWidgets('filter stays on button row height on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      final filter = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPromoterTheme(),
          home: Scaffold(
            body: Column(
              children: [
                const Row(
                  children: [
                    OutlinedButton(
                      onPressed: null,
                      child: Text('Export…'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: AdminListFilterField(
                        controller: filter,
                        hintText: 'Filter artists',
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      fit: FlexFit.loose,
                      child: OutlinedButton(
                        onPressed: null,
                        child: Text('Export…'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      final rows = find.byType(Row);
      expect(
        tester.getSize(rows.at(1)).height,
        tester.getSize(rows.at(0)).height,
      );

      debugDefaultTargetPlatformOverride = null;
      filter.dispose();
    });
  }
}
