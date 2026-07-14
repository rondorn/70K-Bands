/// Parsed production/testing pointer (`Section::key::value` lines).
class PointerFile {
  PointerFile(this.sections);

  final Map<String, Map<String, String>> sections;

  Map<String, String> get current =>
      Map<String, String>.from(sections['Current'] ?? const {});

  String get artistUrl => (current['artistUrl'] ?? '').trim();
  String get scheduleUrl => (current['scheduleUrl'] ?? '').trim();
  String get descriptionMapUrl => (current['descriptionMap'] ?? '').trim();
  String get eventYear => (current['eventYear'] ?? '').trim();

  /// Festival-wide grant for freeform push alerts (`Current::allowCustomAlerts::1`).
  /// Pointer writers also get the Alerts UI without this flag.
  bool get allowCustomAlerts => isTruthyFlag(current['allowCustomAlerts']);

  static bool isTruthyFlag(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes' || v == 'on';
  }

  /// Explicit event-type list from Current or the vocabulary schedule section.
  List<String> get eventTypesFromPointer {
    final fromCurrent = _parseEventTypesList(
      current['eventTypes'] ??
          current['event_types'] ??
          current['eventTypeList'] ??
          '',
    );
    if (fromCurrent.isNotEmpty) return fromCurrent;
    final sectionName = scheduleSourceSection;
    if (sectionName.isEmpty) return const [];
    final section = sections[sectionName] ?? const {};
    return _parseEventTypesList(
      section['eventTypes'] ??
          section['event_types'] ??
          section['eventTypeList'] ??
          '',
    );
  }

  /// Prefer year-below-current (or current year / Current) for vocabulary CSV.
  String get scheduleSourceSection {
    final year = _currentEventYear;
    if (year.isNotEmpty) {
      final prior = (int.parse(year) - 1).toString();
      if (sections.containsKey(prior)) return prior;
      for (final y in _numericYears) {
        if (int.parse(y) < int.parse(year)) return y;
      }
      if (sections.containsKey(year)) return year;
    }
    if (_numericYears.isNotEmpty) return _numericYears.first;
    if (scheduleUrl.isNotEmpty) return 'Current';
    return '';
  }

  String get scheduleUrlForVocabulary {
    final sectionName = scheduleSourceSection;
    if (sectionName.isEmpty) return '';
    final section = sections[sectionName] ?? const {};
    final url = (section['scheduleUrl'] ?? '').trim();
    if (url.isNotEmpty) return url;
    return scheduleUrl;
  }

  List<String> get _numericYears {
    final years = sections.keys.where((k) => RegExp(r'^\d+$').hasMatch(k)).toList()
      ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));
    return years;
  }

  String get _currentEventYear {
    final y = eventYear;
    if (RegExp(r'^\d+$').hasMatch(y)) return y;
    return _numericYears.isNotEmpty ? _numericYears.first : '';
  }

  static List<String> _parseEventTypesList(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const [];
    return [
      for (final part in text.split(RegExp(r'[,|\n]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];
  }

  static PointerFile parse(String text) {
    final sections = <String, Map<String, String>>{};
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('::');
      if (parts.length < 3) continue;
      final section = parts[0].trim();
      final key = parts[1].trim();
      final value = parts.sublist(2).join('::').trim();
      sections.putIfAbsent(section, () => <String, String>{})[key] = value;
    }
    if (!sections.containsKey('Current') || sections['Current']!.isEmpty) {
      throw FormatException('Pointer file has no Current section.');
    }
    return PointerFile(sections);
  }
}
