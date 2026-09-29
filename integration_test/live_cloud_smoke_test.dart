import 'dart:convert';
import 'dart:io';

import 'package:altinus_ocr/bootstrap/firebase_cloud_bootstrap.dart';
import 'package:altinus_ocr/features/ocr/data/firebase_ai_ocr_service.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fixture_image_factory.dart';

const _runLiveOcr = bool.fromEnvironment('RUN_LIVE_OCR');
const _device = String.fromEnvironment('OCR_DEVICE');
const _commit = String.fromEnvironment('OCR_GIT_COMMIT');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authorized Firebase project recognizes a generated fixture', (
    tester,
  ) async {
    if (!_runLiveOcr) {
      markTestSkipped('Set RUN_LIVE_OCR=true only for an authorized project.');
      return;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      markTestSkipped('Live cloud smoke requires an Android or iOS target.');
      return;
    }
    expect(_device, isNotEmpty, reason: 'Pass --dart-define=OCR_DEVICE=...');
    expect(
      _commit,
      isNotEmpty,
      reason: 'Pass --dart-define=OCR_GIT_COMMIT=...',
    );

    final fixture = await FixtureImageFactory().create(
      FixtureImageVariant.koreanLatin,
    );
    addTearDown(() async {
      if (await fixture.exists()) {
        await fixture.delete();
      }
    });

    final gateway = await createFirebaseModelGateway(
      cloudEvidenceEnabled: true,
    );
    expect(gateway.configurationPending, isFalse);

    final result = await FirebaseAiOcrService(gateway: gateway)
        .recognize(fixture.path);
    expect(result, isA<TextDetected>());
    expect((result as TextDetected).text.trim(), isNotEmpty);

    debugPrint(
      jsonEncode(<String, String>{
        'model': FirebaseSdkModelGateway.modelName,
        'platform': Platform.operatingSystem,
        'device': _device,
        'os': Platform.operatingSystemVersion,
        'commit': _commit,
      }),
    );
  });
}
