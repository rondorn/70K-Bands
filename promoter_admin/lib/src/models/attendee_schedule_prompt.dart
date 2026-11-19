import 'package:promoter_admin/src/models/pointer_file.dart';

/// Attendee "Plan Your Schedule" prompt, stored as two pointer flags.
///
/// The admin app writes these on the Testing pointer. Publish copies the same
/// choice onto Production. Apps offer the wizard only when
/// `Current::AutoScheduleFlag` is exactly `Yes`.
/// `Current::AutoScheduleFlagRepeat` only changes the wording (`Yes` = rerun).
enum AttendeeSchedulePrompt {
  off('Prompt: Off'),
  newSchedule('Prompt: new schedule'),
  updatedSchedule('Prompt: updated schedule');

  const AttendeeSchedulePrompt(this.label);

  final String label;

  static const hint =
      'Writes the Testing pointer. Publish to Production before attendees '
      'see it. Answering once sticks until the schedule name changes.';

  /// Apps compare the flag to `Yes` with case sensitivity. Repeat is looser.
  static AttendeeSchedulePrompt fromFlagValues(String? flag, String? repeat) {
    if ((flag ?? '').trim() != 'Yes') return AttendeeSchedulePrompt.off;
    if ((repeat ?? '').trim().toLowerCase() == 'yes') {
      return AttendeeSchedulePrompt.updatedSchedule;
    }
    return AttendeeSchedulePrompt.newSchedule;
  }

  static AttendeeSchedulePrompt fromPointer(PointerFile pointer) {
    return fromFlagValues(
      pointer.current['AutoScheduleFlag'],
      pointer.current['AutoScheduleFlagRepeat'],
    );
  }

  /// Write this choice onto `Current`, leaving every other line in place.
  String applyToPointerText(String pointerText) {
    final values = pointerValues;
    return patchPointerCurrentLines(pointerText, {
      'AutoScheduleFlag': values.flag,
      'AutoScheduleFlagRepeat': values.repeat,
    });
  }

  /// Values written onto `Current`. Repeat is `No` when the prompt is off.
  ({String flag, String repeat}) get pointerValues => switch (this) {
    AttendeeSchedulePrompt.off => (flag: 'No', repeat: 'No'),
    AttendeeSchedulePrompt.newSchedule => (flag: 'Yes', repeat: 'No'),
    AttendeeSchedulePrompt.updatedSchedule => (flag: 'Yes', repeat: 'Yes'),
  };
}

/// Replace or append `Current` keys without rewriting the rest of the file.
///
/// Existing lines, comments, blank lines, and other sections stay put.
/// A key that already appears more than once is updated on every line so a
/// later duplicate cannot keep the old value.
String patchPointerCurrentLines(String text, Map<String, String> updates) {
  if (updates.isEmpty) return text;
  for (final key in updates.keys) {
    if (key.trim().isEmpty || key.contains('::') || key.contains('\n')) {
      throw ArgumentError('Invalid pointer key: $key');
    }
  }

  final separator = text.contains('\r\n') ? '\r\n' : '\n';
  final lines = text.split(separator);
  final found = <String>{};
  var sawCurrent = false;
  var lastCurrentLine = -1;

  for (var i = 0; i < lines.length; i++) {
    final parsed = _currentKey(lines[i]);
    if (parsed == null) continue;
    sawCurrent = true;
    lastCurrentLine = i;
    final value = updates[parsed];
    if (value == null) continue;
    found.add(parsed);
    lines[i] = 'Current::$parsed::$value';
  }

  if (!sawCurrent) {
    throw const FormatException('Pointer file has no Current section.');
  }

  if (found.length < updates.length) {
    final extra = <String>[
      for (final entry in updates.entries)
        if (!found.contains(entry.key)) 'Current::${entry.key}::${entry.value}',
    ];
    lines.insertAll(lastCurrentLine + 1, extra);
  }

  return lines.join(separator);
}

String? _currentKey(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('#')) return null;
  final parts = trimmed.split('::');
  if (parts.length < 3) return null;
  if (parts[0].trim() != 'Current') return null;
  return parts[1].trim();
}
