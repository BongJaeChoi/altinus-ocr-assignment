import 'dart:typed_data';

import 'package:altinus_ocr/app.dart';
import 'package:altinus_ocr/features/camera/camera_plugin_repository.dart';
import 'package:altinus_ocr/features/disclosure/disclosure_store.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_providers.dart';
import 'package:altinus_ocr/features/ocr/data/firebase_ai_ocr_service.dart';
import 'package:altinus_ocr/features/ocr/data/image_preparer.dart';
import 'package:altinus_ocr/features/ocr/data/pigeon_app_settings_launcher.dart';
import 'package:altinus_ocr/features/ocr/data/pigeon_local_ocr_service.dart';
import 'package:altinus_ocr/features/ocr/data/temp_image_store.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots the production OCR screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          disclosureStoreProvider.overrideWithValue(_AcceptedDisclosureStore()),
        ],
        child: const AltinusOcrApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('production defaults compose every synchronous adapter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(cameraRepositoryProvider),
      isA<CameraPluginRepository>(),
    );
    expect(
      container.read(cloudOcrServiceProvider),
      isA<FirebaseAiOcrService>(),
    );
    expect(
      container.read(firebaseModelGatewayProvider),
      isA<FirebaseConfigurationPendingGateway>(),
    );
    expect(
      container.read(localOcrServiceProvider),
      isA<PigeonLocalOcrService>(),
    );
    expect(
      container.read(appSettingsLauncherProvider),
      isA<PigeonAppSettingsLauncher>(),
    );
    expect(container.read(imagePreparerProvider), isA<BoundedImagePreparer>());
    expect(container.read(transactionFilesProvider), isA<TempImageStore>());
  });

  test(
    'pending Firebase gateway reports typed configuration failure',
    () async {
      const gateway = FirebaseConfigurationPendingGateway();

      await expectLater(
        gateway.generate(
          FirebaseModelRequest(
            imageBytes: Uint8List.fromList(const [1]),
            mimeType: 'image/png',
          ),
        ),
        throwsA(
          isA<OcrFailure>().having(
            (failure) => failure.kind,
            'kind',
            OcrFailureKind.configuration,
          ),
        ),
      );
    },
  );
}

final class _AcceptedDisclosureStore implements DisclosureStore {
  @override
  Future<bool> hasAccepted() async => true;

  @override
  Future<void> accept() async {}
}
