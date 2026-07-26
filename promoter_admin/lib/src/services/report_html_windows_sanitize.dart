import 'dart:io';

/// Prepare downloaded report HTML for the current platform.
///
/// Windows WebView2 often renders emoji as garbage (flags show as two-letter
/// codes; pictographs like 🍎/🤖 fail similarly). Strip emoji on Windows only;
/// phones and macOS keep the original HTML for offline use.
String prepareReportHtmlForPlatform(String html) {
  if (!Platform.isWindows) {
    return html;
  }
  return stripWindowsUnrenderedEmoji(html);
}

/// Remove emoji sequences used in festival report HTML (tab icons, flags,
/// platform labels, etc.).
String stripWindowsUnrenderedEmoji(String html) {
  // Flags: two regional indicators. Dart RegExp needs two char classes, not {2}.
  const flagPair = r'[\u{1F1E6}-\u{1F1FF}][\u{1F1E6}-\u{1F1FF}](?:\u{FE0F})?\s*';
  // Tab icons, 🍎 iOS, 🤖 Android, ⚙️, etc.
  const emojiCluster =
      r'(?:\p{Extended_Pictographic}(?:\u{FE0F})?(?:\u{200D}\p{Extended_Pictographic}(?:\u{FE0F})?)*)+\s*';

  var result = html.replaceAll(
    RegExp('$flagPair|$emojiCluster', unicode: true),
    '',
  );

  // Leftover space after stripped emoji at start of text nodes.
  result = result.replaceAll(RegExp(r'(?<=>)\s+'), '');

  return result;
}
