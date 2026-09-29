import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';

import '../features/ocr/data/firebase_ai_ocr_service.dart';
import '../firebase_options.dart';

const artinusCloudEvidenceEnabled = bool.fromEnvironment(
  'ARTINUS_CLOUD_EVIDENCE',
  defaultValue: false,
);

abstract interface class FirebaseCloudRuntime {
  Future<void> initialize();

  Future<void> activateAppCheck();

  FirebaseModelGateway createGateway();
}

final class ProductionFirebaseCloudRuntime implements FirebaseCloudRuntime {
  @override
  Future<void> initialize() =>
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  @override
  Future<void> activateAppCheck() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
    );
  }

  @override
  FirebaseModelGateway createGateway() => FirebaseSdkModelGateway();
}

Future<FirebaseModelGateway> createFirebaseModelGateway({
  bool cloudEvidenceEnabled = artinusCloudEvidenceEnabled,
  FirebaseCloudRuntime? runtime,
}) async {
  if (!cloudEvidenceEnabled) {
    return const FirebaseConfigurationPendingGateway();
  }
  final selected = runtime ?? ProductionFirebaseCloudRuntime();
  try {
    await selected.initialize();
    await selected.activateAppCheck();
    return selected.createGateway();
  } catch (_) {
    return const FirebaseConfigurationFailedGateway();
  }
}
