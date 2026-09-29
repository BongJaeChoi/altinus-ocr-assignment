import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:altinus_ocr/features/ocr/data/firebase_ai_ocr_service.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  late Directory temporaryDirectory;
  late File imageFile;
  late CapturingGateway gateway;
  late FirebaseAiOcrService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('ocr_service_');
    imageFile = File('${temporaryDirectory.path}/capture.jpg');
    await imageFile.writeAsBytes(
      image.encodeJpg(image.Image(width: 4, height: 2)),
    );
    gateway = CapturingGateway();
    service = FirebaseAiOcrService(gateway: gateway);
  });

  tearDown(() => temporaryDirectory.delete(recursive: true));

  group('strict structured response parsing', () {
    test('returns nonblank detected text and preserves line breaks', () async {
      gateway.response = const FirebaseModelResponse(
        text: '{"status":"textDetected","text":"first\\n\\n second"}',
      );

      final result = await service.recognize(imageFile.path);

      expect(result, isA<TextDetected>());
      expect((result as TextDetected).text, 'first\n\n second');
      expect(gateway.requests.single.mimeType, 'image/jpeg');
      expect(gateway.requests.single.imageBytes, await imageFile.readAsBytes());
    });

    for (final response in <String>[
      '{"status":"noReadableText"}',
      '{"status":"noReadableText","text":null}',
      '{"status":"noReadableText","text":""}',
    ]) {
      test('accepts explicit noReadableText: $response', () async {
        gateway.response = FirebaseModelResponse(text: response);

        expect(await service.recognize(imageFile.path), isA<NoReadableText>());
      });
    }

    for (final response in <String?>[
      null,
      '',
      'not-json',
      '[]',
      '{}',
      '{"text":"value"}',
      '{"status":"unknown","text":"value"}',
      '{"status":"textDetected"}',
      '{"status":"textDetected","text":null}',
      '{"status":"textDetected","text":""}',
      '{"status":"textDetected","text":"   "}',
      '{"status":"textDetected","text":3}',
      '{"status":"textDetected","text":"value","extra":true}',
      '{"status":"noReadableText","text":"contradiction"}',
      '{"status":"noReadableText","extra":true}',
      '{"status":"textDetected","status":"noReadableText"}',
    ]) {
      test('rejects malformed or contradictory response: $response', () async {
        gateway.response = FirebaseModelResponse(text: response);

        await expectLater(
          service.recognize(imageFile.path),
          throwsFailure(OcrFailureKind.invalidResponse),
        );
      });
    }

    test('maps public safety finish reason without reading messages', () async {
      gateway.response = const FirebaseModelResponse(
        text: null,
        finishReason: FirebaseModelFinishReason.safety,
      );

      await expectLater(
        service.recognize(imageFile.path),
        throwsFailure(OcrFailureKind.safetyOrRecitation),
      );
    });

    test('maps public recitation finish reason', () async {
      gateway.response = const FirebaseModelResponse(
        text: null,
        finishReason: FirebaseModelFinishReason.recitation,
      );

      await expectLater(
        service.recognize(imageFile.path),
        throwsFailure(OcrFailureKind.safetyOrRecitation),
      );
    });
  });

  group('input validation and MIME', () {
    test('rejects a missing file before calling the model', () async {
      await expectLater(
        service.recognize('${temporaryDirectory.path}/missing.jpg'),
        throwsFailure(OcrFailureKind.invalidInput),
      );
      expect(gateway.requests, isEmpty);
    });

    test('rejects an empty file before calling the model', () async {
      await imageFile.writeAsBytes(const []);

      await expectLater(
        service.recognize(imageFile.path),
        throwsFailure(OcrFailureKind.invalidInput),
      );
      expect(gateway.requests, isEmpty);
    });

    test('detects PNG MIME from bytes rather than the extension', () async {
      final pngWithWrongExtension = File(
        '${temporaryDirectory.path}/image.jpg',
      );
      await pngWithWrongExtension.writeAsBytes(
        image.encodePng(image.Image(width: 3, height: 2)),
      );
      gateway.response = const FirebaseModelResponse(
        text: '{"status":"noReadableText"}',
      );

      await service.recognize(pngWithWrongExtension.path);

      expect(gateway.requests.single.mimeType, 'image/png');
    });

    test('rejects unsupported bytes without calling the model', () async {
      await imageFile.writeAsString('plain text');

      await expectLater(
        service.recognize(imageFile.path),
        throwsFailure(OcrFailureKind.invalidInput),
      );
      expect(gateway.requests, isEmpty);
    });

    for (final fakeBytes in <List<int>>[
      <int>[0xff, 0xd8, 0xff, 0xd9],
      <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
    ]) {
      test('rejects truncated image magic: $fakeBytes', () async {
        await imageFile.writeAsBytes(fakeBytes);

        await expectLater(
          service.recognize(imageFile.path),
          throwsFailure(OcrFailureKind.invalidInput),
        );
        expect(gateway.requests, isEmpty);
      });
    }

    test('rejects bytes that grow beyond 14 MiB after stat', () async {
      service = FirebaseAiOcrService(
        gateway: gateway,
        readImageFile: (file) async =>
            Uint8List(FirebaseAiOcrService.maxImageBytes + 1),
      );

      await expectLater(
        service.recognize(imageFile.path),
        throwsFailure(OcrFailureKind.invalidInput),
      );
      expect(gateway.requests, isEmpty);
    });

    test('validates bytes from a path replacement after stat', () async {
      service = FirebaseAiOcrService(
        gateway: gateway,
        readImageFile: (file) async {
          await file.writeAsBytes(<int>[0xff, 0xd8, 0xff, 0xd9]);
          return file.readAsBytes();
        },
      );

      await expectLater(
        service.recognize(imageFile.path),
        throwsFailure(OcrFailureKind.invalidInput),
      );
      expect(gateway.requests, isEmpty);
    });

    test('rejects excessive decoded dimensions before model upload', () async {
      final wide = image.encodePng(image.Image(width: 9000, height: 1));
      service = FirebaseAiOcrService(
        gateway: gateway,
        readImageFile: (file) async => wide,
      );

      await expectLater(
        service.recognize(imageFile.path),
        throwsFailure(OcrFailureKind.invalidInput),
      );
      expect(gateway.requests, isEmpty);
    });
  });

  group('public exception mapping', () {
    final cases = <(Object, OcrFailureKind)>[
      (InvalidApiKey('private detail'), OcrFailureKind.configuration),
      (ServiceApiNotEnabled('projects/test'), OcrFailureKind.configuration),
      (UnsupportedUserLocation(), OcrFailureKind.unsupportedLocation),
      (QuotaExceeded('private detail'), OcrFailureKind.quota),
      (
        FirebaseAISdkException('private detail'),
        OcrFailureKind.invalidResponse,
      ),
      (ServerException('private detail'), OcrFailureKind.service),
      (FirebaseAIException('looks like timeout'), OcrFailureKind.service),
      (SocketException('private detail'), OcrFailureKind.transportTransient),
      (TimeoutException('private detail'), OcrFailureKind.transportTransient),
      (FirebaseModelTransientException(), OcrFailureKind.transportTransient),
      (StateError('private detail'), OcrFailureKind.service),
    ];

    for (final (error, expectedKind) in cases) {
      test('${error.runtimeType} maps to $expectedKind', () async {
        gateway.error = error;

        await expectLater(
          service.recognize(imageFile.path),
          throwsFailure(expectedKind),
        );
      });
    }
  });

  test(
    'SDK gateway sends pinned model, low thinking, schema and prompt',
    () async {
      String? modelName;
      GenerationConfig? generationConfig;
      List<Content>? contents;
      final sdkGateway = FirebaseSdkModelGateway(
        generateForTest:
            ({required model, required config, required prompt}) async {
              modelName = model;
              generationConfig = config;
              contents = prompt;
              return GenerateContentResponse(<Candidate>[
                Candidate(
                  Content.model(<Part>[
                    const TextPart('{"status":"noReadableText"}'),
                  ]),
                  null,
                  null,
                  FinishReason.stop,
                  null,
                ),
              ], null);
            },
      );

      final response = await sdkGateway.generate(
        FirebaseModelRequest(
          imageBytes: Uint8List.fromList(<int>[0xff, 0xd8, 0xff]),
          mimeType: 'image/jpeg',
        ),
      );

      expect(modelName, 'gemini-3.8-flash');
      expect(generationConfig!.responseMimeType, 'application/json');
      expect(
        generationConfig!.thinkingConfig!.thinkingLevel,
        ThinkingLevel.low,
      );
      expect(generationConfig!.responseSchema, isNotNull);
      expect(
        generationConfig!.responseSchema!.toJson(),
        containsPair('required', containsAll(<String>['status'])),
      );
      final parts = contents!.single.parts;
      expect(parts.whereType<InlineDataPart>().single.mimeType, 'image/jpeg');
      final prompt = parts.whereType<TextPart>().single.text.toLowerCase();
      expect(prompt, contains('original line breaks'));
      expect(prompt, contains('do not guess'));
      expect(prompt, contains('do not correct'));
      expect(prompt, contains('do not translate'));
      expect(prompt, contains('do not summarize'));
      expect(response.text, '{"status":"noReadableText"}');
    },
  );

  test('SDK gateway exposes safety and recitation finish reasons', () async {
    for (final (finishReason, expected)
        in <(FinishReason, FirebaseModelFinishReason)>[
          (FinishReason.safety, FirebaseModelFinishReason.safety),
          (FinishReason.recitation, FirebaseModelFinishReason.recitation),
        ]) {
      final sdkGateway = FirebaseSdkModelGateway(
        generateForTest:
            ({required model, required config, required prompt}) async =>
                GenerateContentResponse(<Candidate>[
                  Candidate(
                    Content.model(const []),
                    null,
                    null,
                    finishReason,
                    null,
                  ),
                ], null),
      );

      final response = await sdkGateway.generate(
        FirebaseModelRequest(imageBytes: Uint8List(1), mimeType: 'image/jpeg'),
      );

      expect(response.finishReason, expected);
    }
  });

  test('SDK gateway does not classify a non-safety block as safety', () async {
    final sdkGateway = FirebaseSdkModelGateway(
      generateForTest:
          ({required model, required config, required prompt}) async =>
              GenerateContentResponse(
                const <Candidate>[],
                PromptFeedback(BlockReason.other, null, const <SafetyRating>[]),
              ),
    );

    await expectLater(
      sdkGateway.generate(
        FirebaseModelRequest(imageBytes: Uint8List(1), mimeType: 'image/jpeg'),
      ),
      throwsA(isA<FirebaseAIException>()),
    );
  });
}

final class CapturingGateway implements FirebaseModelGateway {
  final List<FirebaseModelRequest> requests = [];
  FirebaseModelResponse response = const FirebaseModelResponse(
    text: '{"status":"textDetected","text":"value"}',
  );
  Object? error;

  @override
  Future<FirebaseModelResponse> generate(FirebaseModelRequest request) async {
    requests.add(request);
    if (error case final error?) {
      throw error;
    }
    return response;
  }
}

Matcher throwsFailure(OcrFailureKind kind) =>
    throwsA(isA<OcrFailure>().having((failure) => failure.kind, 'kind', kind));
