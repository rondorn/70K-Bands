import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/festival_create_service.dart';

void main() {
  test('defaultFolderForName uses legacy {name}_Public at Dropbox root', () {
    expect(
      FestivalCreateService.defaultFolderForName('Redwood Metafest'),
      '/Redwood Metafest_Public',
    );
    expect(FestivalCreateService.defaultFolderForName('MDF'), '/MDF_Public');
    expect(FestivalCreateService.defaultFolderForName('  '), '/Festival_Public');
  });

  test('split access folders use {name}_Master|Artist|Schedule|Description|Alert_Files', () {
    expect(
      FestivalCreateService.masterFilesFolderForName('Maryland Deathfest'),
      '/Maryland Deathfest_MasterFiles',
    );
    expect(
      FestivalCreateService.artistFilesFolderForName('Maryland Deathfest'),
      '/Maryland Deathfest_Artist_Files',
    );
    expect(
      FestivalCreateService.scheduleFilesFolderForName('Maryland Deathfest'),
      '/Maryland Deathfest_Schedule_Files',
    );
    expect(
      FestivalCreateService.descriptionFilesFolderForName('Maryland Deathfest'),
      '/Maryland Deathfest_Description_Files',
    );
    expect(
      FestivalCreateService.alertFilesFolderForName('Maryland Deathfest'),
      '/Maryland Deathfest_Alert_Files',
    );
    expect(
      FestivalCreateService.localAlertSyncPathHint('Maryland Deathfest'),
      '~/Library/CloudStorage/Dropbox/Maryland Deathfest_Alert_Files',
    );
  });

  test('defaultFilePrefix uses initials for multi-word names', () {
    expect(
      FestivalCreateService.defaultFilePrefix('Maryland Deathfest'),
      'md',
    );
    expect(FestivalCreateService.defaultFilePrefix('MDF'), 'mdf');
  });

  test('normalizeFolder requires leading slash', () {
    expect(FestivalCreateService.normalizeFolder('Foo_Public'), '/Foo_Public');
    expect(FestivalCreateService.normalizeFolder('/Foo_Public/'), '/Foo_Public');
  });

  test('placeholder filenames match MDF-style testing and production', () {
    expect(
      FestivalCreateService.artistLineupName('mdf', '2027', testing: false),
      'mdf_artistLineup_2027.csv',
    );
    expect(
      FestivalCreateService.artistLineupName('mdf', '2027', testing: true),
      'mdf_artistLineup_2027_test.csv',
    );
    expect(
      FestivalCreateService.scheduleName('mdf', '2027', testing: false),
      'mdf_artistsSchedule2027.csv',
    );
    expect(
      FestivalCreateService.scheduleName('mdf', '2027', testing: true),
      'mdf_artistsSchedule2027_test.csv',
    );
    expect(
      FestivalCreateService.descriptionMapName('mdf', '2027', testing: false),
      'mdf_descriptionMap2027.csv',
    );
    expect(
      FestivalCreateService.descriptionMapName('mdf', '2027', testing: true),
      'mdf_descriptionMap2027_test.csv',
    );
  });

  test('buildPointerText includes Current and year schedule lines', () {
    final text = FestivalCreateService.buildPointerText(
      eventYear: '2027',
      bandListUrl: 'https://example.com/lineup?raw=1',
      scheduleUrl: 'https://example.com/schedule?raw=1',
      descriptionMapUrl: 'https://example.com/map?raw=1',
    );
    expect(text, contains('Current::artistUrl::https://example.com/lineup?raw=1'));
    expect(text, contains('Current::eventYear::2027'));
    expect(text, contains('2027::scheduleUrl::https://example.com/schedule?raw=1'));
  });
}
