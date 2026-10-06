// Host side of integration_test/m4_overlay_test.dart: saves the
// screenshots the test took on the phone to build/m4_overlay/incoming/,
// where tool/m4/run_overlay.sh collects them.

import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      final shots = (data?['screenshots'] as List<dynamic>?) ?? const [];
      for (final shot in shots.cast<Map<String, dynamic>>()) {
        final name = shot['screenshotName'] as String;
        final file = File('build/m4_overlay/incoming/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes((shot['bytes'] as List<dynamic>).cast<int>());
        stdout.writeln('Saved ${file.path}');
      }
    },
  );
}
