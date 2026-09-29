package com.example.altinus_ocr

import android.provider.Settings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidAppSettingsHostApiTest {
    @Test
    fun `launches application details for the current package`() {
        val launcher = RecordingSettingsLauncher()
        val api = AndroidAppSettingsHostApi("com.example.altinus", launcher)
        val replies = mutableListOf<Result<Boolean>>()

        api.open(replies::add)

        assertEquals(1, launcher.requests.size)
        assertEquals(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, launcher.requests.single().action)
        assertEquals("package:com.example.altinus", launcher.requests.single().uriString)
        assertEquals(true, replies.single().getOrThrow())
    }

    @Test
    fun `maps launch failure to one sanitized settings error`() {
        val launcher = RecordingSettingsLauncher(failure = IllegalStateException("activity detail"))
        val api = AndroidAppSettingsHostApi("com.example.altinus", launcher)
        val replies = mutableListOf<Result<Boolean>>()

        api.open(replies::add)

        assertEquals(1, launcher.requests.size)
        assertEquals(1, replies.size)
        val error = replies.single().exceptionOrNull()
        assertTrue(error is FlutterError)
        assertEquals("APP_SETTINGS_FAILED", (error as FlutterError).code)
    }

    @Test
    fun `contains callback exception without relaunching or replying again`() {
        val launcher = RecordingSettingsLauncher()
        val api = AndroidAppSettingsHostApi("com.example.altinus", launcher)
        var callbackCalls = 0

        api.open {
            callbackCalls += 1
            error("consumer callback failed")
        }

        assertEquals(1, launcher.requests.size)
        assertEquals(1, callbackCalls)
    }

    private class RecordingSettingsLauncher(
        private val failure: Exception? = null,
    ) : AppSettingsIntentLauncher {
        val requests = mutableListOf<AppSettingsIntentSpec>()

        override fun launch(spec: AppSettingsIntentSpec) {
            requests += spec
            failure?.let { throw it }
        }
    }
}
