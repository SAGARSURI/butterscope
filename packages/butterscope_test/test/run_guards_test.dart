import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/run_guards.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_run.dart';

void main() {
  late FakeGuardReader reader;
  late RunGuards guards;

  setUp(() {
    reader = FakeGuardReader();
    guards = RunGuards(reader, appCommit: 'abc');
  });

  List<List<Object?>> reasons() {
    return [for (final failure in guards.failures) failure.toJson()];
  }

  DeviceState deviceWith({
    String? thermal = 'none',
    bool? thermalNominal = true,
    bool lowPower = false,
  }) {
    return DeviceState(
      model: 'iPhone18,1',
      osVersion: 'iOS 27.0.1',
      thermal: thermal,
      thermalNominal: thermalNominal,
      lowPower: lowPower,
    );
  }

  test('a clean phone fails nothing, start to end', () async {
    await guards.atRunStart();
    await guards.atTestStart('opens');
    guards.atTestEnd('opens');
    await guards.atRunEnd();
    expect(guards.failures, isEmpty);
    expect(guards.identity.appCommit, 'abc');
  });

  test('a debug build fails at the run start', () async {
    reader.buildMode = 'debug';
    await guards.atRunStart();
    expect(reasons(), [
      ['buildMode', 'run start', 'debug'],
    ]);
  });

  test('a phone without the plugin fails the device read', () async {
    reader.device = null;
    await guards.atRunStart();
    expect(reasons(), [
      ['deviceState', 'run start'],
    ]);
    expect(guards.identity.device, isNull);
  });

  test('a warm phone fails, naming its state', () async {
    reader.device = deviceWith(thermal: 'serious', thermalNominal: false);
    await guards.atRunStart();
    expect(reasons(), [
      ['thermal', 'run start', 'serious'],
    ]);
  });

  test('an iPhone at fair is stamped, not failed', () async {
    reader.device = deviceWith(thermal: 'fair', thermalNominal: false);
    await guards.atRunStart();
    await guards.atTestStart('opens');
    await guards.atRunEnd();
    expect(guards.failures, isEmpty);
    expect(guards.identity.toJson()['thermalAtStart'], 'fair');
  });

  test("an Android phone's lightest throttling still fails", () async {
    reader.device = deviceWith(thermal: 'light', thermalNominal: false);
    await guards.atRunStart();
    expect(reasons(), [
      ['thermal', 'run start', 'light'],
    ]);
  });

  test('a phone that cannot report its thermal state fails', () async {
    reader.device = deviceWith(thermal: null, thermalNominal: null);
    await guards.atRunStart();
    expect(reasons(), [
      ['thermal', 'run start', 'unknown'],
    ]);
  });

  test('power saving turned on mid-run fails at the next test', () async {
    await guards.atRunStart();
    reader.device = deviceWith(lowPower: true);
    await guards.atTestStart('opens');
    expect(reasons(), [
      ['lowPower', 'start of opens'],
    ]);
  });

  test('a test that leaves the frame policy fails at its end', () async {
    await guards.atRunStart();
    await guards.atTestStart('opens');
    reader.benchmarkLive = false;
    guards.atTestEnd('opens');
    expect(reasons(), [
      ['framePolicy', 'end of opens'],
    ]);
  });

  test('animations turned off fail', () async {
    reader.animationsOff = true;
    await guards.atRunStart();
    await guards.atTestStart('opens');
    expect(reasons(), [
      ['animations', 'start of opens'],
    ]);
  });

  test('a text scale or locale that changes mid-run fails', () async {
    await guards.atRunStart();
    reader
      ..textScale = 1.3
      ..locale = 'de-DE';
    await guards.atTestStart('opens');
    expect(reasons(), [
      ['textScale', 'start of opens', '1.3'],
      ['locale', 'start of opens', 'de-DE'],
    ]);
  });

  test('a text scale other than 1 is stamped, not failed', () async {
    reader.textScale = 1.3;
    await guards.atRunStart();
    await guards.atTestStart('opens');
    expect(guards.failures, isEmpty);
    expect(guards.identity.textScale, 1.3);
  });

  test('each guard is listed once, where it first failed', () async {
    reader.device = deviceWith(lowPower: true);
    await guards.atRunStart();
    await guards.atTestStart('opens');
    await guards.atRunEnd();
    expect(reasons(), [
      ['lowPower', 'run start'],
    ]);
  });
}
