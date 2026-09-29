package com.example.altinus_ocr

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings

class AndroidAppSettingsHostApi(
    private val activity: Activity,
) : AppSettingsHostApi {
    override fun open(callback: (Result<Boolean>) -> Unit) {
        try {
            val intent =
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${activity.packageName}"),
                )
            activity.startActivity(intent)
            callback(Result.success(true))
        } catch (_: Exception) {
            callback(
                Result.failure(
                    FlutterError(
                        code = "APP_SETTINGS_FAILED",
                        message = "App settings could not be opened.",
                    ),
                ),
            )
        }
    }
}
