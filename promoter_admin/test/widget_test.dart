import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/widgets/export_schedule_dialog.dart';

void main() {
  testWidgets('schedule export starts with Shows selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportScheduleDialog(
            workspace: const FestivalWorkspace(
              festivalName: 'Test Fest',
              days: ['Day 1'],
              dates: ['1/29/2026', '1/30/2026'],
              venues: ['Theater'],
            ),
            events: [
              ScheduleEvent(
                band: 'Test Band',
                location: 'Theater',
                date: '1/29/2026',
                day: 'Day 1',
                startTime: '18:00',
                endTime: '19:00',
                type: 'Show',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Export running order'), findsOneWidget);
    expect(find.text('1 event(s) across 1 day(s)'), findsOneWidget);
    expect(find.text('Black & white'), findsOneWidget);
    expect(find.text('Save PDF…'), findsOneWidget);
  });
}
