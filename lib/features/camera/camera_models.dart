enum CameraPermissionState { granted, denied, restrictedOrNoPrompt }

enum CameraFlashMode { auto, off }

final class CapturedImage {
  const CapturedImage(this.path);

  final String path;
}
