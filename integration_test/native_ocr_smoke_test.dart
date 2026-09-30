import 'dart:io';

import 'package:altinus_ocr/features/ocr/data/pigeon_local_ocr_service.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fixture_image_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real native OCR handles poor fixtures and rejects malformed bytes',
    (tester) async {
      if (!Platform.isAndroid && !Platform.isIOS) {
        markTestSkipped('Native OCR smoke requires an Android or iOS target.');
        return;
      }
      final factory = FixtureImageFactory();
      final files = <File>[];
      addTearDown(() async {
        for (final file in files) {
          if (await file.exists()) await file.delete();
        }
      });
      final service = PigeonLocalOcrService();
      for (final variant in [
        FixtureImageVariant.darkLowContrast,
        FixtureImageVariant.blurred,
        FixtureImageVariant.skewed,
      ]) {
        final fixture = await factory.create(variant);
        files.add(fixture);
        expect(
          await service.recognize(fixture.path),
          anyOf(isA<TextDetected>(), isA<NoReadableText>()),
          reason: variant.name,
        );
      }
      final malformed = File(
        '${files.first.parent.path}/altinus_fixture_malformed.png',
      );
      files.add(malformed);
      await malformed.writeAsBytes([0, 1, 2, 3]);
      await expectLater(
        service.recognize(malformed.path),
        throwsA(
          isA<OcrFailure>().having(
            (f) => f.kind,
            'kind',
            OcrFailureKind.invalidInput,
          ),
        ),
      );
    },
  );

  testWidgets('real Pigeon Korean OCR classifies generated fixtures', (
    tester,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      markTestSkipped('Native OCR smoke requires an Android or iOS target.');
      return;
    }

    final factory = FixtureImageFactory();
    final fixtures = <File>[];
    addTearDown(() async {
      for (final fixture in fixtures) {
        if (await fixture.exists()) {
          await fixture.delete();
        }
      }
    });
    final service = PigeonLocalOcrService();

    for (final variant in const <FixtureImageVariant>[
      FixtureImageVariant.koreanLatin,
      FixtureImageVariant.multiline,
      FixtureImageVariant.rotated,
    ]) {
      final fixture = await factory.create(variant);
      fixtures.add(fixture);
      final result = await service.recognize(fixture.path);
      expect(result, isA<TextDetected>(), reason: variant.name);
      final text = (result as TextDetected).text;
      expect(text, contains('안녕하세요'), reason: variant.name);
      expect(text, contains('ALTINUS'), reason: variant.name);
      expect(text, contains('123'), reason: variant.name);
      if (variant == FixtureImageVariant.multiline) {
        expect(text, contains('\n'), reason: variant.name);
        expect(text, contains('MULTILINE'), reason: variant.name);
      }
    }

    final noText = await factory.create(FixtureImageVariant.noText);
    fixtures.add(noText);
    expect(
      await service.recognize(noText.path),
      isA<NoReadableText>(),
      reason: FixtureImageVariant.noText.name,
    );
  });

  testWidgets('real Pigeon Korean OCR sanitizes a missing image', (
    tester,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      markTestSkipped('Native OCR smoke requires an Android or iOS target.');
      return;
    }

    await expectLater(
      PigeonLocalOcrService().recognize(
        '/tmp/altinus-native-ocr-missing-image.png',
      ),
      throwsA(
        isA<OcrFailure>().having(
          (failure) => failure.kind,
          'kind',
          OcrFailureKind.invalidInput,
        ),
      ),
    );
  });

  testWidgets('real Pigeon Korean OCR handles ten sequential requests', (
    tester,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      markTestSkipped('Native OCR smoke requires an Android or iOS target.');
      return;
    }

    final fixture = await FixtureImageFactory().create(
      FixtureImageVariant.koreanLatin,
    );
    addTearDown(() async {
      if (await fixture.exists()) {
        await fixture.delete();
      }
    });
    final service = PigeonLocalOcrService();

    for (var request = 0; request < 10; request += 1) {
      final result = await service.recognize(fixture.path);
      expect(result, isA<TextDetected>(), reason: 'request ${request + 1}');
      expect(
        (result as TextDetected).text.trim(),
        isNotEmpty,
        reason: 'request ${request + 1}',
      );
    }
  });
}
