import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/attendee_schedule_prompt.dart';
import 'package:promoter_admin/src/models/pointer_file.dart';

void main() {
  const pointer = '''
# keep me
Current::artistUrl::https://example.com/a.csv
Current::scheduleUrl::https://example.com/s.csv
Current::eventYear::2026

2025::scheduleUrl::https://example.com/old.csv
''';

  test('missing flags read as off', () {
    expect(
      AttendeeSchedulePrompt.fromPointer(PointerFile.parse(pointer)),
      AttendeeSchedulePrompt.off,
    );
  });

  test('Yes without repeat is a new-schedule prompt', () {
    const text = '''
Current::artistUrl::https://example.com/a.csv
Current::AutoScheduleFlag::Yes
Current::AutoScheduleFlagRepeat::No
''';
    expect(
      AttendeeSchedulePrompt.fromPointer(PointerFile.parse(text)),
      AttendeeSchedulePrompt.newSchedule,
    );
  });

  test('Yes and repeat Yes is an updated-schedule prompt', () {
    const text = '''
Current::artistUrl::https://example.com/a.csv
Current::AutoScheduleFlag::Yes
Current::AutoScheduleFlagRepeat::yes
''';
    expect(
      AttendeeSchedulePrompt.fromPointer(PointerFile.parse(text)),
      AttendeeSchedulePrompt.updatedSchedule,
    );
  });

  test('repeat is ignored unless the flag is exactly Yes', () {
    const text = '''
Current::artistUrl::https://example.com/a.csv
Current::AutoScheduleFlag::YES
Current::AutoScheduleFlagRepeat::Yes
''';
    expect(
      AttendeeSchedulePrompt.fromPointer(PointerFile.parse(text)),
      AttendeeSchedulePrompt.off,
    );
  });

  test('pointer values use the capitalization the apps check', () {
    expect(AttendeeSchedulePrompt.off.pointerValues, (
      flag: 'No',
      repeat: 'No',
    ));
    expect(AttendeeSchedulePrompt.newSchedule.pointerValues, (
      flag: 'Yes',
      repeat: 'No',
    ));
    expect(AttendeeSchedulePrompt.updatedSchedule.pointerValues, (
      flag: 'Yes',
      repeat: 'Yes',
    ));
  });

  test('applyToPointerText writes the canonical Testing choice', () {
    const text = '''
Current::artistUrl::https://example.com/a.csv
Current::AutoScheduleFlag::No
''';
    final out = AttendeeSchedulePrompt.updatedSchedule.applyToPointerText(text);
    expect(
      AttendeeSchedulePrompt.fromPointer(PointerFile.parse(out)),
      AttendeeSchedulePrompt.updatedSchedule,
    );
    expect(out, contains('Current::artistUrl::https://example.com/a.csv'));
  });

  test(
    'patch inserts missing Current keys and leaves the rest of the file',
    () {
      final values = AttendeeSchedulePrompt.newSchedule.pointerValues;
      final out = patchPointerCurrentLines(pointer, {
        'AutoScheduleFlag': values.flag,
        'AutoScheduleFlagRepeat': values.repeat,
      });

      expect(out, contains('# keep me'));
      expect(out, contains('Current::eventYear::2026'));
      expect(out, contains('2025::scheduleUrl::https://example.com/old.csv'));
      expect(out, contains('Current::AutoScheduleFlag::Yes'));
      expect(out, contains('Current::AutoScheduleFlagRepeat::No'));

      final parsed = PointerFile.parse(out);
      expect(parsed.eventYear, '2026');
      expect(parsed.scheduleUrl, 'https://example.com/s.csv');
      expect(
        AttendeeSchedulePrompt.fromPointer(parsed),
        AttendeeSchedulePrompt.newSchedule,
      );
      expect(
        out.indexOf('Current::AutoScheduleFlag::Yes'),
        greaterThan(out.indexOf('Current::eventYear::2026')),
      );
      expect(
        out.indexOf('2025::scheduleUrl'),
        greaterThan(out.indexOf('Current::AutoScheduleFlagRepeat::No')),
      );
    },
  );

  test('patch updates every existing copy of a Current key', () {
    const text = '''
Current::artistUrl::https://example.com/a.csv
Current::AutoScheduleFlag::No
Current::AutoScheduleFlagRepeat::Yes
Current::AutoScheduleFlag::No
''';
    final out = patchPointerCurrentLines(text, {
      'AutoScheduleFlag': 'Yes',
      'AutoScheduleFlagRepeat': 'No',
    });
    expect('Current::AutoScheduleFlag::No'.allMatches(out), isEmpty);
    expect('Current::AutoScheduleFlag::Yes'.allMatches(out), hasLength(2));
    expect(out, contains('Current::AutoScheduleFlagRepeat::No'));
    expect(
      AttendeeSchedulePrompt.fromPointer(PointerFile.parse(out)),
      AttendeeSchedulePrompt.newSchedule,
    );
  });

  test('patch keeps CRLF line endings', () {
    const text =
        'Current::artistUrl::https://example.com/a.csv\r\n'
        'Current::eventYear::2026\r\n';
    final out = patchPointerCurrentLines(text, {'AutoScheduleFlag': 'No'});
    expect(out, contains('\r\n'));
    expect(out.contains('\n') && !out.contains('\r\n'), isFalse);
    expect(out, contains('Current::AutoScheduleFlag::No\r\n'));
  });
}
