import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {
  private enum TestFailure: Error {
    case expected
  }

  func testNativeOcrPreservesOriginalNonblankText() {
    let expected = "  \u{C548}\u{B155}\u{D558}\u{C138}\u{C694}\nALTINUS 123  "
    let runner = NativeOcrRunner<Int>(
      imageLoader: { _ in 7 },
      recognizer: { image, completion in
        XCTAssertEqual(image, 7)
        completion(.success(expected))
      }
    )

    let result = captureOcrResult(from: runner, imagePath: "/tmp/capture.jpg")

    guard case .success(let reply) = result else {
      return XCTFail("Expected OCR success")
    }
    XCTAssertEqual(reply.status, .textDetected)
    XCTAssertEqual(reply.text, expected)
  }

  func testNativeOcrUsesTrimmedTextOnlyToDecideEmpty() {
    let runner = NativeOcrRunner<Int>(
      imageLoader: { _ in 1 },
      recognizer: { _, completion in completion(.success(" \n\t ")) }
    )

    let result = captureOcrResult(from: runner, imagePath: "/tmp/blank.jpg")

    guard case .success(let reply) = result else {
      return XCTFail("Expected typed empty OCR success")
    }
    XCTAssertEqual(reply.status, .noReadableText)
    XCTAssertNil(reply.text)
  }

  func testNativeOcrMapsImageLoadFailureWithoutLeakingUnderlyingDetails() {
    let runner = NativeOcrRunner<Int>(
      imageLoader: { _ in throw TestFailure.expected },
      recognizer: { _, _ in XCTFail("Recognizer must not run") }
    )

    let result = captureOcrResult(from: runner, imagePath: "/private/secret.jpg")

    assertSanitizedFailure(result, code: "INPUT_IMAGE_FAILED")
  }

  func testNativeOcrMapsRecognitionFailureWithoutLeakingUnderlyingDetails() {
    let runner = NativeOcrRunner<Int>(
      imageLoader: { _ in 1 },
      recognizer: { _, completion in completion(.failure(TestFailure.expected)) }
    )

    let result = captureOcrResult(from: runner, imagePath: "/private/secret.jpg")

    assertSanitizedFailure(result, code: "OCR_FAILED")
  }

  func testNativeOcrDeliversOnlyFirstCompletionWhenRecognizerCompletesTwice() {
    var callbackCount = 0
    let runner = NativeOcrRunner<Int>(
      imageLoader: { _ in 1 },
      recognizer: { _, completion in
        completion(.success("first"))
        completion(.success("second"))
      }
    )

    runner.recognize(imagePath: "/tmp/capture.jpg") { result in
      callbackCount += 1
      guard case .success(let reply) = result else {
        return XCTFail("Expected first result to win")
      }
      XCTAssertEqual(reply.text, "first")
    }

    XCTAssertEqual(callbackCount, 1)
  }

  func testNativeOcrKeepsSynchronousCompletionWhenRecognizerThenThrows() {
    var callbackCount = 0
    let runner = NativeOcrRunner<Int>(
      imageLoader: { _ in 1 },
      recognizer: { _, completion in
        completion(.success("first"))
        throw TestFailure.expected
      }
    )

    runner.recognize(imagePath: "/tmp/capture.jpg") { result in
      callbackCount += 1
      guard case .success(let reply) = result else {
        return XCTFail("Expected synchronous completion to win")
      }
      XCTAssertEqual(reply.text, "first")
    }

    XCTAssertEqual(callbackCount, 1)
  }

  func testSettingsDoesNotOpenWhenURLCannotBeOpened() {
    var openCount = 0
    let host = IosAppSettingsHostApi(
      settingsURL: URL(string: "app-settings:")!,
      canOpen: { _ in false },
      opener: { _, _ in openCount += 1 }
    )

    let result = captureSettingsResult(from: host)

    XCTAssertEqual(try? result.get(), false)
    XCTAssertEqual(openCount, 0)
  }

  func testSettingsMapsSystemOpenResultWithoutExposingPlatformErrors() {
    for expected in [true, false] {
      let host = IosAppSettingsHostApi(
        settingsURL: URL(string: "app-settings:")!,
        canOpen: { _ in true },
        opener: { _, completion in completion(expected) }
      )

      XCTAssertEqual(try? captureSettingsResult(from: host).get(), expected)
    }
  }

  func testSettingsDeliversOnlyFirstSystemCompletion() {
    var callbackCount = 0
    let host = IosAppSettingsHostApi(
      settingsURL: URL(string: "app-settings:")!,
      canOpen: { _ in true },
      opener: { _, completion in
        completion(true)
        completion(false)
      }
    )

    host.open { result in
      callbackCount += 1
      XCTAssertEqual(try? result.get(), true)
    }

    XCTAssertEqual(callbackCount, 1)
  }

  private func captureOcrResult<Image>(
    from runner: NativeOcrRunner<Image>,
    imagePath: String
  ) -> Result<NativeOcrReply, Error> {
    var captured: Result<NativeOcrReply, Error>?
    runner.recognize(imagePath: imagePath) { captured = $0 }
    return try! XCTUnwrap(captured)
  }

  private func assertSanitizedFailure(
    _ result: Result<NativeOcrReply, Error>,
    code: String
  ) {
    guard case .failure(let error as PigeonError) = result else {
      return XCTFail("Expected a PigeonError")
    }
    XCTAssertEqual(error.code, code)
    XCTAssertNil(error.details)
    XCTAssertFalse(error.message?.contains("secret") ?? false)
    XCTAssertFalse(error.message?.contains("expected") ?? false)
  }

  private func captureSettingsResult(
    from host: IosAppSettingsHostApi
  ) -> Result<Bool, Error> {
    var captured: Result<Bool, Error>?
    host.open { captured = $0 }
    return try! XCTUnwrap(captured)
  }
}
