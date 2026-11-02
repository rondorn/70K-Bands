import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/description_link_markup.dart';
import 'package:promoter_admin/src/theme/app_theme.dart';
import 'package:promoter_admin/src/widgets/description_body_field.dart';

void main() {
  test('plain https addresses are stored with the !!!! marker', () {
    expect(
      descriptionTextForStorage(
        'Line one.\nhttps://example.com/a\nLine three.',
      ),
      'Line one.\n!!!!https://example.com/a\nLine three.',
    );
  });

  test('an address already marked is not marked twice', () {
    const stored = 'See !!!!https://example.com/band today.';
    expect(descriptionTextForStorage(stored), stored);
    expect(
      descriptionTextForEditing(stored),
      'See https://example.com/band today.',
    );
    expect(
      descriptionTextForStorage(descriptionTextForEditing(stored)),
      stored,
    );
  });

  test('extra exclamation marks collapse to the four the apps recognize', () {
    expect(
      descriptionTextForStorage('!!!!!!!!https://example.com/x'),
      '!!!!https://example.com/x',
    );
  });

  test('http addresses and words ending in https are left alone', () {
    const text = 'Visit http://example.com or nothttps://example.com.';
    expect(descriptionTextForStorage(text), text);
    expect(descriptionLinkUrls(text), isEmpty);
  });

  test('two addresses are both marked and listed once each', () {
    const text =
        'https://a.example/1 and HTTPS://a.example/1\n'
        'https://b.example/2';
    expect(
      descriptionTextForStorage(text),
      '!!!!https://a.example/1 and !!!!https://a.example/1\n'
      '!!!!https://b.example/2',
    );
    expect(descriptionLinkUrls(text), [
      'https://a.example/1',
      'https://b.example/2',
    ]);
  });

  test('pasting a marked address keeps the cursor after the url', () {
    const original = 'Notes\n!!!!https://example.com/band\nMore';
    final endOfUrl = original.indexOf('\nMore');
    expect(
      mapDescriptionEditingOffset(original, endOfUrl),
      descriptionTextForEditing(original).indexOf('\nMore'),
    );
    expect(
      mapDescriptionEditingOffset(original, original.indexOf('!!!!') + 2),
      descriptionTextForEditing(original).indexOf('https://'),
    );

    final value = descriptionEditingValue(
      TextEditingValue(
        text: original,
        selection: TextSelection.collapsed(offset: endOfUrl),
      ),
    );
    expect(value.text.contains('!!!!'), isFalse);
    expect(value.selection.baseOffset, value.text.indexOf('\nMore'));
  });

  testWidgets('editor hides the marker and highlights the address', (
    tester,
  ) async {
    final controller = TextEditingController(
      text: 'Bio\n!!!!https://example.com/band\n',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DescriptionBodyField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
          ),
        ),
      ),
    );

    expect(controller.text, 'Bio\nhttps://example.com/band\n');
    expect(controller.text.contains('!!!!'), isFalse);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'https://example.com/band' &&
            widget.style?.color == AppColors.accent,
      ),
      findsOneWidget,
    );
  });
}
