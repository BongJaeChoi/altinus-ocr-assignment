package com.example.altinus_ocr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger
        NativeOcrHostApi.setUp(binaryMessenger, MlKitNativeOcrHostApi(this))
        AppSettingsHostApi.setUp(binaryMessenger, AndroidAppSettingsHostApi(this))
    }
}
