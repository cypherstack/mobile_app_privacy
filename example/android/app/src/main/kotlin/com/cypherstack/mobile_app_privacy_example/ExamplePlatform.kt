package com.cypherstack.mobile_app_privacy_example

import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Device information for the example widget, independent of the plugin API.
internal fun FlutterEngine.registerExamplePlatformChannel() {
    MethodChannel(dartExecutor.binaryMessenger, "mobile_app_privacy_example/platform")
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                else -> result.notImplemented()
            }
        }
}
