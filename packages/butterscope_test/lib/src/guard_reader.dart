import 'package:butterscope/butterscope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show FlutterVersion, MissingPluginException, PlatformException;
import 'package:flutter_test/flutter_test.dart';

/// Reads what the guards check (`docs/DESIGN.md` section 7.2).
///
/// Every read but [readDevice] is a getter on the binding or the platform
/// dispatcher. [readDevice] is one call to the plugin in
/// `package:butterscope`.
abstract interface class GuardReader {
  /// The operating system: `android` or `ios`.
  String get platform;

  /// `debug`, `profile` or `release`.
  String get buildMode;

  /// Whether the binding draws under `benchmarkLive`.
  bool get benchmarkLive;

  /// Whether the phone asks apps to turn animations off or reduce motion.
  bool get animationsOff;

  /// The text scale the phone sets.
  double get textScale;

  /// The phone's first locale, such as `en-GB`.
  String get locale;

  /// Whether the semantics tree is being built.
  bool get semanticsOn;

  /// The Flutter version and engine revision the app was built with.
  ({String? version, String? engineRevision}) get flutter;

  /// The phone's state, or `null` when it cannot be read.
  Future<DeviceState?> readDevice();
}

/// Reads the guards from [_binding] and the phone's state from [_device].
final class BindingGuardReader implements GuardReader {
  /// Creates a reader of [_binding] and [_device].
  new(this._binding, this._device);

  final LiveTestWidgetsFlutterBinding _binding;
  final DeviceStateSource _device;

  /// Butterscope runs on Android and iOS only; any other platform is
  /// written by its name.
  @override
  String get platform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      final other => other.name,
    };
  }

  @override
  String get buildMode {
    if (kReleaseMode) return 'release';
    if (kProfileMode) return 'profile';
    return 'debug';
  }

  @override
  bool get benchmarkLive {
    return _binding.framePolicy ==
        LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  }

  /// `disableAnimations` is Android's animation scale set to 0
  /// (`AccessibilityBridge.java`, Flutter 3.47.6). iOS's Reduce Motion does
  /// not set it, so that is read too (`docs/DESIGN.md` section 7.2).
  @override
  bool get animationsOff {
    return _binding.disableAnimations ||
        _binding.platformDispatcher.accessibilityFeatures.reduceMotion;
  }

  @override
  double get textScale => _binding.platformDispatcher.textScaleFactor;

  @override
  String get locale => _binding.platformDispatcher.locale.toLanguageTag();

  /// The binding's flag, not the platform's: `testWidgets` turns semantics
  /// on with a handle that sets only the binding's (`widget_tester.dart`
  /// and `semantics/binding.dart`, Flutter 3.47.6). The binding's also
  /// follows the platform's, so TalkBack and VoiceOver show here too.
  @override
  bool get semanticsOn => _binding.semanticsEnabled;

  @override
  ({String? version, String? engineRevision}) get flutter {
    return (
      version: FlutterVersion.version,
      engineRevision: FlutterVersion.engineRevision,
    );
  }

  @override
  Future<DeviceState?> readDevice() async {
    try {
      return await _device.read();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
