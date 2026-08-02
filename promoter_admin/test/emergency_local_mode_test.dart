import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/models/emergency_local_paths.dart';
import 'package:promoter_admin/src/models/festival_workspace.dart';
import 'package:promoter_admin/src/services/emergency_local_mode_support.dart';
import 'package:promoter_admin/src/services/local_content_store.dart';

void main() {
  test('FestivalWorkspace persists Local File Mode fields', () {
    const ws = FestivalWorkspace(
      festivalName: 'Test Fest',
      emergencyLocalMode: true,
      emergencyLocalPaths: EmergencyLocalPaths(
        artistsCsv: '/tmp/artists.csv',
        scheduleCsv: '/tmp/schedule.csv',
      ),
    );
    final restored = FestivalWorkspace.fromPrefs(ws.toPrefs());
    expect(restored.emergencyLocalMode, isTrue);
    expect(restored.emergencyLocalPaths.artistsCsv, '/tmp/artists.csv');
    expect(restored.emergencyLocalPaths.scheduleCsv, '/tmp/schedule.csv');
    expect(restored.isConfigured, isTrue);
  });

  test('isConfigured stays Dropbox-first when Local File Mode is off', () {
    const ws = FestivalWorkspace(festivalName: 'Test Fest');
    expect(ws.isConfigured, isFalse);
    const configured = FestivalWorkspace(
      festivalName: 'Test Fest',
      testingPointerUrl: 'https://example.com/pointer.txt',
    );
    expect(configured.isConfigured, isTrue);
  });

  test('LocalContentStore read/write round trip', () async {
    final dir = await Directory.systemTemp.createTemp('omf_local_test_');
    final file = File('${dir.path}/lineup.csv');
    await LocalContentStore.writeText(file.path, 'bandName,genre\nBand A,Metal\n');
    final text = await LocalContentStore.readText(file.path);
    expect(text, contains('Band A'));
    await dir.delete(recursive: true);
  });

  test('LocalContentStore.isLocalLocator distinguishes paths from URLs', () {
    expect(LocalContentStore.isLocalLocator('/tmp/a.csv'), isTrue);
    expect(LocalContentStore.isLocalLocator('~/Dropbox/a.csv'), isTrue);
    expect(
      LocalContentStore.isLocalLocator('https://example.com/a.csv'),
      isFalse,
    );
  });

  test('effective edit flags follow mapped paths in Local File Mode', () {
    const ws = FestivalWorkspace(
      emergencyLocalMode: true,
      emergencyLocalPaths: EmergencyLocalPaths(
        artistsCsv: '/tmp/a.csv',
      ),
      canEditBands: false,
    );
    if (emergencyLocalFileModeSupported) {
      expect(ws.effectiveCanEditBands, isTrue);
    } else {
      expect(ws.usesEmergencyLocalMode, isFalse);
      expect(ws.effectiveCanEditBands, isFalse);
    }
    expect(ws.effectiveCanEditSchedule, isFalse);
    expect(ws.effectiveReportsUiEnabled, isFalse);
  });
}
