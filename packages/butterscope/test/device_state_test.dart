import 'package:butterscope/butterscope.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('butterscope/device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async => handler(call));
  }

  test('reads what the plugin sends for a phone', () async {
    final calls = <String>[];
    answer((call) {
      calls.add(call.method);
      return {
        'model': 'samsung SM-S921B',
        'osVersion': 'Android 16 (API 36)',
        'thermal': 'none',
        'thermalNominal': true,
        'lowPower': false,
      };
    });

    final state = await const ChannelDeviceStateSource().read();
    expect(calls, ['read']);
    expect(state.model, 'samsung SM-S921B');
    expect(state.osVersion, 'Android 16 (API 36)');
    expect(state.thermal, 'none');
    expect(state.thermalNominal, isTrue);
    expect(state.lowPower, isFalse);
    expect(state.toJson(), {
      'model': 'samsung SM-S921B',
      'osVersion': 'Android 16 (API 36)',
      'thermal': 'none',
      'thermalNominal': true,
      'lowPower': false,
    });
  });

  test('keeps an unknown thermal state as unknown', () async {
    // Android before 10 has no thermal status, so the plugin sends nulls.
    answer(
      (_) => {
        'model': 'x y',
        'osVersion': 'Android 9 (API 28)',
        'thermal': null,
        'thermalNominal': null,
        'lowPower': true,
      },
    );

    final state = await const ChannelDeviceStateSource().read();
    expect(state.thermal, isNull);
    expect(state.thermalNominal, isNull);
    expect(state.lowPower, isTrue);
  });

  test('fails loudly on a missing or mistyped field', () async {
    answer((_) => {'model': 'iPhone18,1', 'osVersion': 'iOS 26.1'});
    await expectLater(
      const ChannelDeviceStateSource().read(),
      throwsA(isA<FormatException>()),
    );

    answer(
      (_) => {
        'model': 'iPhone18,1',
        'osVersion': 'iOS 26.1',
        'thermal': 'fair',
        'thermalNominal': 'no',
        'lowPower': false,
      },
    );
    await expectLater(
      const ChannelDeviceStateSource().read(),
      throwsA(isA<FormatException>()),
    );
  });

  test('fails when the app was built without the plugin', () async {
    // No handler: what a release build without the plugin sees.
    await expectLater(
      const ChannelDeviceStateSource().read(),
      throwsA(isA<MissingPluginException>()),
    );
  });
}
