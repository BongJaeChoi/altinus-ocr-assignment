enum CameraPermissionState { granted, denied, restrictedOrNoPrompt }

enum CameraFlashMode { auto, off }

enum CameraFailureKind {
  unavailable,
  initialization,
  capture,
  captureInProgress,
  interrupted,
  flashUnsupported,
}

final class CameraFailure implements Exception {
  const CameraFailure(this.kind, {this.cleanupPath});

  final CameraFailureKind kind;
  final String? cleanupPath;
}

final class CapturedImage {
  const CapturedImage(this.path);

  final String path;
}
