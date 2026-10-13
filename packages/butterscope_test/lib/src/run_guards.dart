import 'package:butterscope/butterscope.dart';
import 'package:butterscope_test/src/guard_reader.dart';

/// The run guards, read at the run's start, each test's start and end, and
/// the run's end (`docs/DESIGN.md` section 7.2).
///
/// Every read happens outside a test's frames: before its start mark or
/// after its end mark. Frames between tests belong to no test, so the
/// reads cost no measured frame. Each guard is listed the first time it
/// fails; one failure is enough to void the run.
final class RunGuards {
  /// Creates the guards, reading through [_reader]. [appCommit] is the
  /// app's commit for the identity.
  new(this._reader, {required this.appCommit});

  final GuardReader _reader;

  /// The app's commit, or `unknown`.
  final String appCommit;

  final List<GuardFailure> _failures = [];
  RunIdentity? _identity;

  /// The guards that failed, in the order they first failed.
  List<GuardFailure> get failures => List.unmodifiable(_failures);

  /// What the run is measured on, once [atRunStart] has read it.
  RunIdentity get identity {
    final identity = _identity;
    if (identity == null) throw StateError('The run has not started.');
    return identity;
  }

  /// Stamps the identity and checks the build mode and the phone.
  Future<void> atRunStart() async {
    final device = await _reader.readDevice();
    final flutter = _reader.flutter;
    _identity = RunIdentity(
      platform: _reader.platform,
      device: device,
      buildMode: _reader.buildMode,
      flutterVersion: flutter.version,
      engineRevision: flutter.engineRevision,
      appCommit: appCommit,
      textScale: _reader.textScale,
      locale: _reader.locale,
    );
    if (_reader.buildMode == 'debug') {
      _fail(const GuardFailure(Guard.buildMode, 'run start', 'debug'));
    }
    _checkDevice(device, 'run start');
  }

  /// Checks the phone, the binding, and that the text scale and locale
  /// still match the identity, before the test named [test] starts.
  Future<void> atTestStart(String test) async {
    final at = 'start of $test';
    _checkDevice(await _reader.readDevice(), at);
    _checkBinding(at);
    final textScale = _reader.textScale;
    if (textScale != identity.textScale) {
      _fail(GuardFailure(Guard.textScale, at, '$textScale'));
    }
    final locale = _reader.locale;
    if (locale != identity.locale) {
      _fail(GuardFailure(Guard.locale, at, locale));
    }
  }

  /// Checks the binding after the test named [test] ends, which catches a
  /// test that changed the frame policy itself.
  void atTestEnd(String test) => _checkBinding('end of $test');

  /// Checks the phone once more after the last test.
  Future<void> atRunEnd() async {
    _checkDevice(await _reader.readDevice(), 'run end');
  }

  void _checkDevice(DeviceState? device, String at) {
    if (device == null) {
      _fail(GuardFailure(Guard.deviceState, at));
      return;
    }
    // An Android phone before 10 cannot say: that is not nominal either.
    if (device.thermalNominal != true && device.thermal != _iosFair) {
      _fail(GuardFailure(Guard.thermal, at, device.thermal ?? 'unknown'));
    }
    if (device.lowPower) _fail(GuardFailure(Guard.lowPower, at));
  }

  /// iOS's `fair` state leaves a run valid
  /// (`docs/decisions/0007-m6-guard-findings.md`). Apple calls it slightly
  /// elevated, and `serious` the state where performance may suffer
  /// (`ProcessInfo.ThermalState`). An iPhone reads it within minutes on
  /// its cable, and runs at fair lost about as many frames as at nominal.
  /// The run's identity still records it.
  static const String _iosFair = 'fair';

  void _checkBinding(String at) {
    if (!_reader.benchmarkLive) _fail(GuardFailure(Guard.framePolicy, at));
    if (_reader.animationsOff) _fail(GuardFailure(Guard.animations, at));
  }

  void _fail(GuardFailure failure) {
    if (_failures.any((seen) => seen.guard == failure.guard)) return;
    _failures.add(failure);
  }
}
