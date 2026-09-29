package dev.bongjae.artinusocr

import android.content.Context
import android.net.Uri
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

internal object NativeOcrPolicy {
    fun isExistingRegularFilePath(imagePath: String): Boolean =
        imagePath.isNotBlank() && File(imagePath).isFile

    fun replyFor(recognizedText: String): NativeOcrReply =
        if (recognizedText.isBlank()) {
            NativeOcrReply(status = NativeOcrStatus.NO_READABLE_TEXT)
        } else {
            NativeOcrReply(
                status = NativeOcrStatus.TEXT_DETECTED,
                text = recognizedText,
            )
        }
}

internal fun interface NativeOcrImageLoader<Image> {
    fun load(imagePath: String): Image
}

internal fun interface NativeOcrRecognizerFactory<Image> {
    fun create(): NativeOcrRecognizerSession<Image>
}

internal interface NativeOcrRecognizerSession<Image> {
    fun process(image: Image, callback: (Result<String>) -> Unit)

    fun close()
}

internal interface CompletedTextTask {
    val isSuccessful: Boolean

    fun text(): String
}

internal fun completedTextResult(task: CompletedTextTask): Result<String> =
    try {
        if (task.isSuccessful) {
            Result.success(task.text())
        } else {
            Result.failure(NativeOcrEngineException())
        }
    } catch (_: Exception) {
        Result.failure(NativeOcrEngineException())
    }

internal class NativeOcrRunner<Image>(
    private val imageLoader: NativeOcrImageLoader<Image>,
    private val recognizerFactory: NativeOcrRecognizerFactory<Image>,
) {
    fun recognize(
        imagePath: String,
        callback: (Result<NativeOcrReply>) -> Unit,
    ) {
        val terminal = AtomicBoolean(false)
        val image =
            try {
                imageLoader.load(imagePath)
            } catch (_: InvalidImagePathException) {
                deliverOnce(terminal, null, callback, Result.failure(invalidImagePathError()))
                return
            } catch (_: Exception) {
                deliverOnce(terminal, null, callback, Result.failure(inputImageError()))
                return
            }

        val recognizer =
            try {
                recognizerFactory.create()
            } catch (_: Exception) {
                deliverOnce(terminal, null, callback, Result.failure(ocrError()))
                return
            }

        try {
            recognizer.process(image) { result ->
                val reply =
                    result.fold(
                        onSuccess = { Result.success(NativeOcrPolicy.replyFor(it)) },
                        onFailure = { Result.failure(ocrError()) },
                    )
                deliverOnce(terminal, recognizer, callback, reply)
            }
        } catch (_: Exception) {
            deliverOnce(terminal, recognizer, callback, Result.failure(ocrError()))
        }
    }

    private fun deliverOnce(
        terminal: AtomicBoolean,
        recognizer: NativeOcrRecognizerSession<Image>?,
        callback: (Result<NativeOcrReply>) -> Unit,
        result: Result<NativeOcrReply>,
    ) {
        if (!terminal.compareAndSet(false, true)) {
            return
        }

        val resultAfterClose =
            if (recognizer == null) {
                result
            } else {
                try {
                    recognizer.close()
                    result
                } catch (_: Exception) {
                    Result.failure(ocrError())
                }
            }

        try {
            callback(resultAfterClose)
        } catch (_: Exception) {
            // The Pigeon reply callback is external to this host. It must not re-enter completion.
        }
    }
}

class MlKitNativeOcrHostApi private constructor(
    private val runner: NativeOcrRunner<InputImage>,
) : NativeOcrHostApi {
    constructor(context: Context) : this(
        NativeOcrRunner(
            imageLoader = MlKitInputImageLoader(context.applicationContext),
            recognizerFactory =
                NativeOcrRecognizerFactory {
                    MlKitRecognizerSession(
                        TextRecognition.getClient(
                            KoreanTextRecognizerOptions.Builder().build(),
                        ),
                    )
                },
        ),
    )

    override fun recognizeKorean(
        imagePath: String,
        callback: (Result<NativeOcrReply>) -> Unit,
    ) {
        runner.recognize(imagePath, callback)
    }
}

private class MlKitInputImageLoader(
    private val context: Context,
) : NativeOcrImageLoader<InputImage> {
    override fun load(imagePath: String): InputImage {
        if (!NativeOcrPolicy.isExistingRegularFilePath(imagePath)) {
            throw InvalidImagePathException()
        }
        return InputImage.fromFilePath(context, Uri.fromFile(File(imagePath)))
    }
}

private class MlKitRecognizerSession(
    private val recognizer: TextRecognizer,
) : NativeOcrRecognizerSession<InputImage> {
    override fun process(image: InputImage, callback: (Result<String>) -> Unit) {
        recognizer.process(image).addOnCompleteListener { task ->
            callback(completedTextResult(GoogleCompletedTextTask(task)))
        }
    }

    override fun close() {
        recognizer.close()
    }
}

private class GoogleCompletedTextTask(
    private val task: Task<Text>,
) : CompletedTextTask {
    override val isSuccessful: Boolean
        get() = task.isSuccessful

    override fun text(): String = task.result.text
}

internal class InvalidImagePathException : Exception()

private class NativeOcrEngineException : Exception()

private fun invalidImagePathError() =
    FlutterError(
        code = "INVALID_IMAGE_PATH",
        message = "The captured image file is unavailable.",
    )

private fun inputImageError() =
    FlutterError(
        code = "INPUT_IMAGE_FAILED",
        message = "The captured image could not be opened.",
    )

private fun ocrError() =
    FlutterError(
        code = "OCR_FAILED",
        message = "Korean text recognition failed.",
    )
