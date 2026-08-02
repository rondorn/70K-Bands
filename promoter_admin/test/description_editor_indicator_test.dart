import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/widgets/description_editor_indicator.dart';

void main() {
  group('descriptionEditorKind', () {
    test('matches current account case-insensitively', () {
      expect(
        descriptionEditorKind(
          updatedBy: 'Editor@Example.com',
          currentAccount: 'editor@example.com',
        ),
        DescriptionEditorKind.mine,
      );
    });

    test('treats empty updatedBy as unknown', () {
      expect(
        descriptionEditorKind(
          updatedBy: '',
          currentAccount: 'editor@example.com',
        ),
        DescriptionEditorKind.unknown,
      );
    });

    test('treats different account as other', () {
      expect(
        descriptionEditorKind(
          updatedBy: 'bot@example.com',
          currentAccount: 'editor@example.com',
        ),
        DescriptionEditorKind.other,
      );
    });
  });

  group('descriptionEditorShortLabel', () {
    test('shows email local part for any editor', () {
      expect(
        descriptionEditorShortLabel('rdorn@gmail.com'),
        'rdorn',
      );
      expect(
        descriptionEditorShortLabel('bot@example.com'),
        'bot',
      );
    });

    test('shows Unknown when editor is empty', () {
      expect(descriptionEditorShortLabel(''), 'Unknown');
    });
  });
}
