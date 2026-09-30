import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/camera_plugin_repository.dart';
import '../../camera/camera_repository.dart';
import '../../disclosure/disclosure_store.dart';
import '../data/firebase_ai_ocr_service.dart';
import '../data/image_preparer.dart';
import '../data/pigeon_app_settings_launcher.dart';
import '../data/pigeon_local_ocr_service.dart';
import '../data/temp_image_store.dart';
import '../domain/ocr_ports.dart';

typedef OcrNow = DateTime Function();
typedef OcrRetryDelay = Duration Function(int failedAttempt);

final cameraRepositoryProvider = Provider<CameraRepository>(
  (ref) => CameraPluginRepository(),
);

final disclosureStoreProvider = Provider<DisclosureStore>(
  (ref) => throw UnsupportedError('DisclosureStore must be provided'),
);

final firebaseModelGatewayProvider = Provider<FirebaseModelGateway>(
  (ref) => const FirebaseConfigurationPendingGateway(),
);

final cloudOcrServiceProvider = Provider<CloudOcrService>(
  (ref) =>
      FirebaseAiOcrService(gateway: ref.watch(firebaseModelGatewayProvider)),
);

final localOcrServiceProvider = Provider<LocalOcrService>(
  (ref) => PigeonLocalOcrService(),
);

final imagePreparerProvider = Provider<ImagePreparer>(
  (ref) => BoundedImagePreparer(),
);

final transactionFilesProvider = Provider<TransactionFiles>(
  (ref) => TempImageStore(),
);

final appSettingsLauncherProvider = Provider<AppSettingsLauncher>(
  (ref) => PigeonAppSettingsLauncher(),
);

final ocrNowProvider = Provider<OcrNow>((ref) => DateTime.now);

final ocrRetryDelayProvider = Provider<OcrRetryDelay>((ref) {
  final random = Random();
  return (failedAttempt) {
    const baseMilliseconds = 1000;
    const maximumMilliseconds = 2000;
    const maximumJitterMilliseconds = 250;
    final exponentialMilliseconds =
        baseMilliseconds * (1 << (failedAttempt - 1).clamp(0, 3));
    final boundedMilliseconds = min(
      exponentialMilliseconds,
      maximumMilliseconds,
    );
    final availableJitterMilliseconds = min(
      maximumJitterMilliseconds,
      maximumMilliseconds - boundedMilliseconds,
    );
    final jitterMilliseconds = random.nextInt(availableJitterMilliseconds + 1);
    return Duration(milliseconds: boundedMilliseconds + jitterMilliseconds);
  };
});
