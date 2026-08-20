package com.emfitsolutions.miarhpen

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Handles MiarhPen's own request to be exempted from Android's battery
/// optimization / background-process freezing (aggressive on OEM skins
/// like Honor's Magic OS) — done in-app via a system dialog, so the user
/// never has to go dig through Settings manually to keep the app
/// responsive. See lib/core/platform/battery_optimization_service.dart.
///
/// Extends FlutterFragmentActivity, not the plain FlutterActivity the
/// default template scaffolds — the local_auth plugin's biometric prompt
/// is built on AndroidX's BiometricPrompt, which requires a host that is
/// a FragmentActivity. Under plain FlutterActivity, every biometric
/// authentication attempt fails silently/throws, which is why "Use
/// biometric" appeared to do nothing.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.emfitsolutions.miarhpen/battery_optimization"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (isIgnoringBatteryOptimizations()) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}
