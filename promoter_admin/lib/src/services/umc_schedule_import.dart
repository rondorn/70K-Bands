import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:promoter_admin/src/services/day_date_alignment.dart';
import 'package:promoter_admin/src/services/schedule_service.dart';
import 'package:promoter_admin/src/services/schedule_validation.dart';

/// A show the UMC feed wants on the schedule.
class UmcFeedShow {
  const UmcFeedShow({
    required this.band,
    required this.location,
    required this.date,
    required this.day,
    required this.startTime,
    required this.endTime,
  });

  final String band;
  final String location;
  final String date;
  final String day;
  final String startTime;
  final String endTime;

  String get key =>
      umcShowKey(band: band, location: location, startTime: startTime);
}

class UmcPlannedAdd {
  const UmcPlannedAdd(this.event);

  final ScheduleEvent event;

  String get label =>
      '${event.band} · ${event.location} · ${event.date} · ${event.startTime}';
}

class UmcPlannedDelete {
  const UmcPlannedDelete({required this.index, required this.event});

  /// Index into the local event list that was planned against.
  final int index;
  final ScheduleEvent event;

  String get label =>
      '${event.band} · ${event.location} · ${event.date} · ${event.startTime}';
}

/// What an UMC import would change. Deletes happen only for Show rows, and
/// only for a band whose feed contains exactly [umcShowsPerBand] shows.
class UmcImportPlan {
  const UmcImportPlan({
    required this.adds,
    required this.deletes,
    required this.alreadyPresent,
    required this.bandsWithoutPair,
    required this.blockingErrors,
    required this.skipped,
    required this.emptyFeed,
  });

  final List<UmcPlannedAdd> adds;
  final List<UmcPlannedDelete> deletes;
  final int alreadyPresent;

  /// Feed bands that do not have exactly two shows. Their local shows stay.
  final int bandsWithoutPair;
  final List<String> blockingErrors;
  final List<String> skipped;
  final bool emptyFeed;

  bool get canApply =>
      blockingErrors.isEmpty &&
      !emptyFeed &&
      (adds.isNotEmpty || deletes.isNotEmpty);
}

/// Every band is expected to have this many shows in the feed.
const umcShowsPerBand = 2;

const _jsonToAppLocation = <(String, String)>[
  ('Pool Deck', 'Pool'),
  ('Royal Theater', 'Theater'),
  ('Studio B', 'Rink'),
  ('Stars Lounge', 'Lounge'),
  ('Bull & Bear', 'Ale And Anchor Pub'),
  ('Boleros', 'Boleros Lounge'),
  ('Playmaker Sports Bar', 'Sports Bar'),
  ('Viking Crown Lounge', 'Viking Crown'),
];

const _jsonLocationAliases = <(String, String)>[('Star Lounge', 'Lounge')];

final Map<String, String> _locationByKey = {
  for (final entry in [..._jsonToAppLocation, ..._jsonLocationAliases])
    entry.$1.toLowerCase(): entry.$2,
};

/// Download the UMC artists JSON. Not cached — each import should see the feed.
Future<String> fetchUmcScheduleJson(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('UMC schedule URL is required');
  }
  final response = await http
      .get(
        Uri.parse(trimmed),
        headers: const {
          'Accept': 'application/json',
          'User-Agent': '70k-schedule-import/1.0',
        },
      )
      .timeout(const Duration(seconds: 60));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode} from the UMC schedule URL');
  }
  return utf8.decode(response.bodyBytes);
}

String umcShowKey({
  required String band,
  required String location,
  required String startTime,
}) {
  return '${band.trim().toLowerCase()}|'
      '${location.trim().toLowerCase()}|'
      '${umcNormalizeTime(startTime)}';
}

String umcNormalizeTime(String value) {
  final text = value.trim();
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
  if (match == null) return text;
  final hour = int.tryParse(match.group(1)!);
  if (hour == null || hour > 23) return text;
  return '${hour.toString().padLeft(2, '0')}:${match.group(2)}';
}

String umcFormatBandName(String name) {
  String cap(String part) {
    if (part.isEmpty) return part;
    return part[0].toUpperCase() + part.substring(1).toLowerCase();
  }

  final words = <String>[];
  for (final word in name.trim().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    words.add(word.split('-').map(cap).join('-'));
  }
  return words.join(' ');
}

/// Map a JSON stage to an app venue. Throws [FormatException] when unknown.
String umcMapLocation(String stage) {
  final raw = stage.trim();
  if (raw.isEmpty) {
    throw const FormatException('Empty stage/venue');
  }
  final key = raw.toLowerCase();
  final exact = _locationByKey[key];
  if (exact != null) return exact;

  var bestLength = -1;
  String? best;
  for (final entry in _jsonToAppLocation) {
    final src = entry.$1.toLowerCase();
    final matches =
        key == src || key.startsWith('$src ') || key.startsWith('$src-');
    if (matches && src.length > bestLength) {
      bestLength = src.length;
      best = entry.$2;
    }
  }
  if (best != null) return best;

  final known = [
    for (final entry in [..._jsonToAppLocation, ..._jsonLocationAliases])
      entry.$1,
  ].join(', ');
  throw FormatException('Unmapped stage "$raw". Known venues: $known');
}

/// Compare [jsonText] with [local] shows. Does not write.
///
/// A local Show is removed only when that band has exactly [umcShowsPerBand]
/// shows in the feed and the local row is not one of them. An empty feed, a
/// band with any other count, or a feed that fails to parse removes nothing.
UmcImportPlan planUmcScheduleImport({
  required String jsonText,
  required List<ScheduleEvent> local,
}) {
  final parsed = _parseFeed(jsonText);
  if (parsed.errors.isNotEmpty) {
    return UmcImportPlan(
      adds: const [],
      deletes: const [],
      alreadyPresent: 0,
      bandsWithoutPair: 0,
      blockingErrors: parsed.errors,
      skipped: const [],
      emptyFeed: false,
    );
  }
  if (parsed.shows.isEmpty) {
    return const UmcImportPlan(
      adds: [],
      deletes: [],
      alreadyPresent: 0,
      bandsWithoutPair: 0,
      blockingErrors: [],
      skipped: [],
      emptyFeed: true,
    );
  }

  final byBand = <String, List<UmcFeedShow>>{};
  final bandOrder = <String>[];
  for (final show in parsed.shows) {
    final bandKey = show.band.trim().toLowerCase();
    final bucket = byBand.putIfAbsent(bandKey, () {
      bandOrder.add(bandKey);
      return <UmcFeedShow>[];
    });
    if (bucket.every((existing) => existing.key != show.key)) {
      bucket.add(show);
    }
  }

  final localShowKeys = <String>{
    for (final event in local)
      if (ScheduleValidation.isShowType(event.type))
        umcShowKey(
          band: event.band,
          location: event.location,
          startTime: event.startTime,
        ),
  };

  final acceptedDeletes = <int>{};
  final acceptedAdds = <UmcPlannedAdd>[];
  final skipped = <String>[];
  var alreadyPresent = 0;
  var bandsWithoutPair = 0;

  List<ScheduleEvent> existingForValidation(Set<int> extraDeletes) {
    return [
      for (var i = 0; i < local.length; i++)
        if (!acceptedDeletes.contains(i) && !extraDeletes.contains(i)) local[i],
      for (final add in acceptedAdds) add.event,
    ];
  }

  for (final bandKey in bandOrder) {
    final unique = byBand[bandKey]!;
    final localIndexes = <int>[
      for (var i = 0; i < local.length; i++)
        if (ScheduleValidation.isShowType(local[i].type) &&
            local[i].band.trim().toLowerCase() == bandKey)
          i,
    ];

    if (unique.length != umcShowsPerBand) {
      bandsWithoutPair++;
      final proposedAdds = <ScheduleEvent>[];
      for (final show in unique) {
        if (localShowKeys.contains(show.key)) {
          alreadyPresent++;
          continue;
        }
        final event = _eventFor(show, local);
        final errors = ScheduleValidation.validateEvent(
          event: event,
          existing: [...existingForValidation(const {}), ...proposedAdds],
        );
        if (errors.isNotEmpty) {
          skipped.add('${event.band}: ${errors.first}');
          continue;
        }
        proposedAdds.add(event);
        localShowKeys.add(show.key);
      }
      acceptedAdds.addAll(proposedAdds.map(UmcPlannedAdd.new));
      continue;
    }

    final feedKeys = unique.map((show) => show.key).toSet();
    final proposedDeleteIndexes = <int>[
      for (final index in localIndexes)
        if (!feedKeys.contains(
          umcShowKey(
            band: local[index].band,
            location: local[index].location,
            startTime: local[index].startTime,
          ),
        ))
          index,
    ];
    final missing = <UmcFeedShow>[
      for (final show in unique)
        if (!localShowKeys.contains(show.key)) show,
    ];
    for (final show in unique) {
      if (localShowKeys.contains(show.key)) alreadyPresent++;
    }

    final proposedAdds = <ScheduleEvent>[];
    String? failure;
    for (final show in missing) {
      final event = _eventFor(show, local);
      final errors = ScheduleValidation.validateEvent(
        event: event,
        existing: [
          ...existingForValidation(proposedDeleteIndexes.toSet()),
          ...proposedAdds,
        ],
      );
      if (errors.isNotEmpty) {
        failure = '${event.band}: ${errors.first}';
        break;
      }
      proposedAdds.add(event);
    }
    if (failure != null) {
      // The pair did not fit the schedule. Leave this band's shows alone.
      skipped.add(failure);
      continue;
    }

    acceptedDeletes.addAll(proposedDeleteIndexes);
    for (final event in proposedAdds) {
      acceptedAdds.add(UmcPlannedAdd(event));
      localShowKeys.add(
        umcShowKey(
          band: event.band,
          location: event.location,
          startTime: event.startTime,
        ),
      );
    }
  }

  final deletes = [
    for (final index in acceptedDeletes.toList()..sort())
      UmcPlannedDelete(index: index, event: local[index]),
  ];

  return UmcImportPlan(
    adds: acceptedAdds,
    deletes: deletes,
    alreadyPresent: alreadyPresent,
    bandsWithoutPair: bandsWithoutPair,
    blockingErrors: const [],
    skipped: skipped,
    emptyFeed: false,
  );
}

List<ScheduleEvent> applyUmcImportPlan(
  List<ScheduleEvent> local,
  UmcImportPlan plan,
) {
  final drop = plan.deletes.map((row) => row.index).toSet();
  return [
    for (var i = 0; i < local.length; i++)
      if (!drop.contains(i)) local[i],
    for (final add in plan.adds) add.event,
  ];
}

ScheduleEvent _eventFor(UmcFeedShow show, List<ScheduleEvent> local) {
  return ScheduleEvent(
    band: _localBandSpelling(show.band, local),
    location: show.location,
    date: DayDateAlignment.normalizeDate(show.date),
    day: show.day,
    startTime: umcNormalizeTime(show.startTime),
    endTime: umcNormalizeTime(show.endTime),
    type: 'Show',
  );
}

String _localBandSpelling(String titleCased, List<ScheduleEvent> local) {
  final key = titleCased.trim().toLowerCase();
  for (final event in local) {
    if (event.band.trim().toLowerCase() == key &&
        event.band.trim().isNotEmpty) {
      return event.band.trim();
    }
  }
  return titleCased;
}

class _ParsedFeed {
  const _ParsedFeed({required this.shows, required this.errors});

  final List<UmcFeedShow> shows;
  final List<String> errors;
}

_ParsedFeed _parseFeed(String jsonText) {
  final trimmed = jsonText.trim();
  if (trimmed.isEmpty) {
    return const _ParsedFeed(shows: [], errors: ['The feed was empty.']);
  }
  Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException catch (e) {
    return _ParsedFeed(shows: const [], errors: ['Invalid JSON: $e']);
  }
  if (decoded is! List) {
    return const _ParsedFeed(
      shows: [],
      errors: ['JSON root must be an array of artists.'],
    );
  }

  final shows = <UmcFeedShow>[];
  final errors = <String>[];
  for (final artist in decoded) {
    if (artist is! Map) {
      errors.add('Artist entry is not an object.');
      continue;
    }
    final rawName = '${artist['name'] ?? ''}'.trim();
    if (rawName.isEmpty) {
      errors.add('Artist id=${artist['id']} is missing a name.');
      continue;
    }
    final name = umcFormatBandName(rawName);
    final performances = artist['performances'];
    if (performances == null) continue;
    if (performances is! List) {
      errors.add('$name: performances must be a list.');
      continue;
    }
    for (var i = 0; i < performances.length; i++) {
      final perf = performances[i];
      if (perf is! Map) {
        errors.add('$name performance[$i]: not an object.');
        continue;
      }
      try {
        shows.add(
          UmcFeedShow(
            band: name,
            location: umcMapLocation('${perf['stage'] ?? ''}'),
            date: _formatDate('${perf['date'] ?? ''}'),
            day: _formatDay(perf['day']),
            startTime: _formatTime('${perf['start_time'] ?? ''}'),
            endTime: _formatTime('${perf['end_time'] ?? ''}'),
          ),
        );
      } on FormatException catch (e) {
        errors.add('$name performance[$i]: ${e.message}');
      }
    }
  }
  return _ParsedFeed(shows: shows, errors: errors);
}

String _formatDate(String isoDate) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(isoDate.trim());
  if (match == null) {
    throw FormatException('Bad date "$isoDate"');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    throw FormatException('Bad date "$isoDate"');
  }
  return '$month/$day/$year';
}

String _formatDay(Object? dayValue) {
  if (dayValue is String && dayValue.trim().toLowerCase().startsWith('day')) {
    return dayValue.trim();
  }
  final number = dayValue is int ? dayValue : int.tryParse('${dayValue ?? ''}');
  if (number == null) {
    throw FormatException('Bad day "$dayValue"');
  }
  return 'Day $number';
}

String _formatTime(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    throw const FormatException('Empty time');
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
  if (match == null) {
    throw FormatException('Bad time "$value"');
  }
  final hour = int.parse(match.group(1)!);
  if (hour > 23) {
    throw FormatException('Bad time "$value"');
  }
  return '${hour.toString().padLeft(2, '0')}:${match.group(2)}';
}
