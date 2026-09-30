import 'package:altinus_ocr/features/camera/camera_models.dart';
import 'package:altinus_ocr/features/ocr/application/ocr_flow_state.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_engine.dart';
import 'package:altinus_ocr/features/ocr/domain/ocr_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flow states are constructible and exhaustive', () {
    final startedAt = DateTime.utc(2026, 9, 28);
    final states = <OcrFlowState>[
      const Booting(),
      const DisclosureRequired(),
      const CameraInitializing(),
      const PermissionDenied(CameraPermissionState.denied),
      const PreviewReady(),
      const Capturing(transactionId: 'capture-1'),
      RecognizingCloud(
        transactionId: 'cloud-1',
        attempt: 2,
        takingLonger: true,
        startedAt: startedAt,
      ),
      CloudRecovery(transactionId: 'cloud-1', failure: OcrFailure.quota()),
      const RecognizingLocal(transactionId: 'local-1'),
      const OcrSuccess(text: 'recognized', engine: OcrEngine.cloud),
      const OcrEmpty(engine: OcrEngine.local),
      RecoverableError(failure: OcrFailure.invalidResponse()),
    ];

    final labels = states.map(_label).toList();

    expect(labels, [
      'booting',
      'disclosure',
      'initializing',
      'permissionDenied',
      'preview',
      'capturing',
      'cloud',
      'cloudRecovery',
      'local',
      'success',
      'empty',
      'error',
    ]);
    final recognizing = states[6] as RecognizingCloud;
    expect(recognizing.transactionId, 'cloud-1');
    expect(recognizing.attempt, 2);
    expect(recognizing.takingLonger, isTrue);
    expect(recognizing.startedAt, startedAt);
    expect((states[9] as OcrSuccess).engine, OcrEngine.cloud);
    expect((states[10] as OcrEmpty).engine, OcrEngine.local);
  });
}

String _label(OcrFlowState state) => switch (state) {
  Booting() => 'booting',
  DisclosureRequired() => 'disclosure',
  CameraInitializing() => 'initializing',
  PermissionDenied() => 'permissionDenied',
  PreviewReady() => 'preview',
  Capturing() => 'capturing',
  RecognizingCloud() => 'cloud',
  CloudRecovery() => 'cloudRecovery',
  RecognizingLocal() => 'local',
  OcrSuccess() => 'success',
  OcrEmpty() => 'empty',
  RecoverableError() => 'error',
};
