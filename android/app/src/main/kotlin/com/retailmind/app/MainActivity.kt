package com.retailmind.app

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CREATIVE_STUDIO_CHANNEL =
            "com.retailmind.app/creative_studio"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
