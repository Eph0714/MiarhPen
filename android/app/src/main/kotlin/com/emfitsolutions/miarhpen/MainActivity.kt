package com.emfitsolutions.miarhpen

import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
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
    private val ringtoneChannelName = "com.emfitsolutions.miarhpen/ringtone_picker"
    private val ringtonePickerRequestCode = 4271

    /// The Flutter-side `pickAlarmSound` call stays pending until
    /// [onActivityResult] fires with the user's choice — Android's
    /// ACTION_RINGTONE_PICKER is a fire-and-forget startActivityForResult,
    /// not a synchronous API, so the MethodChannel result has to be
    /// stashed here rather than returned inline.
    private var pendingRingtoneResult: MethodChannel.Result? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ringtoneChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAlarmSound" -> {
                    val existingUri = call.argument<String>("existingUri")
                    pickAlarmSound(existingUri, result)
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

    /// Opens the system's own "Alarm sound" picker (the same dialog used
    /// by the built-in Clock app), scoped to TYPE_ALARM so the list shown
    /// is every alarm sound already on the device — nothing bundled or
    /// hardcoded by MiarhPen itself.
    private fun pickAlarmSound(existingUri: String?, result: MethodChannel.Result) {
        if (pendingRingtoneResult != null) {
            // A picker is already open — refuse the second call rather than
            // silently dropping the first caller's result.
            result.error("ALREADY_PICKING", "A ringtone picker is already open", null)
            return
        }
        pendingRingtoneResult = result
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Choose Alarm Sound")
            if (existingUri != null) {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(existingUri))
            }
        }
        startActivityForResult(intent, ringtonePickerRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == ringtonePickerRequestCode) {
            val pending = pendingRingtoneResult
            pendingRingtoneResult = null
            val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            if (uri == null) {
                pending?.success(null)
            } else {
                val ringtone = RingtoneManager.getRingtone(this, uri)
                val name = ringtone?.getTitle(this) ?: "Selected sound"
                pending?.success(mapOf("uri" to uri.toString(), "name" to name))
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
