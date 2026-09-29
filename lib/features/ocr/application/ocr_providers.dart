import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/camera_plugin_repository.dart';
import '../../camera/camera_repository.dart';
import '../../disclosure/disclosure_store.dart';
import '../domain/ocr_ports.dart';

typedef OcrNow = DateTime Function();
typedef OcrRetryDelay = Duration Function(int failedAttempt);

final cameraRepositoryProvider = Provider<CameraRepository>(
  (ref) => CameraPluginRepository(),
);

final disclosureStoreProvider = Provider<DisclosureStore>(
  (ref) => throw UnsupportedError('DisclosureStore must be provided'),
);

final cloudOcrServiceProvider = Provider<CloudOcrService>(
  (ref) => throw UnsupportedError('CloudOcrService must be provided'),
);

final localOcrServiceProvider = Provider<LocalOcrService>(
  (ref) => throw UnsupportedError('LocalOcrService must be provided'),
);

final imagePreparerProvider = Provider<ImagePreparer>(
  (ref) => throw UnsupportedError('ImagePreparer must be provided'),
);

final transactionFilesProvider = Provider<TransactionFiles>(
  (ref) => throw UnsupportedError('TransactionFiles must be provided'),
);

final appSettingsLauncherProvider = Provider<AppSettingsLauncher>(
  (ref) => throw UnsupportedError('AppSettingsLauncher must be provided'),
);

final ocrNowProvider = Provider<OcrNow>((ref) => DateTime.now);

final ocrRetryDelayProvider = Provider<OcrRetryDelay>((ref) {
  final random = Random();
  return (failedAttempt) {
    const baseMilliseconds = 400;
    const maximumMilliseconds = 2000;
    const maximumJitterMilliseconds = 200;
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
