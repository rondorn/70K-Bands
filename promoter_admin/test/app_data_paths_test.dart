import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:promoter_admin/src/services/app_data_paths.dart';
import 'package:promoter_admin/src/services/durable_json_store.dart';

void main() {
  tearDown(() {
    AppDataPaths.debugICloudProbeOverride = null;
    AppDataPaths.resetICloudConfiguredCache();
  });

  group('AppDataPaths.iCloudReady', () {
    test('caches not-configured so iCloud is not retried this launch', () async {
      var probes = 0;
      AppDataPaths.debugICloudProbeOverride = () async {
        probes++;
        return false;
      };

      expect(await AppDataPaths.iCloudReady(), isFalse);
      expect(await AppDataPaths.iCloudReady(), isFalse);
      expect(probes, 1);
    });

    test('caches configured when container probe succeeds', () async {
      var probes = 0;
      AppDataPaths.debugICloudProbeOverride = () async {
        probes++;
        return true;
      };

      expect(await AppDataPaths.iCloudReady(), isTrue);
      expect(await AppDataPaths.iCloudReady(), isTrue);
      expect(probes, 1);
    });
  });

  group('ConfigDocumentStore without iCloud', () {
    test('writes and reads local file only', () async {
      AppDataPaths.debugICloudProbeOverride = () async => false;

      final dir = await Directory.systemTemp.createTemp('omf-local-config-');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/festival_registry.json');

      const store = ConfigDocumentStore();
      await store.writeDocument(
        iCloudRelativePath: AppDataPaths.registryRelativePath,
        localFile: () async => file,
        contents: '{"activeFestivalId":"festival-1","festivals":{}}\n',
      );

      expect(await file.exists(), isTrue);
      final text = await store.readDocument(
        iCloudRelativePath: AppDataPaths.registryRelativePath,
        localFile: () async => file,
      );
      expect(text, contains('festival-1'));
    });
  });
}
