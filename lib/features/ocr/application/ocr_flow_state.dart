import '../../camera/camera_models.dart';
import '../domain/ocr_engine.dart';
import '../domain/ocr_failure.dart';

sealed class OcrFlowState {
  const OcrFlowState();
}

final class Booting extends OcrFlowState {
  const Booting();
}

final class DisclosureRequired extends OcrFlowState {
  const DisclosureRequired();
}

final class CameraInitializing extends OcrFlowState {
  const CameraInitializing();
}

final class PermissionDenied extends OcrFlowState {
  const PermissionDenied(this.permission);

  final CameraPermissionState permission;
}

final class PreviewReady extends OcrFlowState {
  const PreviewReady({
    this.flashSupported = false,
    this.flashMode = CameraFlashMode.auto,
  });

  final bool flashSupported;
  final CameraFlashMode flashMode;
}

final class Capturing extends OcrFlowState {
  const Capturing({required this.transactionId});

  final String transactionId;
}

final class RecognizingCloud extends OcrFlowState {
  const RecognizingCloud({
    required this.transactionId,
    required this.attempt,
    required this.takingLonger,
    required this.startedAt,
  });

  final String transactionId;
  final int attempt;
  final bool takingLonger;
  final DateTime startedAt;
}

final class CloudRecovery extends OcrFlowState {
  const CloudRecovery({required this.transactionId, required this.failure});

  final String transactionId;
  final OcrFailure failure;
}

final class RecognizingLocal extends OcrFlowState {
  const RecognizingLocal({required this.transactionId});

  final String transactionId;
}

final class OcrSuccess extends OcrFlowState {
  const OcrSuccess({required this.text, required this.engine});

  final String text;
  final OcrEngine engine;
}

final class OcrEmpty extends OcrFlowState {
  const OcrEmpty({required this.engine});

  final OcrEngine engine;
}

final class RecoverableError extends OcrFlowState {
  const RecoverableError({required this.failure});

  final OcrFailure failure;
}
