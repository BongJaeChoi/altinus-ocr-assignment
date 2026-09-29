import 'package:altinus_ocr/features/ocr/data/pigeon_app_settings_launcher.dart';
import 'package:altinus_ocr/features/ocr/data/pigeon_local_ocr_service.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:altinus_ocr/src/generated/platform_apis.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PigeonLocalOcrService', () {
    test('maps detected text and forwards the image path unchanged', () async {
      final gateway = _FakeNativeOcrGateway(
        reply: NativeOcrReply(
          status: NativeOcrStatus.textDetected,
          text: '안녕하세요\nALTINUS 123',
        ),
      );
      final service = PigeonLocalOcrService(gateway: gateway);

      final result = await service.recognize('/tmp/capture.jpg');

      expect(gateway.imagePaths, ['/tmp/capture.jpg']);
      expect(result, isA<TextDetected>());
      expect((result as TextDetected).text, '안녕하세요\nALTINUS 123');
    });

    test(
      'maps the native no-readable-text status to an empty result',
      () async {
        final service = PigeonLocalOcrService(
          gateway: _FakeNativeOcrGateway(
            reply: NativeOcrReply(status: NativeOcrStatus.noReadableText),
          ),
        );

        final result = await service.recognize('/tmp/empty.jpg');

        expect(result, isA<NoReadableText>());
      },
    );

    test('maps blank detected text to an invalid response failure', () async {
      final service = PigeonLocalOcrService(
        gateway: _FakeNativeOcrGateway(
          reply: NativeOcrReply(
            status: NativeOcrStatus.textDetected,
            text: '  \n',
          ),
        ),
      );

      await expectLater(
        service.recognize('/tmp/blank.jpg'),
        throwsA(
          isA<OcrFailure>().having(
            (failure) => failure.kind,
            'kind',
            OcrFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('maps null detected text to an invalid response failure', () async {
      final service = PigeonLocalOcrService(
        gateway: _FakeNativeOcrGateway(
          reply: NativeOcrReply(status: NativeOcrStatus.textDetected),
        ),
      );

      await expectLater(
        service.recognize('/tmp/null.jpg'),
        throwsA(
          isA<OcrFailure>().having(
            (failure) => failure.kind,
            'kind',
            OcrFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('maps a gateway exception to a bridge failure', () async {
      final service = PigeonLocalOcrService(
        gateway: _FakeNativeOcrGateway(error: StateError('bridge unavailable')),
      );

      await expectLater(
        service.recognize('/tmp/capture.jpg'),
        throwsA(
          isA<OcrFailure>().having(
            (failure) => failure.kind,
            'kind',
            OcrFailureKind.bridge,
          ),
        ),
      );
    });
  });

  group('PigeonAppSettingsLauncher', () {
    for (final expected in [true, false]) {
      test('returns the native settings result $expected', () async {
        final launcher = PigeonAppSettingsLauncher(
          gateway: _FakeSettingsGateway(expected),
        );

        expect(await launcher.open(), expected);
      });
    }
  });
}

final class _FakeNativeOcrGateway implements NativeOcrGateway {
  _FakeNativeOcrGateway({this.reply, this.error});

  final NativeOcrReply? reply;
  final Object? error;
  final List<String> imagePaths = [];

  @override
  Future<NativeOcrReply> recognizeKorean(String imagePath) async {
    imagePaths.add(imagePath);
    if (error case final error?) {
      throw error;
    }
    return reply!;
  }
}

final class _FakeSettingsGateway implements SettingsGateway {
  const _FakeSettingsGateway(this.result);

  final bool result;

  @override
  Future<bool> open() async => result;
}
