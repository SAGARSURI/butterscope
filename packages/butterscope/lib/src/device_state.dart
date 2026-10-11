import 'package:flutter/services.dart' show MethodChannel;

/// The phone's state at one moment, as the guards and the run identity
/// read it: model, OS version, thermal state and power saving.
///
/// Dart cannot read these, so a small native plugin in this package does:
/// Kotlin on Android, Swift on iOS (`docs/DESIGN.md` section 7.2).
final class DeviceState {
  /// Creates a state, for example in a test.
  const new({
    required this.model,
    required this.osVersion,
    required this.thermal,
    required this.thermalNominal,
    required this.lowPower,
  });

  /// Reads the map the plugin sends. Throws a [FormatException] when a
  /// field is missing or of the wrong type.
  factory fromMap(Map<Object?, Object?> map) {
    T field<T>(String key) {
      final value = map[key];
      if (value is T) return value;
      throw FormatException('Device state field "$key" is $value.');
    }

    return DeviceState(
      model: field<String>('model'),
      osVersion: field<String>('osVersion'),
      thermal: field<String?>('thermal'),
      thermalNominal: field<bool?>('thermalNominal'),
      lowPower: field<bool>('lowPower'),
    );
  }

  /// The phone's maker and model on Android, such as `samsung SM-S921B`;
  /// its hardware identifier on iOS, such as `iPhone18,1`.
  final String model;

  /// The OS and its version, such as `Android 16 (API 36)` or `iOS 26.1`.
  final String osVersion;

  /// The thermal state as the OS names it: Android's thermal status (`none`
  /// to `shutdown`) or iOS's thermal state (`nominal` to `critical`).
  /// `null` where the OS cannot report it: Android before 10 (API 29).
  final String? thermal;

  /// Whether the phone is not thermally limited: Android's status is
  /// `none`, or iOS's state is `nominal`. `null` when [thermal] is.
  final bool? thermalNominal;

  /// Whether power saving (Android) or Low Power Mode (iOS) is on.
  final bool lowPower;

  /// The state as a JSON-ready map, in the plugin's own field names.
  Map<String, Object?> toJson() {
    return {
      'model': model,
      'osVersion': osVersion,
      'thermal': thermal,
      'thermalNominal': thermalNominal,
      'lowPower': lowPower,
    };
  }
}

/// Where a run reads the phone's state from.
///
/// A host test passes a fake; on a phone it is [ChannelDeviceStateSource].
abstract interface class DeviceStateSource {
  /// Reads the state now.
  Future<DeviceState> read();
}

/// Reads the phone's state from this package's native plugin.
final class ChannelDeviceStateSource implements DeviceStateSource {
  /// Creates the source. It reads nothing until [read].
  const new();

  static const MethodChannel _channel = MethodChannel('butterscope/device');

  /// Reads the state through the `butterscope/device` channel.
  ///
  /// Fails with a `MissingPluginException` when the app was built without
  /// the plugin. Flutter 3.47.6 leaves plugins reached only through dev
  /// dependencies out of Android release builds
  /// (`packages/flutter_tools/lib/src/flutter_plugins.dart`, line 1408), so
  /// an app that runs release builds lists `butterscope` under its own
  /// dependencies.
  @override
  Future<DeviceState> read() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('read');
    if (map == null) {
      throw const FormatException('The device state read returned nothing.');
    }
    return DeviceState.fromMap(map);
  }
}
