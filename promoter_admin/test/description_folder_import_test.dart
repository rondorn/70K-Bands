import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/description_folder_import.dart';

void main() {
  group('descriptionImportStemKey', () {
    test('matches lathe.txt to Lathe', () {
      expect(descriptionImportStemKey('lathe.txt'), 'lathe');
      expect(descriptionImportStemKey('Lathe'), 'lathe');
    });

    test('matches Arch_Enemy.txt to Arch Enemy', () {
      expect(descriptionImportStemKey('Arch_Enemy.txt'), 'arch_enemy');
      expect(descriptionImportStemKey('Arch Enemy'), 'arch_enemy');
      expect(descriptionImportStemKey('Arch Enemy.txt'), 'arch_enemy');
    });
  });

  group('planDescriptionFolderImport', () {
    const lathe = DescriptionImportFile(
      fileName: 'lathe.txt',
      filePath: '/desc/lathe.txt',
    );

    test('links a unique lineup match', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Lathe', 'Warbringer'],
        files: const [lathe],
        existingUrlByBandLower: const {},
      );
      expect(plan.toLink, hasLength(1));
      expect(plan.toLink.single.bandName, 'Lathe');
      expect(plan.skippedExisting, isEmpty);
      expect(plan.ambiguousBands, isEmpty);
    });

    test('ignores txt files not in the lineup', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Warbringer'],
        files: const [lathe],
        existingUrlByBandLower: const {},
      );
      expect(plan.toLink, isEmpty);
      expect(plan.ambiguousBands, isEmpty);
    });

    test('ignores non-txt files even with a lineup match', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Lathe'],
        files: const [
          DescriptionImportFile(
            fileName: 'lathe.md',
            filePath: '/desc/lathe.md',
          ),
        ],
        existingUrlByBandLower: const {},
      );
      expect(plan.toLink, isEmpty);
    });

    test('skips existing map URLs when override is off', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Lathe'],
        files: const [lathe],
        existingUrlByBandLower: const {'lathe': 'https://example.com/old.txt'},
      );
      expect(plan.toLink, isEmpty);
      expect(plan.skippedExisting, ['Lathe']);
    });

    test('relinks existing map URLs when override is on', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Lathe'],
        files: const [lathe],
        existingUrlByBandLower: const {'lathe': 'https://example.com/old.txt'},
        overrideExisting: true,
      );
      expect(plan.toLink, hasLength(1));
      expect(plan.toLink.single.bandName, 'Lathe');
      expect(plan.skippedExisting, isEmpty);
    });

    test('treats empty existing URL as missing', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Lathe'],
        files: const [lathe],
        existingUrlByBandLower: const {'lathe': '  '},
      );
      expect(plan.toLink, hasLength(1));
    });

    test('does not flag duplicate lineup rows that have no matching file', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Lathe', 'Warbringer', 'Warbringer'],
        files: const [lathe],
        existingUrlByBandLower: const {},
      );
      expect(plan.toLink.single.bandName, 'Lathe');
      expect(plan.ambiguousBands, isEmpty);
    });

    test('does not link duplicate lineup rows and lists the band', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Lathe', 'Lathe', 'Warbringer'],
        files: const [lathe],
        existingUrlByBandLower: const {},
      );
      expect(plan.toLink, isEmpty);
      expect(plan.ambiguousBands, ['Lathe']);
    });

    test('does not link when two lineup names share a stem', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Arch Enemy', 'Arch_Enemy'],
        files: const [
          DescriptionImportFile(
            fileName: 'Arch_Enemy.txt',
            filePath: '/desc/Arch_Enemy.txt',
          ),
        ],
        existingUrlByBandLower: const {},
      );
      expect(plan.toLink, isEmpty);
      expect(plan.ambiguousBands, ['Arch Enemy', 'Arch_Enemy']);
    });

    test('does not link when two txt files match one band', () {
      final plan = planDescriptionFolderImport(
        lineupNames: const ['Lathe'],
        files: const [
          lathe,
          DescriptionImportFile(
            fileName: 'Lathe.txt',
            filePath: '/desc/Lathe.txt',
          ),
        ],
        existingUrlByBandLower: const {},
      );
      expect(plan.toLink, isEmpty);
      expect(plan.ambiguousBands, ['Lathe']);
    });
  });

  group('formatDescriptionFolderImportMessage', () {
    test('reports ambiguous bands for cleanup', () {
      final text = formatDescriptionFolderImportMessage(
        added: 2,
        updated: 0,
        skippedExisting: const ['Amorphis'],
        ambiguousBands: const ['Lathe', 'Warbringer'],
      );
      expect(text, contains('Added 2 description links.'));
      expect(text, contains('Skipped 1 band already on the map.'));
      expect(
        text,
        contains(
          'These bands have more than one entry (nothing was added for them).',
        ),
      );
      expect(text, contains('Lathe, Warbringer'));
    });

    test('says nothing to add when the folder had no usable files', () {
      expect(
        formatDescriptionFolderImportMessage(
          added: 0,
          updated: 0,
          skippedExisting: const [],
          ambiguousBands: const [],
        ),
        'No new description links to add.',
      );
    });
  });
}
