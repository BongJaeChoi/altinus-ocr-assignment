package com.example.altinus_ocr

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
import java.io.File

internal object NativeOcrPolicy {
    fun isReadableImagePath(imagePath: String): Boolean =
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

class MlKitNativeOcrHostApi(
    private val context: Context,
) : NativeOcrHostApi {
    override fun recognizeKorean(
        imagePath: String,
        callback: (Result<NativeOcrReply>) -> Unit,
    ) {
        if (!NativeOcrPolicy.isReadableImagePath(imagePath)) {
            callback(Result.failure(invalidImagePathError()))
            return
        }

        val inputImage =
            try {
                InputImage.fromFilePath(context, Uri.fromFile(File(imagePath)))
            } catch (_: Exception) {
                callback(Result.failure(inputImageError()))
                return
            }

        val recognizer =
            try {
                TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
            } catch (_: Exception) {
                callback(Result.failure(ocrError()))
                return
            }

        try {
            recognizer.process(inputImage).addOnCompleteListener { task ->
                val result =
                    try {
                        if (task.isSuccessful) {
                            Result.success(NativeOcrPolicy.replyFor(task.result.text))
                        } else {
                            Result.failure(ocrError())
                        }
                    } catch (_: Exception) {
                        Result.failure(ocrError())
                    }
                closeThenReply(recognizer, callback, result)
            }
        } catch (_: Exception) {
            closeThenReply(recognizer, callback, Result.failure(ocrError()))
        }
    }

    private fun closeThenReply(
        recognizer: TextRecognizer,
        callback: (Result<NativeOcrReply>) -> Unit,
        result: Result<NativeOcrReply>,
    ) {
        val resultAfterClose =
            try {
                recognizer.close()
                result
            } catch (_: Exception) {
                Result.failure(ocrError())
            }
        callback(resultAfterClose)
    }

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
}
