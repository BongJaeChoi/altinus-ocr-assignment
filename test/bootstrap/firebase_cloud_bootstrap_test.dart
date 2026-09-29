import 'dart:typed_data';

import 'package:altinus_ocr/bootstrap/firebase_cloud_bootstrap.dart';
import 'package:altinus_ocr/features/ocr/data/firebase_ai_ocr_service.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('evaluation build is cloud-first by default', () {
    expect(artinusCloudEvidenceEnabled, isTrue);
  });

  test('iOS debug selects the explicit registered debug token', () {
    final provider = selectEvaluatorAppleProvider(
      isReleaseMode: false,
      debugToken: '11111111-1111-1111-1111-111111111111',
    );

    expect(provider, isA<AppleDebugProvider>());
    expect(
      (provider as AppleDebugProvider).debugToken,
      '11111111-1111-1111-1111-111111111111',
    );
  });

  test('iOS debug rejects a blank token without exposing it', () {
    expect(
      () =>
          selectEvaluatorAppleProvider(isReleaseMode: false, debugToken: '   '),
      throwsA(isA<StateError>()),
    );
  });

  test('iOS release rejects the debug provider', () {
    expect(
      () => selectEvaluatorAppleProvider(
        isReleaseMode: true,
        debugToken: '11111111-1111-1111-1111-111111111111',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('disabled mode returns pending without touching Firebase', () async {
    final runtime = _RecordingFirebaseCloudRuntime();

    final gateway = await createFirebaseModelGateway(
      cloudEvidenceEnabled: false,
      runtime: runtime,
    );

    expect(gateway, isA<FirebaseConfigurationPendingGateway>());
    expect(gateway.configurationPending, isTrue);
    expect(runtime.calls, isEmpty);
  });

  test(
    'enabled mode initializes Firebase then App Check then SDK gateway',
    () async {
      final runtime = _RecordingFirebaseCloudRuntime();

      final gateway = await createFirebaseModelGateway(
        cloudEvidenceEnabled: true,
        runtime: runtime,
      );

      expect(gateway, isA<FirebaseSdkModelGateway>());
      expect(runtime.calls, <String>[
        'firebase.initialize',
        'appCheck.activate',
        'gateway.create',
      ]);
    },
  );

  test(
    'Firebase initialization failure returns configured failure gateway',
    () async {
      final runtime = _RecordingFirebaseCloudRuntime(
        initializeFailure: StateError('initialization failed'),
      );

      final gateway = await createFirebaseModelGateway(
        cloudEvidenceEnabled: true,
        runtime: runtime,
      );

      expect(gateway, isA<FirebaseConfigurationFailedGateway>());
      expect(gateway.configurationPending, isFalse);
      expect(runtime.calls, <String>['firebase.initialize']);
    },
  );

  test(
    'App Check activation failure returns configured failure gateway',
    () async {
      final runtime = _RecordingFirebaseCloudRuntime(
        appCheckFailure: StateError('activation failed'),
      );

      final gateway = await createFirebaseModelGateway(
        cloudEvidenceEnabled: true,
        runtime: runtime,
      );

      expect(gateway, isA<FirebaseConfigurationFailedGateway>());
      expect(gateway.configurationPending, isFalse);
      expect(runtime.calls, <String>[
        'firebase.initialize',
        'appCheck.activate',
      ]);
    },
  );

  test(
    'bootstrap never includes raw exception text in its public failure',
    () async {
      const rawExceptionText = 'secret credential and technical error code';
      final runtime = _RecordingFirebaseCloudRuntime(
        initializeFailure: StateError(rawExceptionText),
      );

      final gateway = await createFirebaseModelGateway(
        cloudEvidenceEnabled: true,
        runtime: runtime,
      );

      await expectLater(
        gateway.generate(
          FirebaseModelRequest(
            imageBytes: Uint8List.fromList(const <int>[1]),
            mimeType: 'image/png',
          ),
        ),
        throwsA(
          isA<OcrFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                OcrFailureKind.configuration,
              )
              .having(
                (failure) => failure.toString(),
                'public text',
                isNot(contains(rawExceptionText)),
              ),
        ),
      );
    },
  );
}

final class _RecordingFirebaseCloudRuntime implements FirebaseCloudRuntime {
  _RecordingFirebaseCloudRuntime({
    this.initializeFailure,
    this.appCheckFailure,
  });

  final Object? initializeFailure;
  final Object? appCheckFailure;
  final List<String> calls = <String>[];

  @override
  Future<void> initialize() async {
    calls.add('firebase.initialize');
    if (initializeFailure case final failure?) {
      throw failure;
    }
  }

  @override
  Future<void> activateAppCheck() async {
    calls.add('appCheck.activate');
    if (appCheckFailure case final failure?) {
      throw failure;
    }
  }

  @override
  FirebaseModelGateway createGateway() {
    calls.add('gateway.create');
    return FirebaseSdkModelGateway();
  }
}
