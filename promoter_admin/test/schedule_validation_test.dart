import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_validation.dart';

ScheduleEvent _event({
  String band = 'Band A',
  String location = 'Stage 1',
  String date = '6/13/2026',
  String day = 'Day 1',
  String start = '12:00',
  String end = '13:00',
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

void main() {
  test('bypass skips all rules', () {
    final errors = ScheduleValidation.validateEvent(
      event: _event(band: ''),
      existing: const [],
      verifyBypass: true,
    );
    expect(errors, isEmpty);
  });

  test('rejects blank day when marked required', () {
    final errors = ScheduleValidation.validateEvent(
      event: _event(day: ' '),
      existing: const [],
    );
    expect(errors.any((e) => e.contains('Day must be assigned')), isTrue);
  });

  test('rejects overlapping venue bookings', () {
    final errors = ScheduleValidation.validateEvent(
      event: _event(band: 'Band B', start: '12:30', end: '13:30'),
      existing: [_event(start: '12:00', end: '13:00')],
    );
    expect(errors.any((e) => e.contains('Stage 1')), isTrue);
  });

  test('rejects overlapping band bookings across venues', () {
    final errors = ScheduleValidation.validateEvent(
      event: _event(location: 'Stage 2', start: '12:30', end: '13:00'),
      existing: [_event(start: '12:00', end: '13:00')],
    );
    expect(errors.any((e) => e.contains('Band A')), isTrue);
  });

  test('allows at most two shows per band', () {
    final existing = [
      _event(start: '10:00', end: '11:00'),
      _event(start: '14:00', end: '15:00'),
    ];
    final errors = ScheduleValidation.validateEvent(
      event: _event(start: '16:00', end: '17:00'),
      existing: existing,
    );
    expect(errors.any((e) => e.contains('2 shows')), isTrue);
  });

  test('rejects show shorter than 30 minutes', () {
    final errors = ScheduleValidation.validateEvent(
      event: _event(start: '12:00', end: '12:20'),
      existing: const [],
    );
    expect(errors.any((e) => e.contains('30 min')), isTrue);
  });

  test('stats matrix counts by band and type', () {
    final events = [
      _event(band: 'A', type: 'Show'),
      _event(band: 'A', type: 'Show', start: '14:00', end: '15:00'),
      _event(band: 'A', type: 'Meet and Greet', start: '16:00', end: '16:30'),
      _event(band: 'B', type: 'Show'),
    ];
    final stats = ScheduleValidation.buildStats(events);
    expect(stats['A']?['Show'], 2);
    expect(stats['A']?['Meet and Greet'], 1);
    expect(stats['B']?['Show'], 1);
  });
}
