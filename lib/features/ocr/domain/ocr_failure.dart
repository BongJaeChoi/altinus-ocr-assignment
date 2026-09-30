enum OcrFailureKind {
  transportTransient,
  quota,
  configuration,
  unsupportedLocation,
  service,
  safetyOrRecitation,
  invalidResponse,
  deadline,
  bridge,
  recognizer,
  cameraUnavailable,
  cameraInitialization,
  cameraCapture,
  cameraInterrupted,
  invalidInput,
  preparation,
  stale,
}

final class OcrFailure implements Exception {
  const OcrFailure._(this.kind, this.isRetryable);

  final OcrFailureKind kind;
  final bool isRetryable;

  factory OcrFailure.transportTransient() =>
      const OcrFailure._(OcrFailureKind.transportTransient, true);

  factory OcrFailure.quota() => const OcrFailure._(OcrFailureKind.quota, true);

  factory OcrFailure.serviceTransient() =>
      const OcrFailure._(OcrFailureKind.service, true);

  factory OcrFailure.invalidResponse() =>
      const OcrFailure._(OcrFailureKind.invalidResponse, false);

  factory OcrFailure.of(OcrFailureKind kind) =>
      OcrFailure._(kind, kind == OcrFailureKind.transportTransient);
}
