package dev.butterscope.butterscope

import android.content.Context
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the phone's state for Butterscope's guards and run identity.
 *
 * One method, `read`, on the `butterscope/device` channel. It does nothing
 * until a run calls it, so an app can ship it.
 */
class ButterscopePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "butterscope/device")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "read") {
            result.notImplemented()
            return
        }
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        // The thermal status needs Android 10 (API 29). Before it, the state
        // is unknown, which the guards treat as unreadable.
        val thermal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            power.currentThermalStatus
        } else {
            null
        }
        result.success(
            mapOf(
                "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                "osVersion" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
                "thermal" to thermal?.let { thermalName(it) },
                "thermalNominal" to thermal?.let { it == PowerManager.THERMAL_STATUS_NONE },
                "lowPower" to power.isPowerSaveMode,
            ),
        )
    }

    private fun thermalName(status: Int): String = when (status) {
        PowerManager.THERMAL_STATUS_NONE -> "none"
        PowerManager.THERMAL_STATUS_LIGHT -> "light"
        PowerManager.THERMAL_STATUS_MODERATE -> "moderate"
        PowerManager.THERMAL_STATUS_SEVERE -> "severe"
        PowerManager.THERMAL_STATUS_CRITICAL -> "critical"
        PowerManager.THERMAL_STATUS_EMERGENCY -> "emergency"
        PowerManager.THERMAL_STATUS_SHUTDOWN -> "shutdown"
        else -> "status $status"
    }
}
