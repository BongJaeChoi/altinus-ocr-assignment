package com.example.altinus_ocr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class NativeOcrRunnerTest {
    @Test
    fun `maps missing path to one sanitized invalid path error`() {
        val runner =
            NativeOcrRunner(
                imageLoader = NativeOcrImageLoader<FakeImage> { throw InvalidImagePathException() },
                recognizerFactory = NativeOcrRecognizerFactory { FakeRecognizerSession() },
            )
        val replies = mutableListOf<Result<NativeOcrReply>>()

        runner.recognize("missing.jpg", replies::add)

        assertEquals(1, replies.size)
        assertFlutterError(replies.single(), "INVALID_IMAGE_PATH")
    }

    @Test
    fun `maps image loading failure to one sanitized input error`() {
        var factoryCalls = 0
        val runner =
            NativeOcrRunner(
                imageLoader = NativeOcrImageLoader<FakeImage> { error("corrupt /private/path") },
                recognizerFactory = NativeOcrRecognizerFactory {
                    factoryCalls += 1
                    FakeRecognizerSession()
                },
            )
        val replies = mutableListOf<Result<NativeOcrReply>>()

        runner.recognize("existing-but-corrupt.jpg", replies::add)

        assertEquals(0, factoryCalls)
        assertEquals(1, replies.size)
        assertFlutterError(replies.single(), "INPUT_IMAGE_FAILED")
    }

    @Test
    fun `maps synchronous recognizer creation failure to one sanitized OCR error`() {
        val runner =
            NativeOcrRunner(
                imageLoader = NativeOcrImageLoader { FakeImage },
                recognizerFactory = NativeOcrRecognizerFactory<FakeImage> {
                    error("engine creation leaked detail")
                },
            )
        val replies = mutableListOf<Result<NativeOcrReply>>()

        runner.recognize("capture.jpg", replies::add)

        assertEquals(1, replies.size)
        assertFlutterError(replies.single(), "OCR_FAILED")
    }

    @Test
    fun `closes and reports one sanitized error when process throws synchronously`() {
        val session = FakeRecognizerSession(processFailure = IllegalStateException("process detail"))
        val replies = mutableListOf<Result<NativeOcrReply>>()

        runnerWith(session).recognize("capture.jpg", replies::add)

        assertEquals(1, session.closeCalls)
        assertEquals(1, replies.size)
        assertFlutterError(replies.single(), "OCR_FAILED")
    }

    @Test
    fun `delivers asynchronous success unchanged and closes once`() {
        val session = FakeRecognizerSession()
        val replies = mutableListOf<Result<NativeOcrReply>>()
        runnerWith(session).recognize("capture.jpg", replies::add)

        assertTrue(replies.isEmpty())
        session.complete(Result.success("  안녕\nAltinus  "))

        assertEquals(1, session.closeCalls)
        assertEquals(1, replies.size)
        assertEquals("  안녕\nAltinus  ", replies.single().getOrThrow().text)
    }

    @Test
    fun `maps asynchronous blank text to no readable text`() {
        val session = FakeRecognizerSession()
        val replies = mutableListOf<Result<NativeOcrReply>>()
        runnerWith(session).recognize("capture.jpg", replies::add)

        session.complete(Result.success(" \n\t"))

        assertEquals(NativeOcrStatus.NO_READABLE_TEXT, replies.single().getOrThrow().status)
        assertEquals(null, replies.single().getOrThrow().text)
        assertEquals(1, session.closeCalls)
    }

    @Test
    fun `maps asynchronous engine failure to one sanitized OCR error`() {
        val session = FakeRecognizerSession()
        val replies = mutableListOf<Result<NativeOcrReply>>()
        runnerWith(session).recognize("capture.jpg", replies::add)

        session.complete(Result.failure(IllegalArgumentException("engine detail")))

        assertEquals(1, session.closeCalls)
        assertEquals(1, replies.size)
        assertFlutterError(replies.single(), "OCR_FAILED")
    }

    @Test
    fun `ignores duplicate terminal completion and closes once`() {
        val session = FakeRecognizerSession()
        val replies = mutableListOf<Result<NativeOcrReply>>()
        runnerWith(session).recognize("capture.jpg", replies::add)

        session.complete(Result.success("first"))
        session.complete(Result.failure(IllegalStateException("late")))

        assertEquals(1, session.closeCalls)
        assertEquals(1, replies.size)
        assertEquals("first", replies.single().getOrThrow().text)
    }

    @Test
    fun `maps close failure to OCR error without a second callback`() {
        val session = FakeRecognizerSession(closeFailure = IllegalStateException("close detail"))
        val replies = mutableListOf<Result<NativeOcrReply>>()
        runnerWith(session).recognize("capture.jpg", replies::add)

        session.complete(Result.success("text"))

        assertEquals(1, session.closeCalls)
        assertEquals(1, replies.size)
        assertFlutterError(replies.single(), "OCR_FAILED")
    }

    @Test
    fun `contains callback exception without closing or replying again`() {
        val session = FakeRecognizerSession(completeSynchronouslyWith = Result.success("text"))
        var callbackCalls = 0

        runnerWith(session).recognize("capture.jpg") {
            callbackCalls += 1
            error("consumer callback failed")
        }

        assertEquals(1, callbackCalls)
        assertEquals(1, session.closeCalls)
    }

    @Test
    fun `synchronous completion wins when process throws afterward`() {
        val session =
            FakeRecognizerSession(
                completeSynchronouslyWith = Result.success("first"),
                processFailureAfterSynchronousCompletion =
                    IllegalStateException("late process failure"),
            )
        val replies = mutableListOf<Result<NativeOcrReply>>()

        runnerWith(session).recognize("capture.jpg", replies::add)

        assertEquals(1, session.closeCalls)
        assertEquals(1, replies.size)
        assertEquals("first", replies.single().getOrThrow().text)
    }

    @Test
    fun `task result access exception becomes a failure`() {
        val result =
            completedTextResult(
                object : CompletedTextTask {
                    override val isSuccessful = true

                    override fun text(): String = error("task result unavailable")
                },
            )

        assertTrue(result.isFailure)
    }

    private fun runnerWith(session: FakeRecognizerSession) =
        NativeOcrRunner(
            imageLoader = NativeOcrImageLoader { FakeImage },
            recognizerFactory = NativeOcrRecognizerFactory { session },
        )

    private fun assertFlutterError(result: Result<NativeOcrReply>, expectedCode: String) {
        val error = result.exceptionOrNull()
        assertTrue(error is FlutterError)
        assertEquals(expectedCode, (error as FlutterError).code)
        assertFalse(error.message.orEmpty().contains("detail"))
        assertFalse(error.message.orEmpty().contains("path"))
    }

    private data object FakeImage

    private class FakeRecognizerSession(
        private val processFailure: Exception? = null,
        private val closeFailure: Exception? = null,
        private val completeSynchronouslyWith: Result<String>? = null,
        private val processFailureAfterSynchronousCompletion: Exception? = null,
    ) : NativeOcrRecognizerSession<FakeImage> {
        private var completion: ((Result<String>) -> Unit)? = null
        var closeCalls = 0
            private set

        override fun process(image: FakeImage, callback: (Result<String>) -> Unit) {
            processFailure?.let { throw it }
            completion = callback
            completeSynchronouslyWith?.let(callback)
            processFailureAfterSynchronousCompletion?.let { throw it }
        }

        override fun close() {
            closeCalls += 1
            closeFailure?.let { throw it }
        }

        fun complete(result: Result<String>) {
            val callback = completion
            if (callback == null) {
                fail("process callback was not registered")
                return
            }
            callback(result)
        }
    }
}
