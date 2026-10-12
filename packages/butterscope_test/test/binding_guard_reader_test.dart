// BindingGuardReader against the real test binding: what it reads for
// semantics and the platform, and that a phone it cannot read gives no
// state.

import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/guard_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// A phone whose state read throws [error].
final class _ThrowingSource implements DeviceStateSource {
  const new(this.error);

  final Exception error;

  @override
  Future<DeviceState> read() async => throw error;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  GuardReader readerThrowing(Exception error) {
    return BindingGuardReader(binding, _ThrowingSource(error));
  }

  final reader = readerThrowing(MissingPluginException());

  testWidgets('reads semantics on where testWidgets turns it on', (_) async {
    // testWidgets's handle sets the binding's flag, not the platform's.
    expect(binding.platformDispatcher.semanticsEnabled, isFalse);
    expect(reader.semanticsOn, isTrue);
  });

  testWidgets('reads semantics off where the test turns it off', (_) async {
    expect(reader.semanticsOn, isFalse);
  }, semanticsEnabled: false);

  testWidgets('names the platform the way the report does', (_) async {
    final names = <String>[];
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      names.add(reader.platform);
    }
    debugDefaultTargetPlatformOverride = null;

    expect(names, ['android', 'ios']);
  });

  test('gives no state when the phone cannot be read', () async {
    expect(await reader.readDevice(), isNull);
    expect(
      await readerThrowing(PlatformException(code: 'x')).readDevice(),
      isNull,
    );
    expect(
      await readerThrowing(const FormatException('x')).readDevice(),
      isNull,
    );
  });
}
