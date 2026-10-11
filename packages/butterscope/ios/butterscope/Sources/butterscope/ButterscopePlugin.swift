import Flutter
import UIKit

/// Reads the phone's state for Butterscope's guards and run identity.
///
/// One method, `read`, on the `butterscope/device` channel. It does nothing
/// until a run calls it, so an app can ship it.
public class ButterscopePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "butterscope/device", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ButterscopePlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "read" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let info = ProcessInfo.processInfo
    result([
      "model": hardwareIdentifier(),
      "osVersion": "iOS \(UIDevice.current.systemVersion)",
      "thermal": thermalName(info.thermalState),
      "thermalNominal": info.thermalState == .nominal,
      "lowPower": info.isLowPowerModeEnabled,
    ])
  }

  /// The model's hardware identifier, such as `iPhone18,1`.
  /// `UIDevice.model` only says "iPhone".
  private func hardwareIdentifier() -> String {
    var system = utsname()
    uname(&system)
    return withUnsafeBytes(of: &system.machine) { bytes in
      String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
  }

  private func thermalName(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal: return "nominal"
    case .fair: return "fair"
    case .serious: return "serious"
    case .critical: return "critical"
    @unknown default: return "unknown"
    }
  }
}
