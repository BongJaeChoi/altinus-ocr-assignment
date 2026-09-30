import 'dart:io';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'evaluator_credentials.dart';
import '../features/ocr/data/firebase_ai_ocr_service.dart';
import '../firebase_options.dart';

const artinusCloudEvidenceEnabled = bool.fromEnvironment(
  'ARTINUS_CLOUD_EVIDENCE',
  defaultValue: true,
);

AppleAppCheckProvider selectEvaluatorAppleProvider({
  required bool isDebugMode,
  required String debugToken,
}) {
  if (!isDebugMode || debugToken.trim().isEmpty) {
    throw StateError('Apple cloud evaluation is unavailable');
  }
  return AppleDebugProvider(debugToken: debugToken);
}

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
    if (Platform.isAndroid) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
      );
      return;
    }
    if (Platform.isIOS) {
      await FirebaseAppCheck.instance.activate(
        providerApple: selectEvaluatorAppleProvider(
          isDebugMode: kDebugMode,
          debugToken: evaluatorIosAppCheckDebugToken,
        ),
      );
    }
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
