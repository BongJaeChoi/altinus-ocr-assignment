import '../../../src/generated/platform_apis.g.dart';
import '../domain/ocr_failure.dart';
import '../domain/ocr_ports.dart';
import '../domain/ocr_result.dart';

abstract interface class NativeOcrGateway {
  Future<NativeOcrReply> recognizeKorean(String imagePath);
}

final class PigeonNativeOcrGateway implements NativeOcrGateway {
  PigeonNativeOcrGateway({NativeOcrHostApi? api})
    : _api = api ?? NativeOcrHostApi();

  final NativeOcrHostApi _api;

  @override
  Future<NativeOcrReply> recognizeKorean(String imagePath) =>
      _api.recognizeKorean(imagePath);
}

final class PigeonLocalOcrService implements LocalOcrService {
  PigeonLocalOcrService({NativeOcrGateway? gateway})
    : _gateway = gateway ?? PigeonNativeOcrGateway();

  final NativeOcrGateway _gateway;

  @override
  Future<OcrResult> recognize(String imagePath) async {
    final NativeOcrReply reply;
    try {
      reply = await _gateway.recognizeKorean(imagePath);
    } on Object {
      throw OcrFailure.of(OcrFailureKind.bridge);
    }

    return switch (reply.status) {
      NativeOcrStatus.textDetected => _detectedText(reply.text),
      NativeOcrStatus.noReadableText => const OcrResult.noReadableText(),
    };
  }

  OcrResult _detectedText(String? text) {
    if (text == null || text.trim().isEmpty) {
      throw OcrFailure.invalidResponse();
    }
    return OcrResult.textDetected(text);
  }
}
