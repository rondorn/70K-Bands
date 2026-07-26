/// Helpers for festival stats report URLs from the production pointer.
class ReportUrls {
  ReportUrls._();

  /// Derive the full-dashboard URL from the end-user URL when the pointer
  /// has no explicit `reportUrlFull` entry.
  ///
  /// `report_dashboard_2027.html` → `report_dashboard_full_2027.html`
  static String deriveFullReportUrl(String reportUrl) {
    final trimmed = reportUrl.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return trimmed;

    final filename = segments.last;
    if (filename.contains('_full')) return trimmed;

    final dot = filename.lastIndexOf('.');
    if (dot <= 0) return trimmed;

    final stem = filename.substring(0, dot);
    final ext = filename.substring(dot);
    final yearMatch = RegExp(r'_(\d{4})$').firstMatch(stem);
    final derivedName = yearMatch != null
        ? '${stem.substring(0, yearMatch.start)}_full_${yearMatch.group(1)}$ext'
        : '${stem}_full$ext';

    final rebuilt = [...segments];
    rebuilt[rebuilt.length - 1] = derivedName;
    return uri.replace(pathSegments: rebuilt).toString();
  }
}
