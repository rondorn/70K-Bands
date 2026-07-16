import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/day_date_alignment.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';

void main() {
  group('normalizeDates', () {
    test('uses single-digit month/day and drops padded duplicates', () {
      final out = DayDateAlignment.normalizeDates([
        '01/13/2027',
        '1/13/2027',
        '1/14/2027',
        '01/15/2027',
      ]);
      expect(out, ['1/13/2027', '1/14/2027', '1/15/2027']);
    });

    test('sorts chronologically', () {
      final out = DayDateAlignment.normalizeDates([
        '1/15/2027',
        '1/13/2027',
        '1/14/2027',
      ]);
      expect(out, ['1/13/2027', '1/14/2027', '1/15/2027']);
    });
  });

  group('validateLists', () {
    test('requires one more date than days', () {
      final errors = DayDateAlignment.validateLists(
        days: ['Day 1', 'Day 2'],
        dates: ['1/13/2027', '1/14/2027'],
      );
      expect(errors, isNotEmpty);
      expect(errors.first, contains('1:1 with one extra Date'));
      expect(errors.first, contains('need exactly 3 Dates'));
    });

    test('requireAlignedLists throws when counts do not match', () {
      expect(
        () => DayDateAlignment.requireAlignedLists(
          days: ['Day 1'],
          dates: ['1/13/2027'],
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('1:1 with one extra Date'),
          ),
        ),
      );
    });

    test('accepts N days and N+1 consecutive dates', () {
      final errors = DayDateAlignment.validateLists(
        days: ['Day 1', 'Day 2'],
        dates: ['1/13/2027', '1/14/2027', '1/15/2027'],
      );
      expect(errors, isEmpty);
      expect(
        () => DayDateAlignment.requireAlignedLists(
          days: ['Day 1', 'Day 2'],
          dates: ['1/13/2027', '1/14/2027', '1/15/2027'],
        ),
        returnsNormally,
      );
    });

    test('rejects non-consecutive dates', () {
      final errors = DayDateAlignment.validateLists(
        days: ['Day 1'],
        dates: ['1/13/2027', '1/15/2027'],
      );
      expect(errors.any((e) => e.contains('consecutive')), isTrue);
    });

    test('rejects days without dates', () {
      final errors = DayDateAlignment.validateLists(
        days: ['Day 1', 'Day 2'],
        dates: const [],
      );
      expect(errors.first, contains('no Dates'));
    });
  });

  group('resolveDate', () {
    const days = ['Pre', 'Day 1', 'Day 2'];
    const dates = ['1/12/2027', '1/13/2027', '1/14/2027', '1/15/2027'];

    test('daytime uses base date', () {
      expect(
        DayDateAlignment.resolveDate(
          days: days,
          dates: dates,
          day: 'Day 2',
          startHour: '22',
          startMin: '00',
          rolloverTime: '8:00',
        ),
        '1/14/2027',
      );
    });

    test('before rollover uses next date', () {
      expect(
        DayDateAlignment.resolveDate(
          days: days,
          dates: dates,
          day: 'Day 2',
          startHour: '02',
          startMin: '30',
          rolloverTime: '8:00',
        ),
        '1/15/2027',
      );
    });

    test('at rollover uses base date', () {
      expect(
        DayDateAlignment.resolveDate(
          days: days,
          dates: dates,
          day: 'Day 2',
          startHour: '8',
          startMin: '00',
          rolloverTime: '8:00',
        ),
        '1/14/2027',
      );
    });
  });

  group('ensureOvernightBuffer', () {
    test('appends next day when counts are equal', () {
      final dates = DayDateAlignment.ensureOvernightBuffer(
        days: ['Day 1', 'Day 2'],
        dates: ['1/13/2027', '1/14/2027'],
      );
      expect(dates, ['1/13/2027', '1/14/2027', '1/15/2027']);
    });
  });

  test('hintsFromEvents orders days by earliest date and pads overnight', () {
    final hints = ScheduleService.hintsFromEvents([
      ScheduleEvent(
        band: 'A',
        location: 'Pool',
        date: '01/14/2027',
        day: 'Day 2',
        startTime: '12:00',
        endTime: '13:00',
        type: 'Show',
      ),
      ScheduleEvent(
        band: 'B',
        location: 'Pool',
        date: '1/13/2027',
        day: 'Day 1',
        startTime: '12:00',
        endTime: '13:00',
        type: 'Show',
      ),
    ]);
    expect(hints.days, ['Day 1', 'Day 2']);
    expect(hints.dates, ['1/13/2027', '1/14/2027', '1/15/2027']);
  });
}
