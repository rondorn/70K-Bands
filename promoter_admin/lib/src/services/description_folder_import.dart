import 'package:promoter_admin/src/services/description_map_service.dart';

class DescriptionImportFile {
  const DescriptionImportFile({
    required this.fileName,
    required this.filePath,
  });

  final String fileName;
  final String filePath;
}

class DescriptionImportLink {
  const DescriptionImportLink({
    required this.bandName,
    required this.fileName,
    required this.filePath,
  });

  final String bandName;
  final String fileName;
  final String filePath;
}

class DescriptionFolderImportPlan {
  const DescriptionFolderImportPlan({
    required this.toLink,
    required this.skippedExisting,
    required this.ambiguousBands,
  });

  /// Unique lineup matches that should be written to the map.
  final List<DescriptionImportLink> toLink;

  /// Lineup bands that already have a map URL (override off).
  final List<String> skippedExisting;

  /// Lineup bands with more than one artists-file or folder match.
  final List<String> ambiguousBands;
}

bool isDescriptionImportTxt(String fileName) {
  return fileName.trim().toLowerCase().endsWith('.txt');
}

/// Stem used to match `lathe.txt` to lineup band "Lathe".
String descriptionImportStemKey(String bandOrFileName) {
  var value = bandOrFileName.trim();
  if (value.toLowerCase().endsWith('.txt')) {
    value = value.substring(0, value.length - 4);
  }
  return DescriptionMapService.safeFileStem(value).toLowerCase();
}

/// Decide which Dropbox `.txt` files become map links.
///
/// Matching is lineup-only. Unmatched files are ignored. Duplicate lineup
/// rows, two lineup names sharing a stem, or two `.txt` files for one band
/// are not linked; those band names go in [DescriptionFolderImportPlan.ambiguousBands].
DescriptionFolderImportPlan planDescriptionFolderImport({
  required List<String> lineupNames,
  required List<DescriptionImportFile> files,
  required Map<String, String> existingUrlByBandLower,
  bool overrideExisting = false,
}) {
  final trimmedNames = [
    for (final name in lineupNames)
      if (name.trim().isNotEmpty) name.trim(),
  ];

  final countByLower = <String, int>{};
  final displayByLower = <String, String>{};
  for (final name in trimmedNames) {
    final key = name.toLowerCase();
    countByLower[key] = (countByLower[key] ?? 0) + 1;
    displayByLower.putIfAbsent(key, () => name);
  }

  final namesByStem = <String, List<String>>{};
  for (final entry in displayByLower.entries) {
    final stem = descriptionImportStemKey(entry.value);
    if (stem.isEmpty) continue;
    namesByStem.putIfAbsent(stem, () => []).add(entry.value);
  }

  final filesByStem = <String, List<DescriptionImportFile>>{};
  for (final file in files) {
    if (!isDescriptionImportTxt(file.fileName)) continue;
    final stem = descriptionImportStemKey(file.fileName);
    if (stem.isEmpty) continue;
    filesByStem.putIfAbsent(stem, () => []).add(file);
  }

  final skippedExisting = <String>[];
  final toLink = <DescriptionImportLink>[];
  final ambiguous = <String>{};

  for (final entry in filesByStem.entries) {
    final bands = namesByStem[entry.key] ?? const <String>[];
    if (bands.isEmpty) continue;

    if (bands.length > 1) {
      ambiguous.addAll(bands);
      continue;
    }

    final bandName = bands.single;
    final rowCount = countByLower[bandName.toLowerCase()] ?? 0;
    if (rowCount > 1 || entry.value.length > 1) {
      ambiguous.add(bandName);
      continue;
    }

    final existingUrl =
        (existingUrlByBandLower[bandName.toLowerCase()] ?? '').trim();
    if (existingUrl.isNotEmpty && !overrideExisting) {
      skippedExisting.add(bandName);
      continue;
    }

    final file = entry.value.single;
    toLink.add(
      DescriptionImportLink(
        bandName: bandName,
        fileName: file.fileName,
        filePath: file.filePath,
      ),
    );
  }

  toLink.sort(
    (a, b) => a.bandName.toLowerCase().compareTo(b.bandName.toLowerCase()),
  );
  skippedExisting.sort(
    (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
  );
  final ambiguousBands = ambiguous.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return DescriptionFolderImportPlan(
    toLink: toLink,
    skippedExisting: skippedExisting,
    ambiguousBands: ambiguousBands,
  );
}

String formatDescriptionFolderImportMessage({
  required int added,
  required int updated,
  required List<String> skippedExisting,
  required List<String> ambiguousBands,
}) {
  final parts = <String>[];
  if (added > 0) {
    parts.add(
      added == 1
          ? 'Added 1 description link.'
          : 'Added $added description links.',
    );
  }
  if (updated > 0) {
    parts.add(
      updated == 1
          ? 'Updated 1 existing description link.'
          : 'Updated $updated existing description links.',
    );
  }
  if (skippedExisting.isNotEmpty) {
    parts.add(
      skippedExisting.length == 1
          ? 'Skipped 1 band already on the map.'
          : 'Skipped ${skippedExisting.length} bands already on the map.',
    );
  }
  if (parts.isEmpty && ambiguousBands.isEmpty) {
    parts.add('No new description links to add.');
  }
  if (ambiguousBands.isNotEmpty) {
    parts.add(
      'These bands have more than one entry (nothing was added for them). '
      'Clean up and import again:\n${ambiguousBands.join(', ')}',
    );
  }
  return parts.join('\n');
}

class DescriptionFolderImportResult {
  const DescriptionFolderImportResult({
    required this.added,
    required this.updated,
    required this.skippedExisting,
    required this.ambiguousBands,
  });

  final int added;
  final int updated;
  final List<String> skippedExisting;
  final List<String> ambiguousBands;

  String get message => formatDescriptionFolderImportMessage(
        added: added,
        updated: updated,
        skippedExisting: skippedExisting,
        ambiguousBands: ambiguousBands,
      );
}
