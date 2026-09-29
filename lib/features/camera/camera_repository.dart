import 'camera_models.dart';

abstract interface class CameraRepository {
  Future<CameraPermissionState> initialize();
  Future<CapturedImage> capture();
  Future<bool> supportsFlash();
  Future<void> setFlash(CameraFlashMode mode);

  /// Releases camera resources and terminates any pending initialization.
  ///
  /// Callers await this teardown boundary before beginning a replacement
  /// initialization, so only one adapter-owned camera session is live.
  Future<void> dispose();
}
