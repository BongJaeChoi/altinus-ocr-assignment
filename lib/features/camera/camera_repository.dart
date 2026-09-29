import 'camera_models.dart';

abstract interface class CameraRepository {
  Future<CameraPermissionState> initialize();
  Future<CapturedImage> capture();
  Future<bool> supportsFlash();
  Future<void> setFlash(CameraFlashMode mode);
  Future<void> dispose();
}
