import 'dart:typed_data';

import 'package:altinus_ocr/app.dart';
import 'package:altinus_ocr/bootstrap/firebase_cloud_bootstrap.dart';
import 'package:altinus_ocr/features/disclosure/disclosure_store.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_providers.dart';
import 'package:altinus_ocr/features/ocr/data/firebase_ai_ocr_service.dart';
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
    expect(find.text('ARTINUS OCR'), findsOneWidget);
  });

  test('default production composition is cloud-first', () async {
    final runtime = _RecordingFirebaseCloudRuntime();
    final gateway = await createFirebaseModelGateway(runtime: runtime);

    expect(runtime.calls, <String>[
      'firebase.initialize',
      'appCheck.activate',
      'gateway.create',
    ]);
    expect(gateway, isA<FirebaseSdkModelGateway>());
    expect(gateway.configurationPending, isFalse);
  });

  test(
    'pending Firebase gateway reports typed configuration failure',
    () async {
      const gateway = FirebaseConfigurationPendingGateway();
      expect(gateway.configurationPending, isTrue);

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

final class _RecordingFirebaseCloudRuntime implements FirebaseCloudRuntime {
  final List<String> calls = <String>[];

  @override
  Future<void> initialize() async {
    calls.add('firebase.initialize');
  }

  @override
  Future<void> activateAppCheck() async {
    calls.add('appCheck.activate');
  }

  @override
  FirebaseModelGateway createGateway() {
    calls.add('gateway.create');
    return FirebaseSdkModelGateway();
  }
}

final class _AcceptedDisclosureStore implements DisclosureStore {
  @override
  Future<bool> hasAccepted() async => true;

  @override
  Future<void> accept() async {}
}
