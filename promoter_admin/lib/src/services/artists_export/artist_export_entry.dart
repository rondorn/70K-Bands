import 'dart:typed_data';

import 'package:promoter_admin/src/models/festival_workspace.dart';

/// One artist cell for lineup export (sorted A–Z by [name]).
class ArtistExportEntry {
  const ArtistExportEntry({
    required this.name,
    required this.imageUrl,
    required this.officialUrl,
    this.imageBytes,
  });

  final String name;
  final String imageUrl;
  final String officialUrl;
  final Uint8List? imageBytes;

  ArtistExportEntry copyWith({Uint8List? imageBytes}) {
    return ArtistExportEntry(
      name: name,
      imageUrl: imageUrl,
      officialUrl: officialUrl,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }

  static List<ArtistExportEntry> fromBands(Iterable<BandRow> bands) {
    final entries = bands
        .map((band) {
          final name = band.name.trim();
          if (name.isEmpty) return null;
          return ArtistExportEntry(
            name: name,
            imageUrl: ensureHttpUrl(band.fields['imageUrl'] ?? ''),
            officialUrl: ensureHttpUrl(band.fields['officalSite'] ?? ''),
          );
        })
        .whereType<ArtistExportEntry>()
        .toList();
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }
}

/// Restores `https://` for scheme-stripped lineup fields (`imageUrl`, `officalSite`).
String ensureHttpUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == ' ') return '';
  final lower = value.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return value;
  }
  return 'https://$value';
}
