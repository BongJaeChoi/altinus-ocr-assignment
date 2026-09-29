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

  factory OcrFailure.quota() => const OcrFailure._(OcrFailureKind.quota, false);

  factory OcrFailure.invalidResponse() =>
      const OcrFailure._(OcrFailureKind.invalidResponse, false);

  factory OcrFailure.of(OcrFailureKind kind) =>
      OcrFailure._(kind, kind == OcrFailureKind.transportTransient);
}
