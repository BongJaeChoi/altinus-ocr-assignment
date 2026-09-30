import 'camera_models.dart';

abstract interface class CameraRepository {
  Future<CameraPermissionState> initialize();
  Future<CapturedImage> capture();
  Future<bool> supportsFlash();
  Future<void> setFlash(CameraFlashMode mode);

  /// Releases camera resources and terminates any pending initialization.
  ///
  /// A successful return proves that a replacement initialization may begin.
  /// If this throws, ownership remains unproven and callers must stay closed;
  /// they may ask a repository to dispose again, but may not infer release from
  /// the retry unless that implementation can prove it. The official camera
  /// adapter treats a native-session teardown failure as terminal because the
  /// underlying controller can make later disposal calls successful no-ops.
  Future<void> dispose();
}
