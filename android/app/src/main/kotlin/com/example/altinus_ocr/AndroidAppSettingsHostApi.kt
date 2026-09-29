package com.example.altinus_ocr

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings

internal data class AppSettingsIntentSpec(
    val action: String,
    val packageName: String,
) {
    val uriString: String
        get() = "package:$packageName"
}

internal fun interface AppSettingsIntentLauncher {
    fun launch(spec: AppSettingsIntentSpec)
}

class AndroidAppSettingsHostApi internal constructor(
    private val packageName: String,
    private val launcher: AppSettingsIntentLauncher,
) : AppSettingsHostApi {
    constructor(activity: Activity) : this(
        activity.packageName,
        AppSettingsIntentLauncher { spec ->
            val uri = Uri.fromParts("package", spec.packageName, null)
            activity.startActivity(Intent(spec.action, uri))
        },
    )

    override fun open(callback: (Result<Boolean>) -> Unit) {
        val result =
            try {
                launcher.launch(
                    AppSettingsIntentSpec(
                        action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        packageName = packageName,
                    ),
                )
                Result.success(true)
            } catch (_: Exception) {
                Result.failure(appSettingsError())
            }

        try {
            callback(result)
        } catch (_: Exception) {
            // A failed Pigeon reply must not relaunch settings or trigger a second reply.
        }
    }

    private fun appSettingsError() =
        FlutterError(
            code = "APP_SETTINGS_FAILED",
            message = "App settings could not be opened.",
        )
}
