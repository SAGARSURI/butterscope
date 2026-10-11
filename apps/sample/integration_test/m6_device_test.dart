// M6's smoke check of the native device reads: prints what the plugin in
// `package:butterscope` reports, once a second for 10 s, so the values can
// be checked against the phone's own settings screens. Run it with:
//
//   flutter drive --profile --no-dds --keep-app-running \
//     --driver test_driver/integration_test.dart \
//     --target integration_test/m6_device_test.dart -d <device-id>
//
// Each read is one BSCOPE-DEVICE line of JSON.

import 'dart:convert';

import 'package:butterscope/butterscope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reads the device state', semanticsEnabled: false, (_) async {
    const source = ChannelDeviceStateSource();
    for (var second = 0; second < 10; second++) {
      final state = await source.read();
      debugPrint('BSCOPE-DEVICE ${jsonEncode(state.toJson())}');
      expect(state.model, isNotEmpty);
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  });
}
