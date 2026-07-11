/// Shared CSV helpers (lineup, schedule, description map).
List<String> parseCsvLine(String line) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buffer.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      result.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(ch);
    }
  }
  result.add(buffer.toString());
  return result;
}

String escapeCsv(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

List<Map<String, String>> parseCsvMaps(String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return [];
  final headers = parseCsvLine(lines.first);
  final rows = <Map<String, String>>[];
  for (var i = 1; i < lines.length; i++) {
    final values = parseCsvLine(lines[i]);
    final map = <String, String>{};
    for (var c = 0; c < headers.length; c++) {
      map[headers[c]] = c < values.length ? values[c] : '';
    }
    rows.add(map);
  }
  return rows;
}

String mapsToCsv(List<String> fields, List<Map<String, String>> rows) {
  final buffer = StringBuffer()..writeln(fields.join(','));
  for (final row in rows) {
    buffer.writeln(fields.map((f) => escapeCsv(row[f] ?? '')).join(','));
  }
  return buffer.toString();
}
