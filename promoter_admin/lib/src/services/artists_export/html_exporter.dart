import 'dart:convert';
import 'dart:typed_data';

import 'package:promoter_admin/src/services/artists_export/artist_export_entry.dart';
import 'package:promoter_admin/src/services/artists_export/logo_fetcher.dart';

class ArtistsHtmlExporter {
  const ArtistsHtmlExporter._();

  static Uint8List build({
    required List<ArtistExportEntry> artists,
    required String festivalName,
    String year = '',
    Uint8List? festivalLogoBytes,
    String festivalLogoMimeType = 'image/png',
    bool useColor = true,
  }) {
    final titleYear = year.trim().isEmpty ? '' : ' $year';
    final html = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="en"><head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln('<meta name="viewport" content="width=device-width">')
      ..writeln(
        '<title>${_escape(festivalName)}$titleYear Lineup</title>',
      )
      ..writeln('<style>${_styles()}</style>')
      ..writeln('</head>')
      ..writeln(
        '<body class="${useColor ? 'color' : 'monochrome'}">',
      )
      ..writeln('<main class="lineup">')
      ..writeln('<header class="brand">');

    if (festivalLogoBytes != null) {
      html.writeln(
        '<img class="festival-logo" alt="${_escape(festivalName)}" '
        'src="data:$festivalLogoMimeType;base64,'
        '${base64Encode(festivalLogoBytes)}">',
      );
    } else {
      html.writeln('<h1>${_escape(festivalName)}</h1>');
    }
    if (year.trim().isNotEmpty) {
      html.writeln('<p class="year">${_escape(year.trim())}</p>');
    }
    html
      ..writeln('<p class="count">${artists.length} bands</p>')
      ..writeln('</header>')
      ..writeln('<section class="grid" aria-label="Lineup">');

    for (final artist in artists) {
      final title = _escape(artist.name);
      final mime = logoMimeType(artist.imageUrl);
      final inner = artist.imageBytes == null
          ? '<span class="name-fallback">$title</span>'
          : '<img src="data:$mime;base64,'
                '${base64Encode(artist.imageBytes!)}" '
                'alt="$title" loading="lazy">';

      if (artist.officialUrl.isEmpty) {
        html.writeln(
          '<div class="cell" title="$title">$inner</div>',
        );
      } else {
        html.writeln(
          '<a class="cell" href="${_escapeAttr(artist.officialUrl)}" '
          'target="_blank" rel="noopener noreferrer" title="$title">'
          '$inner</a>',
        );
      }
    }

    html
      ..writeln('</section>')
      ..writeln('</main>')
      ..writeln('</body></html>');
    return Uint8List.fromList(utf8.encode(html.toString()));
  }

  static String _styles() => '''
:root {
  color-scheme: dark;
  --bg: #050505;
  --fg: #f2f2f2;
  --muted: #9a9a9a;
  --cell: #0d0d0d;
  --border: #222;
}
* { box-sizing: border-box; }
html, body {
  margin: 0;
  padding: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
}
body.monochrome img {
  filter: grayscale(1);
}
.lineup {
  max-width: 1100px;
  margin: 0 auto;
  padding: 36px 28px 64px;
}
.brand {
  text-align: center;
  margin-bottom: 28px;
}
.festival-logo {
  display: block;
  max-height: 96px;
  max-width: min(420px, 80vw);
  width: auto;
  height: auto;
  margin: 0 auto 12px;
  object-fit: contain;
}
.brand h1 {
  margin: 0 0 8px;
  font-size: 1.8rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.year {
  margin: 0;
  font-size: 1.05rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--muted);
}
.count {
  margin: 10px 0 0;
  font-size: 0.85rem;
  color: var(--muted);
}
.grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 18px 16px;
}
.cell {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 110px;
  padding: 14px;
  background: var(--cell);
  border: 1px solid var(--border);
  text-decoration: none;
  color: inherit;
  transition: border-color 0.15s ease, transform 0.15s ease;
}
a.cell:hover {
  border-color: #666;
  transform: translateY(-1px);
}
.cell img {
  display: block;
  max-width: 100%;
  max-height: 88px;
  width: auto;
  height: auto;
  object-fit: contain;
}
.name-fallback {
  display: block;
  text-align: center;
  font-size: 0.85rem;
  line-height: 1.25;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--fg);
  word-break: break-word;
}
@media (max-width: 720px) {
  .grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 420px) {
  .grid { grid-template-columns: 1fr; }
}
''';

  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  static String _escapeAttr(String value) => _escape(value).replaceAll("'", '&#39;');
}
