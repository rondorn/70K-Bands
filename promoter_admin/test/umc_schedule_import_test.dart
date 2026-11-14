import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/festival_setup_package.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/umc_schedule_import.dart';

ScheduleEvent show({
  required String band,
  required String location,
  required String start,
  String end = '19:00',
  String date = '1/14/2027',
  String day = 'Day 1',
  String type = 'Show',
}) {
  return ScheduleEvent(
    band: band,
    location: location,
    date: date,
    day: day,
    startTime: start,
    endTime: end,
    type: type,
  );
}

String feed(List<Map<String, Object?>> artists) => jsonEncode(artists);

Map<String, Object?> artist(
  String name,
  List<Map<String, Object?>> performances,
) {
  return {'name': name, 'performances': performances};
}

Map<String, Object?> perf({
  required String stage,
  required String start,
  String end = '19:00',
  String date = '2027-01-14',
  int day = 1,
}) {
  return {
    'stage': stage,
    'start_time': start,
    'end_time': end,
    'date': date,
    'day': day,
  };
}

void main() {
  test('two feed shows delete only the extra local shows', () {
    final local = [
      show(band: 'Arch Enemy', location: 'Pool', start: '21:30', end: '22:30'),
      show(
        band: 'Arch Enemy',
        location: 'Theater',
        start: '18:00',
        end: '19:00',
        date: '1/16/2027',
        day: 'Day 3',
      ),
      show(band: 'Arch Enemy', location: 'Rink', start: '12:00', end: '13:00'),
      show(
        band: 'Arch Enemy',
        location: 'Lounge',
        start: '15:00',
        end: '16:00',
      ),
      show(
        band: 'Arch Enemy',
        location: 'Pool',
        start: '10:00',
        end: '11:00',
        type: 'Clinic',
      ),
    ];
    final plan = planUmcScheduleImport(
      jsonText: feed([
        artist('ARCH ENEMY', [
          perf(stage: 'Pool Deck Stage', start: '21:30', end: '22:30'),
          perf(
            stage: 'Royal Theater',
            start: '18:00',
            end: '19:00',
            date: '2027-01-16',
            day: 3,
          ),
        ]),
      ]),
      local: local,
    );

    expect(plan.blockingErrors, isEmpty);
    expect(plan.canApply, isTrue);
    expect(plan.adds, isEmpty);
    expect(plan.deletes.map((row) => row.event.startTime), ['12:00', '15:00']);
    expect(plan.deletes.every((row) => row.event.type == 'Show'), isTrue);

    final next = applyUmcImportPlan(local, plan);
    final shows = next.where((event) => event.type == 'Show').toList();
    expect(shows, hasLength(2));
    expect(next.where((event) => event.type == 'Clinic'), hasLength(1));
  });

  test('a band missing from the feed is not deleted', () {
    final local = [
      show(band: 'Kept Band', location: 'Pool', start: '12:00', end: '13:00'),
      show(
        band: 'Kept Band',
        location: 'Theater',
        start: '18:00',
        end: '19:00',
      ),
      show(band: 'Kept Band', location: 'Rink', start: '21:00', end: '22:00'),
      show(band: 'Kept Band', location: 'Lounge', start: '15:00', end: '16:00'),
    ];
    final plan = planUmcScheduleImport(
      jsonText: feed([
        artist('Other Band', [
          perf(stage: 'Studio B', start: '09:00', end: '09:45'),
          perf(stage: 'Bull & Bear', start: '14:00', end: '15:00'),
        ]),
      ]),
      local: local,
    );

    expect(plan.deletes, isEmpty);
    expect(plan.adds, hasLength(2));
    final next = applyUmcImportPlan(local, plan);
    expect(next.where((event) => event.band == 'Kept Band'), hasLength(4));
    expect(next.where((event) => event.band == 'Other Band'), hasLength(2));
  });

  test('one feed show or three feed shows do not delete local shows', () {
    final local = [
      show(band: 'Partial', location: 'Pool', start: '12:00', end: '13:00'),
      show(band: 'Partial', location: 'Theater', start: '18:00', end: '19:00'),
      show(band: 'Partial', location: 'Rink', start: '21:00', end: '22:00'),
      show(band: 'Partial', location: 'Lounge', start: '15:00', end: '16:00'),
      show(
        band: 'Triple',
        location: 'Pool',
        start: '11:00',
        end: '12:00',
        date: '1/15/2027',
        day: 'Day 2',
      ),
      show(
        band: 'Triple',
        location: 'Theater',
        start: '13:00',
        end: '14:00',
        date: '1/15/2027',
        day: 'Day 2',
      ),
      show(
        band: 'Triple',
        location: 'Rink',
        start: '16:00',
        end: '17:00',
        date: '1/15/2027',
        day: 'Day 2',
      ),
      show(
        band: 'Triple',
        location: 'Lounge',
        start: '20:00',
        end: '21:00',
        date: '1/15/2027',
        day: 'Day 2',
      ),
    ];
    final plan = planUmcScheduleImport(
      jsonText: feed([
        artist('Partial', [
          perf(stage: 'Pool Deck', start: '12:00', end: '13:00'),
        ]),
        artist('Triple', [
          perf(
            stage: 'Pool Deck',
            start: '11:00',
            end: '12:00',
            date: '2027-01-15',
            day: 2,
          ),
          perf(
            stage: 'Royal Theater',
            start: '13:00',
            end: '14:00',
            date: '2027-01-15',
            day: 2,
          ),
          perf(
            stage: 'Studio B',
            start: '16:00',
            end: '17:00',
            date: '2027-01-15',
            day: 2,
          ),
        ]),
      ]),
      local: local,
    );

    expect(plan.deletes, isEmpty);
    expect(plan.adds, isEmpty);
    expect(plan.bandsWithoutPair, 2);
    expect(plan.canApply, isFalse);
  });

  test('empty feed and unmapped stage delete nothing', () {
    final local = [
      show(band: 'Arch Enemy', location: 'Pool', start: '21:30', end: '22:30'),
      show(band: 'Arch Enemy', location: 'Rink', start: '12:00', end: '13:00'),
    ];
    final empty = planUmcScheduleImport(jsonText: '[]', local: local);
    expect(empty.emptyFeed, isTrue);
    expect(empty.deletes, isEmpty);
    expect(empty.canApply, isFalse);

    final bad = planUmcScheduleImport(
      jsonText: feed([
        artist('Arch Enemy', [
          perf(stage: 'Not A Real Stage', start: '21:30', end: '22:30'),
          perf(stage: 'Royal Theater', start: '18:00', end: '19:00'),
        ]),
      ]),
      local: local,
    );
    expect(bad.blockingErrors, isNotEmpty);
    expect(bad.deletes, isEmpty);
    expect(bad.adds, isEmpty);
    expect(bad.canApply, isFalse);
  });

  test('a full reschedule replaces the old shows when the feed has two', () {
    final local = [
      show(band: 'Arch Enemy', location: 'Rink', start: '12:00', end: '13:00'),
      show(
        band: 'Arch Enemy',
        location: 'Lounge',
        start: '15:00',
        end: '16:00',
      ),
    ];
    final plan = planUmcScheduleImport(
      jsonText: feed([
        artist('Arch Enemy', [
          perf(stage: 'Pool Deck', start: '21:30', end: '22:30'),
          perf(
            stage: 'Royal Theater',
            start: '18:00',
            end: '19:00',
            date: '2027-01-16',
            day: 3,
          ),
        ]),
      ]),
      local: local,
    );

    expect(plan.deletes, hasLength(2));
    expect(plan.adds, hasLength(2));
    final next = applyUmcImportPlan(local, plan);
    expect(next.map((event) => event.startTime), ['21:30', '18:00']);
    expect(next.map((event) => event.location), ['Pool', 'Theater']);
  });

  test('workspace keeps the UMC URL locally and setup export ignores it', () {
    const ws = FestivalWorkspace(
      festivalName: '70K',
      umcApiEnabled: true,
      umcScheduleApiUrl: 'https://example.com/artists.json',
    );
    final restored = FestivalWorkspace.fromPrefs(ws.toPrefs());
    expect(restored.umcApiEnabled, isTrue);
    expect(restored.umcScheduleApiUrl, 'https://example.com/artists.json');
    final exported = FestivalSetupPackage.fromWorkspace(
      ws,
      includeReports: false,
      includeAlerts: false,
    ).toJson();
    expect(exported.containsKey('umcApiEnabled'), isFalse);
    expect(exported.containsKey('umcScheduleApiUrl'), isFalse);

    const off = FestivalWorkspace(festivalName: 'Other');
    expect(off.umcApiEnabled, isFalse);
    expect(off.umcScheduleApiUrl, isEmpty);
  });
}
