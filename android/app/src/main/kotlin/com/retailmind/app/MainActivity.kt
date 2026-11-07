package com.retailmind.app

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CREATIVE_STUDIO_CHANNEL =
            "com.retailmind.app/creative_studio"
        private const val PAYMENT_ACCESS_CHANNEL =
            "com.retailmind.billing/accessibility"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PAYMENT_ACCESS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    try {
                        if (android.os.Build.VERSION.SDK_INT >=
                            android.os.Build.VERSION_CODES.M
                        ) {
                            val pm =
                                getSystemService(POWER_SERVICE) as PowerManager
                            result.success(
                                pm.isIgnoringBatteryOptimizations(packageName)
                            )
                        } else {
                            result.success(false)
                        }
                    } catch (error: Exception) {
                        result.error(
                            "BATTERY_STATUS_FAILED",
                            error.message,
                            null
                        )
                    }
                }
                "requestIgnoreBatteryOptimization" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(true)
                    } catch (error: Exception) {
                        // Some OEMs block the direct request intent; fall back
                        // to the battery-optimization settings list.
                        try {
                            startActivity(
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            )
                            result.success(true)
                        } catch (fallbackError: Exception) {
                            result.error(
                                "BATTERY_REQUEST_FAILED",
                                fallbackError.message,
                                null
                            )
                        }
                    }
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        )
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "BATTERY_SETTINGS_FAILED",
                            error.message,
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CREATIVE_STUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> {
                    try {
                        startActivity(
                            Intent(this, CreativeStudioActivity::class.java)
                        )
                        result.success(true)
                    } catch (error: Exception) {
                        result.error(
                            "CREATIVE_STUDIO_OPEN_FAILED",
                            error.message ?: "Could not open Creative Studio.",
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
