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
    fun `accepts an existing regular path without claiming image validity`() {
        val directory = Files.createTempDirectory("native-ocr-policy").toFile()
        val arbitraryFile = File(directory, "not-an-image.txt").apply { writeText("text") }

        try {
            assertTrue(NativeOcrPolicy.isExistingRegularFilePath(arbitraryFile.path))
            assertFalse(
                NativeOcrPolicy.isExistingRegularFilePath(File(directory, "missing.jpg").path),
            )
            assertFalse(NativeOcrPolicy.isExistingRegularFilePath(directory.path))
            assertFalse(NativeOcrPolicy.isExistingRegularFilePath(""))
        } finally {
            arbitraryFile.delete()
            directory.delete()
        }
    }

    @Test
    fun `accepts a symbolic link to an existing regular file`() {
        val directory = Files.createTempDirectory("native-ocr-symlink")
        val target = Files.write(directory.resolve("capture.jpg"), byteArrayOf(1))
        val link = Files.createSymbolicLink(directory.resolve("capture-link.jpg"), target)

        try {
            assertTrue(NativeOcrPolicy.isExistingRegularFilePath(link.toString()))
        } finally {
            Files.deleteIfExists(link)
            Files.deleteIfExists(target)
            Files.deleteIfExists(directory)
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
