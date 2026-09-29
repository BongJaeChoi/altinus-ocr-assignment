import Foundation
import MLKitTextRecognitionCommon
import MLKitTextRecognitionKorean
import MLKitVision
import UIKit

private enum NativeOcrBridgeFailure: Error {
  case recognitionFailed
}

internal final class OneShotResult<Value> {
  private let lock = NSLock()
  private var isDelivered = false

  func deliver(
    _ result: Result<Value, Error>,
    to completion: (Result<Value, Error>) -> Void
  ) {
    lock.lock()
    guard !isDelivered else {
      lock.unlock()
      return
    }
    isDelivered = true
    lock.unlock()

    completion(result)
  }
}

internal final class NativeOcrRunner<Image> {
  typealias ImageLoader = (String) throws -> Image
  typealias Recognizer = (
    Image,
    @escaping (Result<String, Error>) -> Void
  ) throws -> Void

  private let imageLoader: ImageLoader
  private let recognizer: Recognizer

  init(
    imageLoader: @escaping ImageLoader,
    recognizer: @escaping Recognizer
  ) {
    self.imageLoader = imageLoader
    self.recognizer = recognizer
  }

  func recognize(
    imagePath: String,
    completion: @escaping (Result<NativeOcrReply, Error>) -> Void
  ) {
    let terminal = OneShotResult<NativeOcrReply>()

    let image: Image
    do {
      image = try imageLoader(imagePath)
    } catch {
      terminal.deliver(.failure(inputImageError()), to: completion)
      return
    }

    do {
      try recognizer(image) { result in
        let mapped =
          result
          .map(NativeOcrPolicy.reply)
          .mapError { _ in ocrError() as Error }
        terminal.deliver(mapped, to: completion)
      }
    } catch {
      terminal.deliver(.failure(ocrError()), to: completion)
    }
  }
}

internal enum NativeOcrPolicy {
  static func reply(for recognizedText: String) -> NativeOcrReply {
    if recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return NativeOcrReply(status: .noReadableText)
    }
    return NativeOcrReply(status: .textDetected, text: recognizedText)
  }
}

final class MlKitNativeOcrHostApi: NativeOcrHostApi {
  private let runner: NativeOcrRunner<UIImage>

  init() {
    runner = NativeOcrRunner(
      imageLoader: { imagePath in
        guard
          let image = UIImage(contentsOfFile: imagePath),
          image.cgImage != nil
        else {
          throw NativeOcrBridgeFailure.recognitionFailed
        }
        return image
      },
      recognizer: { image, completion in
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        let recognizer = TextRecognizer.textRecognizer(
          options: KoreanTextRecognizerOptions()
        )
        recognizer.process(visionImage) { text, error in
          defer { withExtendedLifetime(recognizer) {} }
          guard error == nil, let text else {
            completion(.failure(NativeOcrBridgeFailure.recognitionFailed))
            return
          }
          completion(.success(text.text))
        }
      }
    )
  }

  func recognizeKorean(
    imagePath: String,
    completion: @escaping (Result<NativeOcrReply, Error>) -> Void
  ) {
    runner.recognize(imagePath: imagePath, completion: completion)
  }
}

private func inputImageError() -> PigeonError {
  PigeonError(
    code: "INPUT_IMAGE_FAILED",
    message: "The captured image could not be opened.",
    details: nil
  )
}

private func ocrError() -> PigeonError {
  PigeonError(
    code: "OCR_FAILED",
    message: "Korean text recognition failed.",
    details: nil
  )
}
