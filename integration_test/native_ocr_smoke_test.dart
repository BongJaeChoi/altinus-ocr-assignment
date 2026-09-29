import 'dart:io';

import 'package:altinus_ocr/features/ocr/data/pigeon_local_ocr_service.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fixture_image_factory.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real Pigeon Korean OCR returns nonblank text', (tester) async {
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

    final result = await PigeonLocalOcrService().recognize(fixture.path);
    expect(result, isA<TextDetected>());
    expect((result as TextDetected).text.trim(), isNotEmpty);
  });
}
