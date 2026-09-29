package com.example.altinus_ocr

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeOcrPolicyTest {
    @Test
    fun `accepts only an existing regular file`() {
        val directory = Files.createTempDirectory("native-ocr-policy").toFile()
        val image = File(directory, "capture.jpg").apply { writeBytes(byteArrayOf(1)) }

        try {
            assertTrue(NativeOcrPolicy.isReadableImagePath(image.path))
            assertFalse(
                NativeOcrPolicy.isReadableImagePath(File(directory, "missing.jpg").path),
            )
            assertFalse(NativeOcrPolicy.isReadableImagePath(directory.path))
            assertFalse(NativeOcrPolicy.isReadableImagePath(""))
        } finally {
            image.delete()
            directory.delete()
        }
    }

    @Test
    fun `maps blank recognition to no readable text`() {
        val reply = NativeOcrPolicy.replyFor(" \n\t")

        assertEquals(NativeOcrStatus.NO_READABLE_TEXT, reply.status)
        assertNull(reply.text)
    }

    @Test
    fun `preserves nonblank recognition exactly`() {
        val recognizedText = "  안녕하세요\nAltinus  "

        val reply = NativeOcrPolicy.replyFor(recognizedText)

        assertEquals(NativeOcrStatus.TEXT_DETECTED, reply.status)
        assertEquals(recognizedText, reply.text)
    }
}
