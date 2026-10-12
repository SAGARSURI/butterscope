import 'package:butterscope/src/device_state.dart';

/// What a run was measured on, stamped once at its start
/// (`docs/DESIGN.md` section 7.3).
///
/// Two runs are compared only when every field but [appCommit] matches.
/// Comparing is M9's; M6 only stamps it.
final class RunIdentity {
  /// Creates an identity, for example in a test.
  const new({
    required this.platform,
    required this.device,
    required this.buildMode,
    required this.flutterVersion,
    required this.engineRevision,
    required this.appCommit,
    required this.textScale,
    required this.locale,
  });

  /// The operating system: `android` or `ios`.
  final String platform;

  /// The phone's state at the run's start, or `null` when it could not be
  /// read. Its model, OS version and thermal state are identity fields.
  final DeviceState? device;

  /// `debug`, `profile` or `release`.
  final String buildMode;

  /// The Flutter version the app was built with, or `null` when the build
  /// did not define it. The `flutter` tool defines it in every build.
  final String? flutterVersion;

  /// The engine revision the app was built with, or `null` when the build
  /// did not define it.
  final String? engineRevision;

  /// The app's commit, passed with
  /// `--dart-define=BUTTERSCOPE_APP_COMMIT=<sha>`, or `unknown`.
  final String appCommit;

  /// The text scale at the run's start.
  final double textScale;

  /// The locale at the run's start, such as `en-GB`.
  final String locale;

  /// The identity as a JSON-ready map.
  Map<String, Object?> toJson() {
    return {
      'platform': platform,
      'model': device?.model,
      'osVersion': device?.osVersion,
      'buildMode': buildMode,
      'thermalAtStart': device?.thermal,
      'flutterVersion': flutterVersion,
      'engineRevision': engineRevision,
      'appCommit': appCommit,
      'textScale': textScale,
      'locale': locale,
    };
  }
}
