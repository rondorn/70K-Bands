import 'package:flutter/services.dart';

/// Fan apps treat `!!!!https://…` as a link and hide the `!!!!` when showing it.
///
/// The marker runs until the next space. A line break after the address is kept
/// as written; the apps do not require one.
final RegExp descriptionLinkPattern = RegExp(
  r'(?<![\w!])(?:!{4,})?https://\S+',
  caseSensitive: false,
);

/// Text for the editor: `!!!!https://…` is shown as `https://…`.
String descriptionTextForEditing(String text) {
  return text.replaceAllMapped(descriptionLinkPattern, (match) {
    return _httpsUrl(match.group(0)!);
  });
}

/// Text stored in the description file. Each web address gets the `!!!!` marker.
String descriptionTextForStorage(String text) {
  return text.replaceAllMapped(descriptionLinkPattern, (match) {
    return '!!!!${_httpsUrl(match.group(0)!)}';
  });
}

/// Web addresses in [text], without the `!!!!` marker, in order, without duplicates.
List<String> descriptionLinkUrls(String text) {
  final seen = <String>{};
  final urls = <String>[];
  for (final match in descriptionLinkPattern.allMatches(text)) {
    final url = _httpsUrl(match.group(0)!);
    if (seen.add(url)) urls.add(url);
  }
  return urls;
}

/// Maps a cursor in stored or pasted text onto [descriptionTextForEditing].
int mapDescriptionEditingOffset(String original, int offset) {
  final maxOut = descriptionTextForEditing(original).length;
  if (offset <= 0) return 0;
  if (offset > original.length) return maxOut;

  var sourceIndex = 0;
  var editedIndex = 0;
  for (final match in descriptionLinkPattern.allMatches(original)) {
    if (offset <= match.start) {
      return editedIndex + (offset - sourceIndex);
    }
    editedIndex += match.start - sourceIndex;
    final raw = match.group(0)!;
    final bangs = _leadingBangCount(raw);
    if (offset <= match.start + bangs) return editedIndex;
    if (offset <= match.end) {
      return editedIndex + (offset - match.start - bangs);
    }
    editedIndex += raw.length - bangs;
    sourceIndex = match.end;
  }
  final mapped = editedIndex + (offset - sourceIndex);
  if (mapped < 0) return 0;
  if (mapped > maxOut) return maxOut;
  return mapped;
}

/// Editor value with `!!!!` removed and the cursor kept on the same character.
TextEditingValue descriptionEditingValue(TextEditingValue value) {
  final nextText = descriptionTextForEditing(value.text);
  if (nextText == value.text) return value;
  return TextEditingValue(
    text: nextText,
    selection: TextSelection(
      baseOffset: mapDescriptionEditingOffset(
        value.text,
        value.selection.baseOffset,
      ),
      extentOffset: mapDescriptionEditingOffset(
        value.text,
        value.selection.extentOffset,
      ),
    ),
  );
}

String _httpsUrl(String raw) {
  var rest = raw;
  while (rest.startsWith('!')) {
    rest = rest.substring(1);
  }
  rest = rest.replaceFirst(RegExp(r'^https://', caseSensitive: false), '');
  return 'https://$rest';
}

int _leadingBangCount(String raw) {
  var count = 0;
  while (count < raw.length && raw[count] == '!') {
    count++;
  }
  return count;
}
