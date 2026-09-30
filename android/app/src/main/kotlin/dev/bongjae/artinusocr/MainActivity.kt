package dev.bongjae.artinusocr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger

class MainActivity : FlutterActivity() {
    private var nativeOcrHostApi: NativeOcrHostApi? = null
    private var appSettingsHostApi: AppSettingsHostApi? = null
    private val hostRegistration =
        HostRegistrationLifecycle<BinaryMessenger>(
            onRegister = ::registerHosts,
            onUnregister = ::unregisterHosts,
        )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nativeOcrHostApi = MlKitNativeOcrHostApi(applicationContext)
        appSettingsHostApi = AndroidAppSettingsHostApi(this)
        hostRegistration.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            hostRegistration.unregister()
        } finally {
            nativeOcrHostApi = null
            appSettingsHostApi = null
            super.cleanUpFlutterEngine(flutterEngine)
        }
    }

    private fun registerHosts(binaryMessenger: BinaryMessenger) {
        NativeOcrHostApi.setUp(binaryMessenger, checkNotNull(nativeOcrHostApi))
        try {
            AppSettingsHostApi.setUp(binaryMessenger, checkNotNull(appSettingsHostApi))
        } catch (exception: Exception) {
            NativeOcrHostApi.setUp(binaryMessenger, null)
            throw exception
        }
    }

    private fun unregisterHosts(binaryMessenger: BinaryMessenger) {
        try {
            NativeOcrHostApi.setUp(binaryMessenger, null)
        } finally {
            AppSettingsHostApi.setUp(binaryMessenger, null)
        }
    }
}
