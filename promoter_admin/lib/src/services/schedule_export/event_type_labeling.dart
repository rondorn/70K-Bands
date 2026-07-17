/// Rules for when to show Meet and Greet / Clinic / Unofficial Event labels
/// on running-order exports.
///
/// - Those three types may be labeled; Show and Special Event never are.
/// - If the export selection is exactly one of those three, the label goes in
///   the page header (not on each event).
/// - If mixed types are selected, label each Meet and Greet / Clinic /
///   Unofficial Event individually.
class EventTypeLabeling {
  const EventTypeLabeling({
    required this.pageHeaderLabel,
    required this.labelEventsIndividually,
  });

  /// Default for mixed / unspecified selections: label eligible events.
  static const mixed = EventTypeLabeling(
    pageHeaderLabel: null,
    labelEventsIndividually: true,
  );

  /// Non-null when the whole export is a single labelable type.
  final String? pageHeaderLabel;

  /// True when event boxes should show a type tag (mixed selection).
  final bool labelEventsIndividually;

  static const _labelable = {
    'clinic',
    'meet and greet',
    'unofficial event',
  };

  static EventTypeLabeling forSelection(Iterable<String> selectedTypes) {
    final normalized = selectedTypes
        .map(_normalize)
        .where((type) => type.isNotEmpty)
        .toSet();
    if (normalized.length == 1 && _labelable.contains(normalized.single)) {
      return EventTypeLabeling(
        pageHeaderLabel: pageHeaderForType(normalized.single),
        labelEventsIndividually: false,
      );
    }
    return mixed;
  }

  static bool isLabelable(String type) =>
      _labelable.contains(_normalize(type));

  /// Short in-box label, or null when this event should not show a type tag.
  String? eventLabel(String type) {
    if (!labelEventsIndividually) return null;
    final normalized = _normalize(type);
    if (!_labelable.contains(normalized)) return null;
    return shortLabelForType(normalized);
  }

  /// Plural page-header label when the export is only this type.
  static String pageHeaderForType(String normalized) {
    switch (normalized) {
      case 'meet and greet':
        return 'MEET & GREETS';
      case 'clinic':
        return 'CLINICS';
      case 'unofficial event':
        return 'UNOFFICIAL EVENTS';
      default:
        return _pluralizeWords(normalized).toUpperCase();
    }
  }

  static String shortLabelForType(String normalized) {
    switch (normalized) {
      case 'meet and greet':
        return 'MEET & GREET';
      case 'clinic':
        return 'CLINIC';
      case 'unofficial event':
        return 'UNOFFICIAL';
      default:
        return normalized.toUpperCase();
    }
  }

  /// Filename segment when exactly one event type is selected, e.g. `shows`
  /// or `meet-and-greets`. Null when mixed or empty.
  static String? fileSlugForSelection(Iterable<String> selectedTypes) {
    final selected = selectedTypes
        .map((type) => type.trim())
        .where((type) => type.isNotEmpty)
        .toList();
    final normalized = selected.map(_normalize).toSet();
    if (normalized.length != 1) return null;
    return _fileSlugForType(normalized.single);
  }

  static String _fileSlugForType(String normalized) {
    switch (normalized) {
      case 'show':
        return 'shows';
      case 'clinic':
        return 'clinics';
      case 'meet and greet':
        return 'meet-and-greets';
      case 'special event':
        return 'special-events';
      case 'unofficial event':
        return 'unofficial-events';
      default:
        return _safeSlug(_pluralizeWords(normalized));
    }
  }

  static String _pluralizeWords(String normalized) {
    final parts = normalized.split(RegExp(r'\s+'));
    if (parts.isEmpty) return normalized;
    final last = parts.last;
    if (last.endsWith('s')) return normalized;
    parts[parts.length - 1] = '${last}s';
    return parts.join(' ');
  }

  static String _safeSlug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String _normalize(String type) => type.trim().toLowerCase();
}
